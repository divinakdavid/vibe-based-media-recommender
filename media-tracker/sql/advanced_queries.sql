-- advanced_queries.sql
-- Advanced SQL: how foreign keys affect INSERT, UPDATE and DELETE (Q1-Q5), and how NULL values
-- change query results (Q6-Q10). advanced_tests.sql checks every query here.
--
-- FOREIGN KEY POLICIES: what happens to the child rows when a parent row is deleted (ON DELETE)
-- or its key is changed (ON UPDATE):
--   RESTRICT / NO ACTION  refuse the change while a child row points at the parent (ERROR 1451).
--                         NO ACTION is the default; in MySQL it behaves exactly like RESTRICT.
--   CASCADE               do the same to the children (delete them, or change their key too)
--   SET NULL              keep the children, set their foreign key to NULL (column must allow NULL)
--   SET DEFAULT           in the SQL standard, but MySQL's InnoDB does not carry it out
-- This schema uses CASCADE for rows that only make sense with their parent, RESTRICT for a
-- group's creator and for tags in use, and ON UPDATE RESTRICT everywhere.
--
-- Which operations a foreign key  child(fk) -> parent(key)  affects:
--   INSERT into the child, UPDATE of the child's fk   refused if the parent is missing (ERROR 1452),
--                                                     whatever the policy
--   DELETE from the parent                            the ON DELETE policy
--   UPDATE of the parent's key                        the ON UPDATE policy
--   never: INSERT into the parent, DELETE from the child, UPDATE of a column nobody references
--
-- NULL: a comparison with NULL is neither TRUE nor FALSE but UNKNOWN (three-valued logic).
-- WHERE, ON and HAVING keep a row only when the condition is TRUE, so UNKNOWN rows disappear.
--
-- Every query runs inside a transaction that is rolled back, so the data ends as it started.
-- Statements that are EXPECTED to fail run through the helper try_statement, which prints the
-- error as a row instead of stopping the script.
-- Run it after seed_data.sql and BEFORE load_csv.sql (that script adds more media):
--     mysql -t -u root -p < advanced_queries.sql

USE media_tracker;

SET FOREIGN_KEY_CHECKS = 1;

-- Helper (created before any transaction, because CREATE PROCEDURE ends a transaction).
-- rows_affected counts only rows of the table in the statement, never cascaded rows.
DROP PROCEDURE IF EXISTS try_statement;

DELIMITER //
CREATE PROCEDURE try_statement(IN step VARCHAR(100), IN stmt TEXT)
BEGIN
    DECLARE err_no  INT  DEFAULT 0;
    DECLARE err_msg TEXT DEFAULT '';
    DECLARE changed INT  DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        GET DIAGNOSTICS CONDITION 1 err_no = MYSQL_ERRNO, err_msg = MESSAGE_TEXT;

    SET @try_stmt = stmt;
    PREPARE s FROM @try_stmt;
    IF err_no = 0 THEN
        EXECUTE s;
        SET changed = ROW_COUNT();
        DEALLOCATE PREPARE s;
    END IF;

    SELECT step                                           AS statement,
           IF(err_no = 0, 'OK', CONCAT('ERROR ', err_no)) AS outcome,
           IF(err_no = 0, GREATEST(changed, 0), 0)        AS rows_affected,
           LEFT(err_msg, 120)                             AS error_message;
END//
DELIMITER ;

-- =====================================================================
-- FOREIGN KEYS AND DML
-- =====================================================================

-- Q1) INSERT into a child: grace starts tracking The Secret History, but the app sends user 99,
--     who does not exist. tracks.user_id -> users refuses it, whatever the ON DELETE policy.
-- Expected:   ERROR 1452 (Cannot add or update a child row); tracks still has 3 rows
START TRANSACTION;
CALL try_statement('Q1 track media 1 as user 99',
    'INSERT INTO tracks (user_id, media_id, media_status) VALUES (99, 1, ''want_to_consume'')');
