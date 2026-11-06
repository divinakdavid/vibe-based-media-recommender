-- Evidence for Sub-queries. Every query is in subquery_queries.sql; this file runs it and prints
-- PASS/FAIL against the result worked out by hand from seed_data.sql.
--
--   T1  IN: nested three levels deep, and NOT IN to remove what was already reviewed
--   T2  Negated existential conditions: NOT EXISTS, the NOT IN / NULL trap, and the LEFT JOIN
--       rewrite that gives the same answer
--   T3  "For all" questions (double NOT EXISTS), checked against a COUNT formulation
--   T4  ALL: the most-used vibe, and items released before every movie
--   T5  Correlated sub-queries: per-show and per-type averages, EXISTS inside EXISTS
--   T6  Sub-queries in the projection (SELECT list), and why a join cannot replace them
--   T7  Multiple aggregations: an average of counts, and WITH + ALL on the averages
--   T8  WITH: a recommendation built from named steps
--   T9  Everything is a SELECT: the data is unchanged afterwards
--
-- Every check compares the rows a query returns, turned into one string, with the expected
-- string. Rows are joined with commas and the columns of a row with colons; "(none)" means the
-- query returned no rows.
--
-- The file can be run any number of times. Run it after seed_data.sql and BEFORE load_csv.sql
-- (that script adds more media, which changes the answers).
--
-- Run with:  mysql -t -u root -p < subquery_tests.sql

USE media_tracker;

-- ---------------------------------------------------------------------
-- T1  IN and NOT IN
-- ---------------------------------------------------------------------
-- T1a  Media carrying a vibe muskan used in her reviews (IN nested three levels deep)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE m.media_id IN (SELECT h.media_id
                             FROM has_tag AS h
                             WHERE h.tag_id IN (SELECT rt.tag_id
                                                FROM review_tags AS rt
                                                WHERE rt.user_id = (SELECT u.user_id
                                                                    FROM users AS u
                                                                    WHERE u.username = 'muskan')))
    ) AS q);
SELECT 'T1a IN, three levels: vibes muskan used' AS test, '1,2,5,6,7' AS expected, @actual AS actual,
       IF(@actual = '1,2,5,6,7', 'PASS', 'FAIL') AS result;

-- T1b  The same, minus what muskan has already reviewed (NOT IN)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE m.media_id IN (SELECT h.media_id
                             FROM has_tag AS h
                             WHERE h.tag_id IN (SELECT rt.tag_id
                                                FROM review_tags AS rt
                                                WHERE rt.user_id = (SELECT u.user_id
                                                                    FROM users AS u
                                                                    WHERE u.username = 'muskan')))
          AND m.media_id NOT IN (SELECT r.media_id
                                 FROM reviews AS r
                                 WHERE r.user_id = (SELECT u.user_id
                                                    FROM users AS u
                                                    WHERE u.username = 'muskan'))
    ) AS q);
SELECT 'T1b NOT IN: not yet reviewed by muskan' AS test, '2,5,6,7' AS expected, @actual AS actual,
       IF(@actual = '2,5,6,7', 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T2  Negated existential conditions
-- ---------------------------------------------------------------------
-- T2a  Media nobody tracks (correlated NOT EXISTS)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE NOT EXISTS (SELECT 1 FROM tracks AS t WHERE t.media_id = m.media_id)
    ) AS q);
SELECT 'T2a NOT EXISTS: media nobody tracks' AS test, '4,5,6,7' AS expected, @actual AS actual,
       IF(@actual = '4,5,6,7', 'PASS', 'FAIL') AS result;

-- T2b  Users who never wrote a review
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.username ORDER BY q.user_id), '(none)') FROM (
        SELECT u.user_id, u.username
        FROM users AS u
        WHERE NOT EXISTS (SELECT 1 FROM reviews AS r WHERE r.user_id = u.user_id)
    ) AS q);
SELECT 'T2b NOT EXISTS: users with no review' AS test, 'divina,grace' AS expected, @actual AS actual,
       IF(@actual = 'divina,grace', 'PASS', 'FAIL') AS result;

-- T2c  The NULL trap: one NULL in the NOT IN list removes EVERY row
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE m.media_id NOT IN (SELECT t.media_id FROM tracks AS t
                                 UNION ALL
                                 SELECT NULL)
    ) AS q);
SELECT 'T2c NOT IN with a NULL returns nothing' AS test, '(none)' AS expected, @actual AS actual,
       IF(@actual = '(none)', 'PASS', 'FAIL') AS result;

-- T2d  NOT EXISTS is not fooled by the same NULL
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE NOT EXISTS (SELECT 1
                          FROM (SELECT t.media_id FROM tracks AS t
                                UNION ALL
                                SELECT NULL) AS listed
                          WHERE listed.media_id = m.media_id)
    ) AS q);
