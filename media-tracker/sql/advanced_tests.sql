-- Evidence for advanced SQL. Every query is in advanced_queries.sql; this file runs it again and
-- prints PASS/FAIL against the result worked out by hand from seed_data.sql.
--
--   T1   Q1   INSERT into a child with a missing parent is refused
--   T2   Q2   UPDATE of a child's foreign key to a missing parent is refused
--   T3   Q3   DELETE of a parent with ON DELETE CASCADE, two levels deep
--   T4   Q4   DELETE of a parent with ON DELETE RESTRICT is refused and changes nothing,
--             until the reference is removed
--   T5   Q5   ON UPDATE RESTRICT blocks changing a referenced key, not other columns or child deletes
--   T6   Q6   Three-valued logic: WHERE keeps only TRUE, so NULL years are in neither answer
--   T7   Q7   NULL never joins with NULL (but <=> does)
--   T8   Q8   NOT IN / NOT EXISTS over a nullable column
--   T9   Q9   LEFT JOIN: a condition in ON versus WHERE; COUNT(*) versus COUNT(column)
--   T10  Q10  Aggregates ignore NULL
--   T11       Everything was rolled back
--
-- Statements that must fail are run through the helper expect_outcome, which catches the error
-- and compares its number with the expected one, so no --force is needed. Rows are turned into one
-- string: rows joined with commas, columns with colons; "(none)" means no rows.
-- Everything runs inside transactions that are rolled back, so the file can be run any number of
-- times. Run it after seed_data.sql and BEFORE load_csv.sql (that script adds more media).
--
-- Run with:  mysql -t -u root -p < advanced_tests.sql

USE media_tracker;

SET FOREIGN_KEY_CHECKS = 1;

-- Helper (created before any transaction, because CREATE PROCEDURE ends a transaction)
DROP PROCEDURE IF EXISTS expect_outcome;

DELIMITER //
CREATE PROCEDURE expect_outcome(IN test_name VARCHAR(100), IN stmt TEXT, IN expected VARCHAR(10))
BEGIN
    DECLARE err_no  INT  DEFAULT 0;
    DECLARE err_msg TEXT DEFAULT '';
    DECLARE actual  VARCHAR(10);
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        GET DIAGNOSTICS CONDITION 1 err_no = MYSQL_ERRNO, err_msg = MESSAGE_TEXT;

    SET @stmt_to_run = stmt;
    PREPARE s FROM @stmt_to_run;
    IF err_no = 0 THEN
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;

    SET actual = IF(err_no = 0, 'OK', CAST(err_no AS CHAR));
    SELECT test_name                           AS test,
           expected                            AS expected,
           actual                              AS actual,
           IF(actual = expected, 'PASS', 'FAIL') AS result,
           LEFT(err_msg, 110)                  AS error_message;
END//
DELIMITER ;

-- =====================================================================
-- FOREIGN KEYS AND DML
-- =====================================================================

-- T1  Q1: INSERT into tracks for user 99, who does not exist
START TRANSACTION;
CALL expect_outcome('T1a INSERT child, parent missing',
    'INSERT INTO tracks (user_id, media_id, media_status) VALUES (99, 1, ''want_to_consume'')', '1452');
SET @actual = (SELECT COUNT(*) FROM tracks);
SELECT 'T1b tracks unchanged' AS test, 3 AS expected, @actual AS actual,
       IF(@actual = 3, 'PASS', 'FAIL') AS result;
ROLLBACK;

-- T2  Q2: UPDATE has_tag.tag_id to tag 99, which does not exist
START TRANSACTION;
CALL expect_outcome('T2a UPDATE child fk to a missing parent',
    'UPDATE has_tag SET tag_id = 99 WHERE media_id = 1 AND tag_id = 1', '1452');
SET @actual = (SELECT GROUP_CONCAT(tag_id ORDER BY tag_id) FROM has_tag WHERE media_id = 1);
SELECT 'T2b The Secret History keeps its vibes' AS test, '1,2,4' AS expected, @actual AS actual,
       IF(@actual = '1,2,4', 'PASS', 'FAIL') AS result;