SELECT COUNT(*) AS tracks_rows FROM tracks;
ROLLBACK;

-- Q2) UPDATE of a child's foreign key: change The Secret History's "dark academia" vibe (tag 1)
--     to tag 99, which does not exist. Changing the fk column is checked just like an INSERT.
-- Expected:   ERROR 1452; has_tag (1, 1) is unchanged
START TRANSACTION;
CALL try_statement('Q2 change a vibe to tag 99',
    'UPDATE has_tag SET tag_id = 99 WHERE media_id = 1 AND tag_id = 1');
SELECT media_id, tag_id FROM has_tag WHERE media_id = 1 ORDER BY tag_id;
ROLLBACK;

-- Q3) DELETE a parent with ON DELETE CASCADE: muskan (1) deletes her account. She created no
--     group, so nothing RESTRICTs it. Her memberships, friendships, tracks and reviews are
--     CASCADE, and the cascade goes a second level: reviews -> review_tags (also CASCADE).
-- Expected:   before: 1 membership, 3 friendships, 1 tracks row, 1 review, 2 review tags
--             DELETE: OK, 1 row (the cascaded rows are not counted)
--             after:  every count 0
START TRANSACTION;
SELECT (SELECT COUNT(*) FROM member_of   WHERE user_id = 1)                          AS memberships,
       (SELECT COUNT(*) FROM friends     WHERE follower_id = 1 OR followed_id = 1)  AS friendships,
       (SELECT COUNT(*) FROM tracks      WHERE user_id = 1)                          AS tracks,
       (SELECT COUNT(*) FROM reviews     WHERE user_id = 1)                          AS reviews,
       (SELECT COUNT(*) FROM review_tags WHERE user_id = 1)                          AS review_tags;
CALL try_statement('Q3 delete muskan', 'DELETE FROM users WHERE user_id = 1');
SELECT (SELECT COUNT(*) FROM member_of   WHERE user_id = 1)                          AS memberships,
       (SELECT COUNT(*) FROM friends     WHERE follower_id = 1 OR followed_id = 1)  AS friendships,
       (SELECT COUNT(*) FROM tracks      WHERE user_id = 1)                          AS tracks,
       (SELECT COUNT(*) FROM reviews     WHERE user_id = 1)                          AS reviews,
       (SELECT COUNT(*) FROM review_tags WHERE user_id = 1)                          AS review_tags;
ROLLBACK;

-- Q4) DELETE a parent with ON DELETE RESTRICT: grace (3) created Spooky Season Club, and
--     user_groups.creator_id is RESTRICT, so the DELETE is refused. Her other rows are CASCADE;
--     do they go anyway? No: a statement either completes in full or changes nothing.
--     To get past RESTRICT, remove the reference first: hand the group to muskan.
-- Expected:   ERROR 1451; grace still has 1 membership, 1 friendship, 1 tracks row;
--             after handing over the group: OK, OK, and grace has nothing left
START TRANSACTION;
CALL try_statement('Q4 delete grace (group creator)', 'DELETE FROM users WHERE user_id = 3');
SELECT (SELECT COUNT(*) FROM users     WHERE user_id = 3)                          AS grace_exists,
       (SELECT COUNT(*) FROM member_of WHERE user_id = 3)                          AS memberships,
       (SELECT COUNT(*) FROM friends   WHERE follower_id = 3 OR followed_id = 3)  AS friendships,
       (SELECT COUNT(*) FROM tracks    WHERE user_id = 3)                          AS tracks;
CALL try_statement('Q4 hand the group to muskan', 'UPDATE user_groups SET creator_id = 1 WHERE group_id = 1');
CALL try_statement('Q4 delete grace again',       'DELETE FROM users WHERE user_id = 3');
SELECT (SELECT COUNT(*) FROM users     WHERE user_id = 3)                          AS grace_exists,
       (SELECT COUNT(*) FROM member_of WHERE user_id = 3)                          AS memberships,
       (SELECT COUNT(*) FROM friends   WHERE follower_id = 3 OR followed_id = 3)  AS friendships,
       (SELECT COUNT(*) FROM tracks    WHERE user_id = 3)                          AS tracks;