SELECT 'T2d NOT EXISTS ignores the NULL' AS test, '4,5,6,7' AS expected, @actual AS actual,
       IF(@actual = '4,5,6,7', 'PASS', 'FAIL') AS result;

-- T2e  A LEFT JOIN ... IS NULL gives the same answer as NOT EXISTS (so for this question the
--      sub-query is a choice, not a necessity)
SET @not_exists = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE NOT EXISTS (SELECT 1 FROM tracks AS t WHERE t.media_id = m.media_id)
    ) AS q);
SET @left_join = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        LEFT JOIN tracks AS t ON t.media_id = m.media_id
        WHERE t.media_id IS NULL
    ) AS q);
SELECT 'T2e NOT EXISTS = LEFT JOIN ... IS NULL' AS test, '4,5,6,7 / 4,5,6,7' AS expected,
       CONCAT(@not_exists, ' / ', @left_join) AS actual,
       IF(@not_exists = '4,5,6,7' AND @left_join = '4,5,6,7', 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T3  "For all" questions
-- ---------------------------------------------------------------------
-- T3a  Groups that recommend EVERY TV show (double NOT EXISTS)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.group_id ORDER BY q.group_id), '(none)') FROM (
        SELECT g.group_id
        FROM user_groups AS g
        WHERE NOT EXISTS (SELECT 1
                          FROM tv_shows AS s
                          WHERE NOT EXISTS (SELECT 1
                                            FROM recommends AS r
                                            WHERE r.group_id = g.group_id
                                              AND r.media_id = s.media_id))
    ) AS q);
SELECT 'T3a every TV show is recommended' AS test, '1' AS expected, @actual AS actual,
       IF(@actual = '1', 'PASS', 'FAIL') AS result;

-- T3b  The same for movies: the group recommends neither movie
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.group_id ORDER BY q.group_id), '(none)') FROM (
        SELECT g.group_id
        FROM user_groups AS g
        WHERE NOT EXISTS (SELECT 1
                          FROM movies AS s
                          WHERE NOT EXISTS (SELECT 1
                                            FROM recommends AS r
                                            WHERE r.group_id = g.group_id
                                              AND r.media_id = s.media_id))
    ) AS q);
SELECT 'T3b every movie is recommended: nobody' AS test, '(none)' AS expected, @actual AS actual,
       IF(@actual = '(none)', 'PASS', 'FAIL') AS result;

-- T3c  A COUNT formulation of T3a gives the same group: the number of TV shows the group
--      recommends equals the number of TV shows there are
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.group_id ORDER BY q.group_id), '(none)') FROM (
        SELECT g.group_id
        FROM user_groups AS g
        WHERE (SELECT COUNT(DISTINCT r.media_id)
               FROM recommends AS r
               JOIN tv_shows AS s ON s.media_id = r.media_id
               WHERE r.group_id = g.group_id) = (SELECT COUNT(*) FROM tv_shows)
    ) AS q);
SELECT 'T3c COUNT formulation agrees with T3a' AS test, '1' AS expected, @actual AS actual,
       IF(@actual = '1', 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T4  ALL
-- ---------------------------------------------------------------------
-- T4a  The most-used vibe: HAVING COUNT(*) >= ALL (the counts of every vibe)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.name, q.items) ORDER BY q.name), '(none)') FROM (
        SELECT t.name, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id = t.tag_id
        GROUP BY t.tag_id, t.name
        HAVING COUNT(*) >= ALL (SELECT COUNT(*) FROM has_tag GROUP BY tag_id)
    ) AS q);
SELECT 'T4a >= ALL: the most-used vibe' AS test, 'melancholy:5' AS expected, @actual AS actual,
       IF(@actual = 'melancholy:5', 'PASS', 'FAIL') AS result;

-- T4b  Items released before EVERY movie (< ALL)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media AS m
        WHERE m.release_year < ALL (SELECT m2.release_year
                                    FROM media AS m2
                                    JOIN movies AS mv ON mv.media_id = m2.media_id)
    ) AS q);
SELECT 'T4b < ALL: before every movie' AS test, '5,7' AS expected, @actual AS actual,
       IF(@actual = '5,7', 'PASS', 'FAIL') AS result;

-- T4c  ">= ALL the counts" is the same as "= the largest count"
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.name, q.items) ORDER BY q.name), '(none)') FROM (
        SELECT t.name, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id = t.tag_id
        GROUP BY t.tag_id, t.name
        HAVING COUNT(*) = (SELECT MAX(c.n)
                           FROM (SELECT COUNT(*) AS n FROM has_tag GROUP BY tag_id) AS c)
    ) AS q);