ROLLBACK;

-- T3  Q3: delete muskan. Counts are memberships:friendships:tracks:reviews:review_tags
START TRANSACTION;
SET @rows_of_muskan = 'SELECT CONCAT_WS('':'',
        (SELECT COUNT(*) FROM member_of   WHERE user_id = 1),
        (SELECT COUNT(*) FROM friends     WHERE follower_id = 1 OR followed_id = 1),
        (SELECT COUNT(*) FROM tracks      WHERE user_id = 1),
        (SELECT COUNT(*) FROM reviews     WHERE user_id = 1),
        (SELECT COUNT(*) FROM review_tags WHERE user_id = 1)) INTO @actual';
PREPARE rows_of_muskan FROM @rows_of_muskan;
EXECUTE rows_of_muskan;
SELECT 'T3a muskan''s rows before' AS test, '1:3:1:1:2' AS expected, @actual AS actual,
       IF(@actual = '1:3:1:1:2', 'PASS', 'FAIL') AS result;
CALL expect_outcome('T3b DELETE muskan (CASCADE)', 'DELETE FROM users WHERE user_id = 1', 'OK');
EXECUTE rows_of_muskan;
DEALLOCATE PREPARE rows_of_muskan;
SELECT 'T3c all cascaded, incl. review_tags' AS test, '0:0:0:0:0' AS expected, @actual AS actual,
       IF(@actual = '0:0:0:0:0', 'PASS', 'FAIL') AS result;
ROLLBACK;

-- T4  Q4: delete grace, who created a group. Counts are exists:memberships:friendships:tracks
START TRANSACTION;
SET @rows_of_grace = 'SELECT CONCAT_WS('':'',
        (SELECT COUNT(*) FROM users     WHERE user_id = 3),
        (SELECT COUNT(*) FROM member_of WHERE user_id = 3),
        (SELECT COUNT(*) FROM friends   WHERE follower_id = 3 OR followed_id = 3),
        (SELECT COUNT(*) FROM tracks    WHERE user_id = 3)) INTO @actual';
PREPARE rows_of_grace FROM @rows_of_grace;
CALL expect_outcome('T4a DELETE grace (RESTRICT)', 'DELETE FROM users WHERE user_id = 3', '1451');
EXECUTE rows_of_grace;
SELECT 'T4b refused DELETE changed nothing' AS test, '1:1:1:1' AS expected, @actual AS actual,
       IF(@actual = '1:1:1:1', 'PASS', 'FAIL') AS result;
UPDATE user_groups SET creator_id = 1 WHERE group_id = 1;
CALL expect_outcome('T4c DELETE grace after hand-over', 'DELETE FROM users WHERE user_id = 3', 'OK');
EXECUTE rows_of_grace;
DEALLOCATE PREPARE rows_of_grace;
SELECT 'T4d grace and her rows are gone' AS test, '0:0:0:0' AS expected, @actual AS actual,
       IF(@actual = '0:0:0:0', 'PASS', 'FAIL') AS result;
ROLLBACK;

-- T5  Q5: has_tag.tag_id -> tag is ON UPDATE RESTRICT
START TRANSACTION;
CALL expect_outcome('T5a change a referenced key',      'UPDATE tag SET tag_id = 40 WHERE tag_id = 4', '1451');
CALL expect_outcome('T5b rename a tag (not the key)',   'UPDATE tag SET name = ''cosy'' WHERE tag_id = 3', 'OK');
CALL expect_outcome('T5c DELETE a child row',           'DELETE FROM has_tag WHERE media_id = 7 AND tag_id = 3', 'OK');
ROLLBACK;

-- =====================================================================
-- NULL VALUES: the same demo rows as advanced_queries.sql (ids 881-885), rolled back at the end
-- =====================================================================
START TRANSACTION;