ROLLBACK;

-- Q5) UPDATE a parent: has_tag.tag_id -> tag is ON UPDATE RESTRICT. Changing the KEY of a tag in
--     use is refused; renaming it is allowed, because no foreign key references the name.
--     Deleting a has_tag row (the child) is never blocked.
-- Expected:   ERROR 1451, OK (1 row), OK (1 row)
START TRANSACTION;
CALL try_statement('Q5 change tag 4''s id to 40',    'UPDATE tag SET tag_id = 40 WHERE tag_id = 4');
CALL try_statement('Q5 rename tag 3 to cosy',        'UPDATE tag SET name = ''cosy'' WHERE tag_id = 3');
CALL try_statement('Q5 remove a vibe from a song',   'DELETE FROM has_tag WHERE media_id = 7 AND tag_id = 3');
ROLLBACK;

-- =====================================================================
-- NULL VALUES
-- The seed data has almost no NULLs, so five media items and one episode with missing values
-- are added (ids 881-885), used by Q6-Q10, and rolled back at the end:
--   881 Wuthering Heights        book     year NULL
--   882 Jane Eyre                book     year NULL
--   883 Mulholland Drive         movie    2001, director David Lynch
--   884 Kiki's Delivery Service  movie    1989, director NULL
--   885 The Twilight Zone        TV show  1959, director NULL (many directors)
--   Twin Peaks season 2 episode 2 "Coma": duration NULL
-- With the seed data: 12 media items. Movie directors: Rian Johnson, Peter Weir, David Lynch,
-- NULL. TV directors: David Lynch, NULL.
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

-- Q6) Three-valued logic: how many items were released before 1950, and how many were not?
--     For a NULL year, "release_year < 1950" is UNKNOWN, and so is NOT (release_year < 1950).
--     Both WHEREs drop the row, so "p OR NOT p" does not cover every row.
--     (Truth tables: TRUE AND UNKNOWN = UNKNOWN, FALSE AND UNKNOWN = FALSE,
--      TRUE OR UNKNOWN = TRUE, FALSE OR UNKNOWN = UNKNOWN, NOT UNKNOWN = UNKNOWN.)
-- Expected:   all 12, before 2, not_before 8, before_or_not 10, year_unknown 2
SELECT (SELECT COUNT(*) FROM media)                                                  AS all_items,
       (SELECT COUNT(*) FROM media WHERE release_year < 1950)                       AS before_1950,
       (SELECT COUNT(*) FROM media WHERE NOT (release_year < 1950))                 AS not_before_1950,
       (SELECT COUNT(*) FROM media WHERE release_year < 1950
                                      OR NOT (release_year < 1950))                 AS before_or_not,
       (SELECT COUNT(*) FROM media WHERE release_year IS NULL)                      AS year_unknown;

-- Q7) Joining on a column that contains NULL: which directors made both a movie and a TV show?
--     Kiki's Delivery Service and The Twilight Zone both have director NULL, but NULL = NULL is
--     UNKNOWN, so the join does not pair them. MySQL's NULL-safe <=> would pair them, which is
--     wrong here: two unknown directors are not known to be the same person.
-- Expected:   1 row: Mulholland Drive, Twin Peaks, David Lynch
SELECT mm.title AS movie, tm.title AS tv_show, mo.director
FROM movies   AS mo
JOIN tv_shows AS tv ON tv.director = mo.director
JOIN media    AS mm ON mm.media_id = mo.media_id
JOIN media    AS tm ON tm.media_id = tv.media_id;