SELECT 'T4c ALL agrees with MAX' AS test, 'melancholy:5' AS expected, @actual AS actual,
       IF(@actual = 'melancholy:5', 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T5  Correlated sub-queries
-- ---------------------------------------------------------------------
-- T5a  Episodes longer than the average episode of their own show
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.media_id, q.season_number, q.episode_number, q.title)
                               ORDER BY q.media_id, q.season_number, q.episode_number), '(none)') FROM (
        SELECT e.media_id, e.season_number, e.episode_number, e.title
        FROM tv_episodes AS e
        WHERE e.duration_minutes > (SELECT AVG(e2.duration_minutes)
                                    FROM tv_episodes AS e2
                                    WHERE e2.media_id = e.media_id)
    ) AS q);
SELECT 'T5a episode above its own show average' AS test, '2:1:1:Pilot' AS expected, @actual AS actual,
       IF(@actual = '2:1:1:Pilot', 'PASS', 'FAIL') AS result;

-- T5b  Media released after the average year of their own type
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id
        FROM media_with_type AS m
        WHERE m.release_year > (SELECT AVG(m2.release_year)
                                FROM media_with_type AS m2
                                WHERE m2.media_type = m.media_type)
    ) AS q);
SELECT 'T5b above the average year of its type' AS test, '3,7' AS expected, @actual AS actual,
       IF(@actual = '3,7', 'PASS', 'FAIL') AS result;

-- T5c  Users who reviewed something they also track (EXISTS inside EXISTS)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.username ORDER BY q.user_id), '(none)') FROM (
        SELECT u.user_id, u.username
        FROM users AS u
        WHERE EXISTS (SELECT 1
                      FROM reviews AS r
                      WHERE r.user_id = u.user_id
                        AND EXISTS (SELECT 1
                                    FROM tracks AS t
                                    WHERE t.user_id = r.user_id
                                      AND t.media_id = r.media_id))
    ) AS q);
SELECT 'T5c EXISTS inside EXISTS' AS test, 'muskan' AS expected, @actual AS actual,
       IF(@actual = 'muskan', 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T6  Sub-queries in the projection
-- ---------------------------------------------------------------------
-- T6a  Finished items and reviews per user: users with none still appear, with 0
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.username, q.finished, q.reviews) ORDER BY q.user_id), '(none)') FROM (
        SELECT u.user_id, u.username,
               (SELECT COUNT(*)
                FROM tracks AS t
                WHERE t.user_id = u.user_id AND t.media_status = 'finished') AS finished,
               (SELECT COUNT(*)
                FROM reviews AS r
                WHERE r.user_id = u.user_id) AS reviews
        FROM users AS u
    ) AS q);
SELECT 'T6a counts per user in the SELECT list' AS test, 'muskan:1:1,divina:0:0,grace:0:0' AS expected,
       @actual AS actual,
       IF(@actual = 'muskan:1:1,divina:0:0,grace:0:0', 'PASS', 'FAIL') AS result;

-- T6b  Vibes and trackers per media item: two independent counts side by side
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.media_id, q.vibes, q.trackers) ORDER BY q.media_id), '(none)') FROM (
        SELECT m.media_id,
               (SELECT COUNT(*) FROM has_tag AS h WHERE h.media_id = m.media_id) AS vibes,
               (SELECT COUNT(*) FROM tracks  AS t WHERE t.media_id = m.media_id) AS trackers
        FROM media AS m
    ) AS q);
SELECT 'T6b vibes and trackers per item' AS test, '1:3:1,2:2:1,3:2:1,4:1:0,5:2:0,6:2:0,7:2:0' AS expected,
       @actual AS actual,
       IF(@actual = '1:3:1,2:2:1,3:2:1,4:1:0,5:2:0,6:2:0,7:2:0', 'PASS', 'FAIL') AS result;

-- T6c  The inner-join version cannot do this: it returns only the 3 items that have a tracker,
--      so 4 of the 7 items disappear
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT m.media_id
        FROM media AS m
        JOIN has_tag AS h ON h.media_id = m.media_id
        JOIN tracks  AS t ON t.media_id = m.media_id
        GROUP BY m.media_id
    ) AS q);
SELECT 'T6c a join keeps only 3 of the 7 items' AS test, 3 AS expected, @actual AS actual,
       IF(@actual = 3, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T7  Multiple aggregations
-- ---------------------------------------------------------------------
-- T7a  Average number of vibes per media type (an average of counts)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.media_type, q.avg_vibes, q.items) ORDER BY q.media_type), '(none)') FROM (
        SELECT per_item.media_type, AVG(per_item.vibes) AS avg_vibes, COUNT(*) AS items
        FROM (SELECT mt.media_id, mt.media_type, COUNT(h.tag_id) AS vibes
              FROM media_with_type AS mt
              LEFT JOIN has_tag AS h ON h.media_id = mt.media_id
              GROUP BY mt.media_id, mt.media_type) AS per_item
        GROUP BY per_item.media_type
    ) AS q);