INSERT INTO media (media_id, title, release_year, summary) VALUES
    (881, 'Wuthering Heights',       NULL, NULL),
    (882, 'Jane Eyre',               NULL, 'A governess at Thornfield Hall.'),
    (883, 'Mulholland Drive',        2001, 'A dream-like mystery in Los Angeles.'),
    (884, 'Kiki''s Delivery Service', 1989, 'A young witch starts a delivery service.'),
    (885, 'The Twilight Zone',       1959, 'An anthology of strange stories.');
INSERT INTO books    (media_id, author)                     VALUES (881, 'Emily Bronte'), (882, 'Charlotte Bronte');
INSERT INTO movies   (media_id, director, duration_minutes) VALUES (883, 'David Lynch', 147.00), (884, NULL, NULL);
INSERT INTO tv_shows (media_id, director)                   VALUES (885, NULL);
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (2, 2, 2, 'Coma', NULL);

-- T6  Q6: all, before 1950, NOT before 1950, either, unknown
SET @actual = CONCAT_WS(',',
    (SELECT COUNT(*) FROM media),
    (SELECT COUNT(*) FROM media WHERE release_year < 1950),
    (SELECT COUNT(*) FROM media WHERE NOT (release_year < 1950)),
    (SELECT COUNT(*) FROM media WHERE release_year < 1950 OR NOT (release_year < 1950)),
    (SELECT COUNT(*) FROM media WHERE release_year IS NULL));
SELECT 'T6a p OR NOT p misses the NULL years' AS test, '12,2,8,10,2' AS expected, @actual AS actual,
       IF(@actual = '12,2,8,10,2', 'PASS', 'FAIL') AS result;

-- T6b  The truth values behind it: NULL < 1950, NOT (NULL < 1950), TRUE AND UNKNOWN,
--      FALSE AND UNKNOWN, TRUE OR UNKNOWN, FALSE OR UNKNOWN   (T / F / U)
SET @actual = (
    SELECT GROUP_CONCAT(CASE WHEN e.v IS NULL THEN 'U' WHEN e.v THEN 'T' ELSE 'F' END ORDER BY e.n)
    FROM (SELECT 1 AS n, NULL < 1950 AS v  UNION ALL SELECT 2, NOT (NULL < 1950) UNION ALL
          SELECT 3, TRUE AND NULL          UNION ALL SELECT 4, FALSE AND NULL    UNION ALL
          SELECT 5, TRUE OR NULL           UNION ALL SELECT 6, FALSE OR NULL) AS e);
SELECT 'T6b three-valued logic' AS test, 'U,U,U,F,T,U' AS expected, @actual AS actual,
       IF(@actual = 'U,U,U,F,T,U', 'PASS', 'FAIL') AS result;

-- T7  Q7: movie:tv_show pairs with the same director
SET @equals = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT(mo.media_id, ':', tv.media_id) ORDER BY mo.media_id), '(none)')
    FROM movies AS mo JOIN tv_shows AS tv ON tv.director = mo.director);
SET @null_safe = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT(mo.media_id, ':', tv.media_id) ORDER BY mo.media_id), '(none)')
    FROM movies AS mo JOIN tv_shows AS tv ON tv.director <=> mo.director);
SELECT 'T7 join with = / with <=>' AS test, '883:2 / 883:2,884:885' AS expected,
       CONCAT(@equals, ' / ', @null_safe) AS actual,
       IF(@equals = '883:2' AND @null_safe = '883:2,884:885', 'PASS', 'FAIL') AS result;

-- T8  Q8: movies whose director has not made a TV show, three ways
SET @not_in = (
    SELECT IFNULL(GROUP_CONCAT(mo.media_id ORDER BY mo.media_id), '(none)')
    FROM movies AS mo
    WHERE mo.director NOT IN (SELECT tv.director FROM tv_shows AS tv));
SET @not_exists = (
    SELECT IFNULL(GROUP_CONCAT(mo.media_id ORDER BY mo.media_id), '(none)')
    FROM movies AS mo
    WHERE NOT EXISTS (SELECT 1 FROM tv_shows AS tv WHERE tv.director = mo.director));
