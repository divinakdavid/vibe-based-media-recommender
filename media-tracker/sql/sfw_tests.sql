-- sfw_tests.sql
-- Evidence for SELECT-FROM-WHERE 
--
-- The data is unchanged afterwards and the file can be run any number of times.
--


USE media_tracker;

START TRANSACTION;

-- ---------------------------------------------------------------------
-- T1  Complex conditions (3 constraints, 4 tables, ORDER BY)
-- ---------------------------------------------------------------------
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(show_title, '/', episode, '/', duration_minutes)
                        ORDER BY duration_minutes DESC SEPARATOR ', ')
    FROM (
        SELECT m.title AS show_title, e.title AS episode, e.duration_minutes
        FROM tv_episodes AS e
        JOIN media   AS m ON m.media_id = e.media_id
        JOIN has_tag AS h ON h.media_id = m.media_id
        JOIN tag     AS g ON g.tag_id   = h.tag_id
        WHERE e.duration_minutes > 45
        AND g.name = 'mystery'
        AND e.season_number = 1
    ) AS q);
SET @expected = 'Twin Peaks/Pilot/94.00, Twin Peaks/Traces to Nowhere/47.00';
SELECT 'T1 complex conditions (JOIN, AND, ORDER BY)' AS test,
    @expected AS expected, @actual AS actual,
    IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T2-T5  Constraints as queries: each must return 0 rows
-- ---------------------------------------------------------------------
SET @actual = (SELECT COUNT(*) FROM media WHERE release_year < 1400);
SELECT 'T2 value range: released before 1400' AS test, 0 AS expected, @actual AS actual,
    IF(@actual = 0, 'PASS', 'FAIL') AS result;

SET @actual = (SELECT COUNT(*) FROM friends WHERE follower_id = followed_id);
SELECT 'T3 attribute relationship: follows self' AS test, 0 AS expected, @actual AS actual,
    IF(@actual = 0, 'PASS', 'FAIL') AS result;

SET @actual = (SELECT COUNT(*) FROM media AS a, media AS b
            WHERE a.media_id < b.media_id AND a.title = b.title);
SELECT 'T4 key/uniqueness (×): same title' AS test, 0 AS expected, @actual AS actual,
    IF(@actual = 0, 'PASS', 'FAIL') AS result;

SET @actual = (SELECT COUNT(*) FROM users AS u1, users AS u2
            WHERE u1.username = u2.username AND u1.email <> u2.email);
SELECT 'T5 FD username -> email' AS test, 0 AS expected, @actual AS actual,
    IF(@actual = 0, 'PASS', 'FAIL') AS result;

-- T4b  Prove the uniqueness query really catches a violation:
--      add a second "Twin Peaks", the count must go from 0 to 1. (Rolled back at the end.)
INSERT INTO media (media_id, title, release_year, summary)
VALUES (990, 'Twin Peaks', 2017, 'Test duplicate title, removed by ROLLBACK.');
SET @actual = (SELECT COUNT(*) FROM media AS a, media AS b
            WHERE a.media_id < b.media_id AND a.title = b.title);
SELECT 'T4b uniqueness query detects a duplicate' AS test, 1 AS expected, @actual AS actual,
    IF(@actual = 1, 'PASS', 'FAIL') AS result;
DELETE FROM media WHERE media_id = 990;

-- ---------------------------------------------------------------------
-- T6  Self-join with AS: pairs of users who follow each other
-- ---------------------------------------------------------------------
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(u1.username, '<->', u2.username) SEPARATOR ', ')
    FROM friends AS f1
    JOIN friends AS f2 ON f2.follower_id = f1.followed_id
                      AND f2.followed_id = f1.follower_id
    JOIN users   AS u1 ON u1.user_id = f1.follower_id
    JOIN users   AS u2 ON u2.user_id = f1.followed_id
    WHERE f1.follower_id < f1.followed_id);
SET @expected = 'muskan<->divina';
SELECT 'T6 self-join with AS: mutual follows' AS test,
       @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T7  Remaining keywords
-- ---------------------------------------------------------------------
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(u.username, '/', m.title) ORDER BY u.username SEPARATOR ', ')
    FROM tracks AS t
    JOIN users  AS u ON u.user_id  = t.user_id
    JOIN media  AS m ON m.media_id = t.media_id
    WHERE NOT t.media_status = 'finished');
SET @expected = 'divina/Knives Out, grace/Twin Peaks';
SELECT 'T7a NOT: tracked but not finished' AS test,
       @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;

SET @actual = (
    SELECT GROUP_CONCAT(m.title SEPARATOR ', ')
    FROM books AS b
    JOIN media AS m ON m.media_id = b.media_id
    WHERE b.isbn IS NOT NULL);
SET @expected = 'The Secret History';
SELECT 'T7b IS: books with an ISBN' AS test,
       @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;

SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(song, '/', minutes) ORDER BY minutes DESC SEPARATOR ', ')
    FROM (
        SELECT m.title AS song, s.duration_minutes AS minutes
        FROM songs AS s
        JOIN media AS m ON m.media_id = s.media_id
        WHERE m.title LIKE '%Sonata%' OR m.title LIKE 'Clair%'
    ) AS q);
SET @expected = 'Moonlight Sonata/6.00, Clair de Lune/5.00';
SELECT 'T7c LIKE and AS: matching songs' AS test,
    @expected AS expected, @actual AS actual,
    IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;

SET @actual = (
    SELECT GROUP_CONCAT(title ORDER BY release_year DESC SEPARATOR ', ')
    FROM (SELECT title, release_year FROM media ORDER BY release_year DESC LIMIT 3) AS q);
SET @expected = 'Knives Out, Serial, The Secret History';
SELECT 'T7d LIMIT: 3 newest media' AS test,
    @expected AS expected, @actual AS actual,
    IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T8  Complex-predicate DML: same FROM and WHERE as T1
-- ---------------------------------------------------------------------
UPDATE tv_episodes AS e
JOIN media   AS m ON m.media_id = e.media_id
JOIN has_tag AS h ON h.media_id = m.media_id
JOIN tag     AS g ON g.tag_id   = h.tag_id
SET e.title = CONCAT(e.title, ' (Mystery Marathon)')
WHERE e.duration_minutes > 45
AND g.name = 'mystery'
AND e.season_number = 1;
SET @rows_changed = ROW_COUNT();
SET @marked = (SELECT GROUP_CONCAT(title ORDER BY season_number, episode_number SEPARATOR ', ')
            FROM tv_episodes WHERE title LIKE '%(Mystery Marathon)');
SELECT 'T8 DML: UPDATE with the same FROM/WHERE' AS test,
    2 AS expected, @rows_changed AS actual,
    IF(@rows_changed = 2
        AND @marked = 'Pilot (Mystery Marathon), Traces to Nowhere (Mystery Marathon)',
        'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- Undo everything this file changed (the duplicate title and the UPDATE).
-- ---------------------------------------------------------------------
ROLLBACK;

SET @left = (SELECT COUNT(*) FROM tv_episodes WHERE title LIKE '%Marathon%')
        + (SELECT COUNT(*) FROM media WHERE media_id = 990);
SELECT 'T9 data unchanged after ROLLBACK' AS test, 0 AS expected, @left AS actual,
    IF(@left = 0, 'PASS', 'FAIL') AS result;

-- Keyword coverage across sfw_queries.sql (13/13):
-- SELECT, FROM, WHERE, × (FROM a, b in T4/T5), JOIN, AND, OR, NOT, IS, AS, LIKE, ORDER BY, LIMIT