-- Q8) NOT IN versus NOT EXISTS over a nullable column: which movies were made by a director who
--     has not made a TV show? The TV directors are ('David Lynch', NULL), so for Knives Out:
--     'Rian Johnson' NOT IN ('David Lynch', NULL)
--       = 'Rian Johnson' <> 'David Lynch' AND 'Rian Johnson' <> NULL = TRUE AND UNKNOWN = UNKNOWN,
--     and every movie is dropped. NOT EXISTS only asks whether a matching show exists, and keeps
--     Kiki's too (NULL matches nothing). Filtering NULLs out of the list gives the safe answer.
-- Expected:   NOT IN: 0 rows   NOT EXISTS: 3 (Knives Out, Dead Poets Society, Kiki's Delivery
--             Service)   NOT IN without NULLs: 2 (Knives Out, Dead Poets Society)
SELECT 'NOT IN' AS version, COUNT(*) AS movies, IFNULL(GROUP_CONCAT(mm.title ORDER BY mm.media_id), '') AS titles
FROM movies AS mo JOIN media AS mm ON mm.media_id = mo.media_id
WHERE mo.director NOT IN (SELECT tv.director FROM tv_shows AS tv)
UNION ALL
SELECT 'NOT EXISTS', COUNT(*), GROUP_CONCAT(mm.title ORDER BY mm.media_id)
FROM movies AS mo JOIN media AS mm ON mm.media_id = mo.media_id
WHERE NOT EXISTS (SELECT 1 FROM tv_shows AS tv WHERE tv.director = mo.director)
UNION ALL
SELECT 'NOT IN without NULLs', COUNT(*), GROUP_CONCAT(mm.title ORDER BY mm.media_id)
FROM movies AS mo JOIN media AS mm ON mm.media_id = mo.media_id
WHERE mo.director NOT IN (SELECT tv.director FROM tv_shows AS tv WHERE tv.director IS NOT NULL);

-- Q9) Outer join: every media item with divina's status, if she tracks it.
--     A LEFT JOIN pads a media row that has no match with NULLs. The condition on tracks must go
--     in ON: there it only decides which tracks rows match, and every media row is kept.
--     In WHERE it runs after the join, and on a padded row "NULL = 2" is UNKNOWN, so the padded
--     rows are dropped and the LEFT JOIN behaves like an inner join.
--     COUNT(*) counts the padded rows too; COUNT(t.user_id) skips their NULL.
-- Expected:   condition in ON: 12 rows, 1 with a status (Knives Out, in_progress)
--             condition in WHERE: 1 row
SELECT 'in ON' AS condition_placed, COUNT(*) AS media_rows, COUNT(t.user_id) AS with_status
FROM media AS m
LEFT JOIN tracks AS t ON t.media_id = m.media_id AND t.user_id = 2
UNION ALL
SELECT 'in WHERE', COUNT(*), COUNT(t.user_id)
FROM media AS m
LEFT JOIN tracks AS t ON t.media_id = m.media_id
WHERE t.user_id = 2;

SELECT m.media_id, m.title, t.media_status AS divina_status
FROM media AS m
LEFT JOIN tracks AS t ON t.media_id = m.media_id AND t.user_id = 2
ORDER BY m.media_id;

-- Q10) Aggregates ignore NULL: statistics for the four episodes of Twin Peaks (94, 47, 47 and a
--      NULL). AVG divides by the 3 known durations, not 4. Treating the missing one as 0 is a
--      different claim and gives a different answer.
-- Expected:   episodes 4, with_duration 3, total 188.00, average 62.666667,
--             average_if_null_is_0 47.000000
SELECT COUNT(*)                            AS episodes,
       COUNT(duration_minutes)             AS with_duration,
       SUM(duration_minutes)               AS total,
       AVG(duration_minutes)               AS average,
       AVG(COALESCE(duration_minutes, 0))  AS average_if_null_is_0
FROM tv_episodes
WHERE media_id = 2;

ROLLBACK;

DROP PROCEDURE IF EXISTS try_statement;