SELECT 'T7a average of counts per media type' AS test,
       'book:3.0000:1,movie:2.0000:2,podcast:1.0000:1,song:2.0000:2,tv_show:2.0000:1' AS expected,
       @actual AS actual,
       IF(@actual = 'book:3.0000:1,movie:2.0000:2,podcast:1.0000:1,song:2.0000:2,tv_show:2.0000:1', 'PASS', 'FAIL') AS result;

-- T7b  The type with the highest average (WITH + ALL)
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(CONCAT_WS(':', q.media_type, q.avg_vibes) ORDER BY q.media_type), '(none)') FROM (
        WITH per_item AS (SELECT mt.media_id, mt.media_type, COUNT(h.tag_id) AS vibes
                          FROM media_with_type AS mt
                          LEFT JOIN has_tag AS h ON h.media_id = mt.media_id
                          GROUP BY mt.media_id, mt.media_type),
             per_type AS (SELECT media_type, AVG(vibes) AS avg_vibes
                          FROM per_item
                          GROUP BY media_type)
        SELECT media_type, avg_vibes
        FROM per_type
        WHERE avg_vibes >= ALL (SELECT avg_vibes FROM per_type)
    ) AS q);
SELECT 'T7b WITH + ALL: highest average' AS test, 'book:3.0000' AS expected, @actual AS actual,
       IF(@actual = 'book:3.0000', 'PASS', 'FAIL') AS result;

-- T7c  Sanity check: the per-type item counts add up to all 7 media items, each counted once
SET @actual = (
    SELECT SUM(q.items) FROM (
        SELECT per_item.media_type, COUNT(*) AS items
        FROM (SELECT mt.media_id, mt.media_type
              FROM media_with_type AS mt
              LEFT JOIN has_tag AS h ON h.media_id = mt.media_id
              GROUP BY mt.media_id, mt.media_type) AS per_item
        GROUP BY per_item.media_type
    ) AS q);
SELECT 'T7c per-type items add up to all media' AS test, 7 AS expected, @actual AS actual,
       IF(@actual = 7, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T8  WITH: a recommendation built from named steps
-- ---------------------------------------------------------------------
-- T8a  For grace: finished by someone she follows and not yet tracked by her
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        WITH me AS (SELECT user_id FROM users WHERE username = 'grace'),
             followed AS (SELECT f.followed_id AS user_id
                          FROM friends AS f
                          JOIN me ON f.follower_id = me.user_id),
             finished_by_followed AS (SELECT DISTINCT t.media_id
                                      FROM tracks AS t
                                      JOIN followed AS fo ON fo.user_id = t.user_id
                                      WHERE t.media_status = 'finished')
        SELECT m.media_id
        FROM media AS m
        WHERE m.media_id IN (SELECT media_id FROM finished_by_followed)
          AND NOT EXISTS (SELECT 1
                          FROM tracks AS t
                          JOIN me ON t.user_id = me.user_id
                          WHERE t.media_id = m.media_id)
    ) AS q);
SELECT 'T8a recommendation for grace' AS test, '1' AS expected, @actual AS actual,
       IF(@actual = '1', 'PASS', 'FAIL') AS result;

-- T8b  For muskan: the one person she follows who has finished anything is nobody, so nothing
SET @actual = (
    SELECT IFNULL(GROUP_CONCAT(q.media_id ORDER BY q.media_id), '(none)') FROM (
        WITH me AS (SELECT user_id FROM users WHERE username = 'muskan'),
             followed AS (SELECT f.followed_id AS user_id
                          FROM friends AS f
                          JOIN me ON f.follower_id = me.user_id),
             finished_by_followed AS (SELECT DISTINCT t.media_id
                                      FROM tracks AS t
                                      JOIN followed AS fo ON fo.user_id = t.user_id
                                      WHERE t.media_status = 'finished')
        SELECT m.media_id
        FROM media AS m
        WHERE m.media_id IN (SELECT media_id FROM finished_by_followed)
          AND NOT EXISTS (SELECT 1
                          FROM tracks AS t
                          JOIN me ON t.user_id = me.user_id
                          WHERE t.media_id = m.media_id)
    ) AS q);
SELECT 'T8b recommendation for muskan: none' AS test, '(none)' AS expected, @actual AS actual,
       IF(@actual = '(none)', 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T9  Nothing was changed
-- ---------------------------------------------------------------------
SET @actual = (SELECT CONCAT_WS(',', (SELECT COUNT(*) FROM users),
                                     (SELECT COUNT(*) FROM media),
                                     (SELECT COUNT(*) FROM has_tag)));
SELECT 'T9 users, media, has_tag unchanged' AS test, '3,7,14' AS expected, @actual AS actual,
       IF(@actual = '3,7,14', 'PASS', 'FAIL') AS result;