SET @not_in_no_nulls = (
    SELECT IFNULL(GROUP_CONCAT(mo.media_id ORDER BY mo.media_id), '(none)')
    FROM movies AS mo
    WHERE mo.director NOT IN (SELECT tv.director FROM tv_shows AS tv WHERE tv.director IS NOT NULL));
SELECT 'T8 NOT IN / NOT EXISTS / NOT IN without NULLs' AS test, '(none) / 3,6,884 / 3,6' AS expected,
       CONCAT_WS(' / ', @not_in, @not_exists, @not_in_no_nulls) AS actual,
       IF(@not_in = '(none)' AND @not_exists = '3,6,884' AND @not_in_no_nulls = '3,6', 'PASS', 'FAIL') AS result;

-- T9  Q9: divina's status; rows:with_status for the condition in ON, then in WHERE
SET @in_on = (
    SELECT CONCAT(COUNT(*), ':', COUNT(t.user_id))
    FROM media AS m LEFT JOIN tracks AS t ON t.media_id = m.media_id AND t.user_id = 2);
SET @in_where = (
    SELECT CONCAT(COUNT(*), ':', COUNT(t.user_id))
    FROM media AS m LEFT JOIN tracks AS t ON t.media_id = m.media_id
    WHERE t.user_id = 2);
SELECT 'T9a condition in ON / in WHERE' AS test, '12:1 / 1:1' AS expected,
       CONCAT(@in_on, ' / ', @in_where) AS actual,
       IF(@in_on = '12:1' AND @in_where = '1:1', 'PASS', 'FAIL') AS result;

SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(m.media_id, ':', t.media_status))
    FROM media AS m LEFT JOIN tracks AS t ON t.media_id = m.media_id AND t.user_id = 2
    WHERE t.media_status IS NOT NULL);
SELECT 'T9b the one matched row' AS test, '3:in_progress' AS expected, @actual AS actual,
       IF(@actual = '3:in_progress', 'PASS', 'FAIL') AS result;

-- T10  Q10: Twin Peaks episodes 94, 47, 47, NULL
SET @actual = (
    SELECT CONCAT_WS(':', COUNT(*), COUNT(duration_minutes), SUM(duration_minutes),
                     AVG(duration_minutes), AVG(COALESCE(duration_minutes, 0)))
    FROM tv_episodes WHERE media_id = 2);
SELECT 'T10 aggregates skip the NULL duration' AS test, '4:3:188.00:62.666667:47.000000' AS expected,
       @actual AS actual, IF(@actual = '4:3:188.00:62.666667:47.000000', 'PASS', 'FAIL') AS result;

ROLLBACK;

-- =====================================================================
-- T11  Everything was rolled back: seed row counts for
--      users, user_groups, member_of, friends, tracks, reviews, review_tags, tag, has_tag,
--      media, movies, tv_shows, tv_episodes
-- =====================================================================
SET @actual = CONCAT_WS(',',
    (SELECT COUNT(*) FROM users),       (SELECT COUNT(*) FROM user_groups),
    (SELECT COUNT(*) FROM member_of),   (SELECT COUNT(*) FROM friends),
    (SELECT COUNT(*) FROM tracks),      (SELECT COUNT(*) FROM reviews),
    (SELECT COUNT(*) FROM review_tags), (SELECT COUNT(*) FROM tag),
    (SELECT COUNT(*) FROM has_tag),     (SELECT COUNT(*) FROM media),
    (SELECT COUNT(*) FROM movies),      (SELECT COUNT(*) FROM tv_shows),
    (SELECT COUNT(*) FROM tv_episodes));
SELECT 'T11 data back to the seed row counts' AS test, '3,1,3,3,3,1,2,4,14,7,2,1,3' AS expected,
       @actual AS actual, IF(@actual = '3,1,3,3,3,1,2,4,14,7,2,1,3', 'PASS', 'FAIL') AS result;

DROP PROCEDURE IF EXISTS expect_outcome;
