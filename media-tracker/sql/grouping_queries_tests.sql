-- Evidence for Grouping & Aggregation. Every query is in grouping_queries.sql; this file runs
-- it and prints PASS/FAIL against the result worked out by hand from seed_data.sql.
--
--   T1  DISTINCT removes duplicate tuples        (complex search, 3 constraints)
--   T2  GROUP BY partitions tuples               (COUNT: most popular media by number of vibes)
--   T3  ANY_VALUE / aggregates for columns that are not functionally dependent on the group,
--       and the error MySQL gives without them
--   T4  WHERE and HAVING: same result when the condition is on a GROUP BY column
--   T5  Aggregation functions: MIN, MAX, SUM, AVG, COUNT, ANY_VALUE over durations and years
--   T6  OLAP-style report: GROUP BY over three dimensions (era (derived), media type, vibe)
--
-- Everything is a SELECT, so the data is unchanged afterwards and the file can be run any
-- number of times.
--
-- Run it after seed_data.sql.
 
USE media_tracker;
 
-- Enable ONLY_FULL_GROUP_BY
SET @old_sql_mode = @@sql_mode;
SET SESSION sql_mode = CONCAT(REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''), ',ONLY_FULL_GROUP_BY');
 
-- ---------------------------------------------------------------------
-- Helper: run one statement that is EXPECTED TO FAIL, catch the error, and report whether it
-- failed with the expected MySQL error number.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS expect_error;
 
DELIMITER //
CREATE PROCEDURE expect_error(IN test_name VARCHAR(100), IN stmt TEXT, IN expected_errno INT)
BEGIN
    DECLARE actual_errno INT DEFAULT 0;
    DECLARE actual_msg   TEXT DEFAULT '';
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        GET DIAGNOSTICS CONDITION 1 actual_errno = MYSQL_ERRNO, actual_msg = MESSAGE_TEXT;
 
    SET @stmt_to_run = stmt;
    PREPARE s FROM @stmt_to_run;
    IF actual_errno = 0 THEN
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;
 
    SELECT test_name                                            AS test,
           expected_errno                                       AS expected,
           actual_errno                                         AS actual,
           IF(actual_errno = expected_errno, 'PASS', 'FAIL')    AS result,
           LEFT(actual_msg, 110)                                AS error_message;
END//
DELIMITER ;
 
-- =====================================================================
-- T1  DISTINCT removes duplicate tuples
--     Query: non-song media released before 2000 with the 'mystery' or 'melancholy' vibe.
--     3 constraints: tag IN (...), release_year < 2000, media_type <> 'song'.
-- =====================================================================
 
-- T1a  Without DISTINCT the result has duplicates: 5 rows for only 3 different media items
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT m.media_id, m.title, mt.media_type, m.release_year
        FROM media AS m
        JOIN media_with_type AS mt ON mt.media_id = m.media_id
        JOIN has_tag AS h          ON h.media_id  = m.media_id
        JOIN tag     AS t          ON t.tag_id    = h.tag_id
        WHERE t.name IN ('mystery', 'melancholy')
          AND m.release_year < 2000
          AND mt.media_type <> 'song'
    ) AS q);
SELECT 'T1a no DISTINCT: duplicate rows are kept' AS test, 5 AS expected, @actual AS actual,
       IF(@actual = 5, 'PASS', 'FAIL') AS result;
 
-- T1b  With COUNT (DISTINCT): only 3 different media items are in those 5 rows
SET @actual = (
    SELECT COUNT(DISTINCT q.media_id) FROM (
        SELECT m.media_id
        FROM media AS m
        JOIN media_with_type AS mt ON mt.media_id = m.media_id
        JOIN has_tag AS h          ON h.media_id  = m.media_id
        JOIN tag     AS t          ON t.tag_id    = h.tag_id
        WHERE t.name IN ('mystery', 'melancholy')
          AND m.release_year < 2000
          AND mt.media_type <> 'song'
    ) AS q);
SELECT 'T1b only 3 different media items in them' AS test, 3 AS expected, @actual AS actual,
       IF(@actual = 3, 'PASS', 'FAIL') AS result;
 
-- T1c  WITH DISTINCT: one tuple per media item, no duplicates left
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT DISTINCT m.media_id, m.title, mt.media_type, m.release_year
        FROM media AS m
        JOIN media_with_type AS mt ON mt.media_id = m.media_id
        JOIN has_tag AS h          ON h.media_id  = m.media_id
        JOIN tag     AS t          ON t.tag_id    = h.tag_id
        WHERE t.name IN ('mystery', 'melancholy')
          AND m.release_year < 2000
          AND mt.media_type <> 'song'
    ) AS q);
SELECT 'T1c DISTINCT removes the duplicate tuples' AS test, 3 AS expected, @actual AS actual,
       IF(@actual = 3, 'PASS', 'FAIL') AS result;
 
-- T1d  DISTINCT = GROUP BY on all the output columns (same equivalence classes)
SET @distinct_ids = (
    SELECT GROUP_CONCAT(media_id ORDER BY media_id) FROM (
        SELECT DISTINCT m.media_id, m.title, mt.media_type, m.release_year
        FROM media AS m
        JOIN media_with_type AS mt ON mt.media_id = m.media_id
        JOIN has_tag AS h          ON h.media_id  = m.media_id
        JOIN tag     AS t          ON t.tag_id    = h.tag_id
        WHERE t.name IN ('mystery', 'melancholy')
          AND m.release_year < 2000
          AND mt.media_type <> 'song'
    ) AS q);
SET @grouped_ids = (
    SELECT GROUP_CONCAT(media_id ORDER BY media_id) FROM (
        SELECT m.media_id, m.title, mt.media_type, m.release_year
        FROM media AS m
        JOIN media_with_type AS mt ON mt.media_id = m.media_id
        JOIN has_tag AS h          ON h.media_id  = m.media_id
        JOIN tag     AS t          ON t.tag_id    = h.tag_id
        WHERE t.name IN ('mystery', 'melancholy')
          AND m.release_year < 2000
          AND mt.media_type <> 'song'
        GROUP BY m.media_id, m.title, mt.media_type, m.release_year
    ) AS q);
SELECT 'T1d DISTINCT = GROUP BY on the output columns' AS test, '1,2,6' AS expected,
       @grouped_ids AS actual,
       IF(@distinct_ids = '1,2,6' AND @grouped_ids = '1,2,6', 'PASS', 'FAIL') AS result;
 
-- =====================================================================
-- T2  GROUP BY partitions tuples; COUNT ranks media by number of vibes
-- =====================================================================
 
-- T2a  Ranking: Ties alphabetically by title
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(title, '/', vibe_count) ORDER BY vibe_count DESC, title SEPARATOR ', ')
    FROM (
        SELECT m.media_id, m.title, COUNT(h.tag_id) AS vibe_count
        FROM media AS m
        JOIN has_tag AS h ON h.media_id = m.media_id
        GROUP BY m.media_id, m.title
    ) AS q);
SET @expected = 'The Secret History/3, Clair de Lune/2, Dead Poets Society/2, Knives Out/2, Moonlight Sonata/2, Twin Peaks/2, Serial/1';
SELECT 'T2a COUNT per media item: most popular first' AS test, @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T2b  One output tuple per group
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT m.media_id, COUNT(h.tag_id) AS vibe_count
        FROM media AS m
        JOIN has_tag AS h ON h.media_id = m.media_id
        GROUP BY m.media_id
    ) AS q);
SET @expected = (SELECT COUNT(DISTINCT media_id) FROM has_tag);
SELECT 'T2b one output tuple per group' AS test, @expected AS expected, @actual AS actual,
       IF(@actual = @expected AND @actual = 7, 'PASS', 'FAIL') AS result;
 
-- T2c  The groups partition the input: every has_tag row is in exactly one group,
--      so the group counts add up to the number of has_tag rows (14)
SET @actual = (
    SELECT SUM(vibe_count) FROM (
        SELECT m.media_id, COUNT(h.tag_id) AS vibe_count
        FROM media AS m
        JOIN has_tag AS h ON h.media_id = m.media_id
        GROUP BY m.media_id
    ) AS q);
SET @expected = (SELECT COUNT(*) FROM has_tag);
SELECT 'T2c group counts add up to all has_tag rows' AS test, @expected AS expected, @actual AS actual,
       IF(@actual = @expected AND @actual = 14, 'PASS', 'FAIL') AS result;
 
-- =====================================================================
-- T3  Columns that are not functionally dependent on the GROUP BY columns
-- =====================================================================
 
-- T3a  FAILED TEST: title is not determined by tag_id. MySQL must reject the query with
--      ERROR 1055 (the error text is shown in the last column).
CALL expect_error(
    'T3a title not determined by tag_id: rejected',
    'SELECT t.tag_id, m.title, COUNT(*) AS items
       FROM tag AS t
       JOIN has_tag AS h ON h.tag_id = t.tag_id
       JOIN media   AS m ON m.media_id = h.media_id
      GROUP BY t.tag_id',
    1055);
 
-- T3b  The fix works: ANY_VALUE gives exactly one title per vibe (4 vibes, 4 rows)
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT t.tag_id, ANY_VALUE(m.title) AS any_title
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id   = t.tag_id
        JOIN media   AS m ON m.media_id = h.media_id
        GROUP BY t.tag_id
    ) AS q);
SELECT 'T3b ANY_VALUE: one scalar per group' AS test, 4 AS expected, @actual AS actual,
       IF(@actual = 4, 'PASS', 'FAIL') AS result;
 
-- T3c  (continuation from T3b) and the title it returns really is one of that vibe's titles. WHICH title is
--      arbitrary, so the test checks membership, not a particular value.
SET @actual = (
    SELECT COUNT(DISTINCT q.tag_id) FROM (
        SELECT t.tag_id, ANY_VALUE(m.title) AS any_title
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id   = t.tag_id
        JOIN media   AS m ON m.media_id = h.media_id
        GROUP BY t.tag_id
    ) AS q
    JOIN has_tag AS h2 ON h2.tag_id   = q.tag_id
    JOIN media   AS m2 ON m2.media_id = h2.media_id AND m2.title = q.any_title);
SELECT 'T3c ANY_VALUE result belongs to its group' AS test, 4 AS expected, @actual AS actual,
       IF(@actual = 4, 'PASS', 'FAIL') AS result;
 
-- T3d  When the same answer must come out every time, use a deterministic aggregate:
--      MIN(title) is the alphabetically first title of each vibe
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '=', first_title) ORDER BY tag_id SEPARATOR ', ')
    FROM (
        SELECT t.tag_id, t.name AS vibe, MIN(m.title) AS first_title
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id   = t.tag_id
        JOIN media   AS m ON m.media_id = h.media_id
        GROUP BY t.tag_id
    ) AS q);
SET @expected = 'dark academia=Dead Poets Society, mystery=Knives Out, cozy=Clair de Lune, melancholy=Clair de Lune';
SELECT 'T3d MIN: deterministic title per group' AS test, @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T3e  A column that IS determined by the GROUP BY key (tag_id -> name) needs no aggregate:
--      accepted as it is, and ANY_VALUE(name) gives the very same value in every group
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT t.tag_id, t.name, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id = t.tag_id
        GROUP BY t.tag_id
        HAVING t.name = ANY_VALUE(t.name)
    ) AS q);
SELECT 'T3e FD column: no aggregate needed, ANY_VALUE agrees' AS test, 4 AS expected, @actual AS actual,
       IF(@actual = 4, 'PASS', 'FAIL') AS result;
 
-- =====================================================================
-- T4  WHERE and HAVING
-- =====================================================================
 
-- T4a  Condition on a GROUP BY column: WHERE and HAVING give the same result
SET @with_where = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', items) ORDER BY vibe SEPARATOR ', ')
    FROM (
        SELECT t.name AS vibe, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id = t.tag_id
        WHERE t.name IN ('mystery', 'melancholy')
        GROUP BY t.name
    ) AS q);
SET @with_having = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', items) ORDER BY vibe SEPARATOR ', ')
    FROM (
        SELECT t.name AS vibe, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id = t.tag_id
        GROUP BY t.name
        HAVING t.name IN ('mystery', 'melancholy')
    ) AS q);
SELECT 'T4a WHERE = HAVING (condition on the GROUP BY column)' AS test,
       @with_where AS expected, @with_having AS actual,
       IF(@with_where <=> @with_having AND @with_where = 'melancholy/5, mystery/4', 'PASS', 'FAIL') AS result;
 
-- T4b  Condition on a column that is NOT in GROUP BY: WHERE removes tuples before counting,
--      HAVING keeps or drops whole groups, so the results are NOT the same
SET @with_where = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', items) ORDER BY vibe SEPARATOR ', ')
    FROM (
        SELECT t.name AS vibe, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id   = t.tag_id
        JOIN media   AS m ON m.media_id = h.media_id
        WHERE m.release_year < 2000
        GROUP BY t.name
    ) AS q);
SET @with_having = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', items) ORDER BY vibe SEPARATOR ', ')
    FROM (
        SELECT t.name AS vibe, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id   = t.tag_id
        JOIN media   AS m ON m.media_id = h.media_id
        GROUP BY t.name
        HAVING MIN(m.release_year) < 2000
    ) AS q);
SELECT 'T4b WHERE <> HAVING (condition on a non-grouped column)' AS test,
       'cozy/1, dark academia/3, melancholy/5, mystery/2' AS expected,
       @with_where AS actual,
       IF(@with_where = 'cozy/1, dark academia/3, melancholy/5, mystery/2'
          AND @with_having = 'cozy/2, dark academia/3, melancholy/5, mystery/4'
          AND NOT (@with_where <=> @with_having), 'PASS', 'FAIL') AS result;
 
-- T4c  A condition on a group (an aggregate) works in HAVING ...
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', items) ORDER BY vibe SEPARATOR ', ')
    FROM (
        SELECT t.name AS vibe, COUNT(*) AS items
        FROM tag AS t
        JOIN has_tag AS h ON h.tag_id = t.tag_id
        GROUP BY t.name
        HAVING COUNT(*) >= 4
    ) AS q);
SELECT 'T4c HAVING COUNT(*) >= 4' AS test, 'melancholy/5, mystery/4' AS expected, @actual AS actual,
       IF(@actual <=> 'melancholy/5, mystery/4', 'PASS', 'FAIL') AS result;
 
-- T4d  (continuation from T4c) but is rejected in WHERE, Invalid use of group function
CALL expect_error(
    'T4d COUNT(*) in WHERE: rejected',
    'SELECT t.name AS vibe, COUNT(*) AS items
       FROM tag AS t
       JOIN has_tag AS h ON h.tag_id = t.tag_id
      WHERE COUNT(*) >= 4
      GROUP BY t.name',
    1111);
 
-- =====================================================================
-- T5  Aggregation functions: MIN, MAX, SUM, AVG, COUNT, ANY_VALUE
--     Durations are in movies, songs, tv_episodes and podcast_episodes; they are stacked with
--     UNION ALL (which keeps every row) before they are grouped.
-- =====================================================================
 
-- T5a  Duration summary per media type: COUNT, MIN, MAX, SUM, AVG
--      (type:items/shortest/longest/total/average)
SET @actual = (
    SELECT GROUP_CONCAT(
               CONCAT(media_type, ':', items, '/', shortest, '/', longest, '/', total_minutes, '/', average_minutes)
               ORDER BY media_type SEPARATOR ', ')
    FROM (
        SELECT d.media_type,
               COUNT(*)                          AS items,
               MIN(d.duration_minutes)           AS shortest,
               MAX(d.duration_minutes)           AS longest,
               SUM(d.duration_minutes)           AS total_minutes,
               ROUND(AVG(d.duration_minutes), 2) AS average_minutes
        FROM (
            SELECT 'movie' AS media_type, m.title, mo.duration_minutes
            FROM movies AS mo JOIN media AS m ON m.media_id = mo.media_id
            UNION ALL
            SELECT 'song', m.title, s.duration_minutes
            FROM songs AS s JOIN media AS m ON m.media_id = s.media_id
        ) AS d
        GROUP BY d.media_type
    ) AS q);
SET @expected = 'movie:2/128.00/130.00/258.00/129.00, song:2/5.00/6.00/11.00/5.50';
SELECT 'T5a COUNT/MIN/MAX/SUM/AVG of duration per media type' AS test, @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T5b  ANY_VALUE: the example title is one of that type's titles (which one is arbitrary,
--      so the test checks membership, not a particular value). Both groups must pass.
SET @actual = (
    SELECT COUNT(*) FROM (
        SELECT d.media_type, ANY_VALUE(d.title) AS example_title
        FROM (
            SELECT 'movie' AS media_type, m.title, mo.duration_minutes
            FROM movies AS mo JOIN media AS m ON m.media_id = mo.media_id
            UNION ALL
            SELECT 'song', m.title, s.duration_minutes
            FROM songs AS s JOIN media AS m ON m.media_id = s.media_id
        ) AS d
        GROUP BY d.media_type
    ) AS q
    WHERE (q.media_type = 'movie' AND q.example_title IN ('Knives Out', 'Dead Poets Society'))
       OR (q.media_type = 'song'  AND q.example_title IN ('Moonlight Sonata', 'Clair de Lune')));
SELECT 'T5b ANY_VALUE title belongs to its media type' AS test, 2 AS expected, @actual AS actual,
       IF(@actual = 2, 'PASS', 'FAIL') AS result;
 
-- T5c  Episode statistics per show: episodes/total/average/longest/shortest
SET @actual = (
    SELECT GROUP_CONCAT(
               CONCAT(title, ':', media_type, '/', episodes, '/', total_minutes, '/', average_minutes, '/', longest, '/', shortest)
               ORDER BY title SEPARATOR ', ')
    FROM (
        SELECT d.title, d.media_type,
               COUNT(*)                          AS episodes,
               SUM(d.duration_minutes)           AS total_minutes,
               ROUND(AVG(d.duration_minutes), 2) AS average_minutes,
               MAX(d.duration_minutes)           AS longest,
               MIN(d.duration_minutes)           AS shortest
        FROM (
            SELECT m.media_id, m.title, 'tv_show' AS media_type, e.duration_minutes
            FROM tv_episodes AS e JOIN media AS m ON m.media_id = e.media_id
            UNION ALL
            SELECT m.media_id, m.title, 'podcast', e.duration_minutes
            FROM podcast_episodes AS e JOIN media AS m ON m.media_id = e.media_id
        ) AS d
        GROUP BY d.media_id, d.title, d.media_type
    ) AS q);
SET @expected = 'Serial:podcast/3/139.00/46.33/52.00/41.00, Twin Peaks:tv_show/3/188.00/62.67/94.00/47.00';
SELECT 'T5c episode stats per show' AS test, @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T5d  HAVING on an average: only Twin Peaks (62.67) has an average episode over 50 minutes;
--      Serial (46.33) is dropped as a whole group
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(title, '/', average_minutes) ORDER BY title SEPARATOR ', ')
    FROM (
        SELECT d.title, ROUND(AVG(d.duration_minutes), 2) AS average_minutes
        FROM (
            SELECT m.media_id, m.title, e.duration_minutes
            FROM tv_episodes AS e JOIN media AS m ON m.media_id = e.media_id
            UNION ALL
            SELECT m.media_id, m.title, e.duration_minutes
            FROM podcast_episodes AS e JOIN media AS m ON m.media_id = e.media_id
        ) AS d
        GROUP BY d.media_id, d.title
        HAVING AVG(d.duration_minutes) > 50
    ) AS q);
SELECT 'T5d HAVING AVG(duration) > 50' AS test, 'Twin Peaks/62.67' AS expected, @actual AS actual,
       IF(@actual <=> 'Twin Peaks/62.67', 'PASS', 'FAIL') AS result;
 
-- T5e  WHERE on a set duration: only episodes under 60 minutes are counted and summed
--      (Twin Peaks loses its 94-minute pilot, so 2 episodes / 94.00 minutes)
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(title, '/', short_episodes, '/', total_minutes) ORDER BY title SEPARATOR ', ')
    FROM (
        SELECT d.title, COUNT(*) AS short_episodes, SUM(d.duration_minutes) AS total_minutes
        FROM (
            SELECT m.media_id, m.title, e.duration_minutes
            FROM tv_episodes AS e JOIN media AS m ON m.media_id = e.media_id
            UNION ALL
            SELECT m.media_id, m.title, e.duration_minutes
            FROM podcast_episodes AS e JOIN media AS m ON m.media_id = e.media_id
        ) AS d
        WHERE d.duration_minutes < 60
        GROUP BY d.media_id, d.title
    ) AS q);
SET @expected = 'Serial/3/139.00, Twin Peaks/2/94.00';
SELECT 'T5e WHERE duration < 60, then COUNT and SUM' AS test, @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T5f  MIN and MAX on release_year per media type (type:items/oldest/newest)
SET @actual = (
    SELECT GROUP_CONCAT(CONCAT(media_type, ':', items, '/', oldest, '/', newest) ORDER BY media_type SEPARATOR ', ')
    FROM (
        SELECT mt.media_type, COUNT(*) AS items, MIN(mt.release_year) AS oldest, MAX(mt.release_year) AS newest
        FROM media_with_type AS mt
        GROUP BY mt.media_type
    ) AS q);
SET @expected = 'book:1/1992/1992, movie:2/1989/2019, podcast:1/2014/2014, song:2/1801/1905, tv_show:1/1990/1990';
SELECT 'T5f MIN/MAX release_year per media type' AS test, @expected AS expected, @actual AS actual,
       IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T5g  The functions agree with each other: in every group AVG = SUM / COUNT, and the group
--      SUMs add up to the SUM of all the stacked durations (258 + 11 = 269)
SET @groups_ok = (
    SELECT COUNT(*) FROM (
        SELECT d.media_type
        FROM (
            SELECT 'movie' AS media_type, mo.duration_minutes FROM movies AS mo
            UNION ALL
            SELECT 'song', s.duration_minutes FROM songs AS s
        ) AS d
        GROUP BY d.media_type
        HAVING ROUND(AVG(d.duration_minutes), 2) = ROUND(SUM(d.duration_minutes) / COUNT(*), 2)
    ) AS q);
SET @sum_of_sums = (
    SELECT SUM(t) FROM (
        SELECT SUM(d.duration_minutes) AS t
        FROM (
            SELECT 'movie' AS media_type, mo.duration_minutes FROM movies AS mo
            UNION ALL
            SELECT 'song', s.duration_minutes FROM songs AS s
        ) AS d
        GROUP BY d.media_type
    ) AS q);
SET @total = (SELECT SUM(duration_minutes) FROM movies) + (SELECT SUM(duration_minutes) FROM songs);
SELECT 'T5g AVG = SUM/COUNT per group; group SUMs add up to the total' AS test, @total AS expected,
       @sum_of_sums AS actual,
       IF(@groups_ok = 2 AND @sum_of_sums = @total AND @total = 269, 'PASS', 'FAIL') AS result;

       -- =====================================================================
-- T6  OLAP-style report: GROUP BY over three dimensions (era, media type, vibe)
--     The report is stored once in a temporary table so the checks below can look at it from
--     different sides. (era_no only makes the eras sort in time order.)
-- =====================================================================
DROP TEMPORARY TABLE IF EXISTS olap_cells;
CREATE TEMPORARY TABLE olap_cells AS
SELECT e.era_no, e.era, mt.media_type, t.name AS vibe,
       COUNT(*)                  AS items,
       SUM(im.minutes)           AS total_minutes,
       ROUND(AVG(im.minutes), 2) AS avg_minutes
FROM has_tag AS h
JOIN media           AS m  ON m.media_id  = h.media_id
JOIN media_with_type AS mt ON mt.media_id = m.media_id
JOIN tag             AS t  ON t.tag_id    = h.tag_id
JOIN (
    SELECT media_id,
           CASE WHEN release_year < 1950 THEN 1 WHEN release_year < 2000 THEN 2 ELSE 3 END AS era_no,
           CASE WHEN release_year < 1950 THEN 'before 1950'
                WHEN release_year < 2000 THEN '1950-1999'
                ELSE '2000 and later' END AS era
    FROM media
) AS e ON e.media_id = m.media_id
LEFT JOIN (
    SELECT media_id, duration_minutes AS minutes FROM movies
    UNION ALL
    SELECT media_id, duration_minutes FROM songs
    UNION ALL
    SELECT media_id, SUM(duration_minutes) FROM tv_episodes GROUP BY media_id
    UNION ALL
    SELECT media_id, SUM(duration_minutes) FROM podcast_episodes GROUP BY media_id
) AS im ON im.media_id = m.media_id
GROUP BY e.era_no, e.era, mt.media_type, t.name;
 
-- T6a  The whole report, in report order (era newest first, then biggest total running time):
--      era|type|vibe:items/total minutes/average minutes
SET @actual = (
    SELECT GROUP_CONCAT(
               CONCAT(era, '|', media_type, '|', vibe, ':', items, '/',
                      IFNULL(total_minutes, 'NULL'), '/', IFNULL(avg_minutes, 'NULL'))
               ORDER BY era_no DESC, total_minutes DESC, media_type, vibe SEPARATOR ', ')
    FROM olap_cells);
SET @expected = CONCAT_WS(', ',
    '2000 and later|podcast|mystery:1/139.00/139.00',
    '2000 and later|movie|cozy:1/130.00/130.00',
    '2000 and later|movie|mystery:1/130.00/130.00',
    '1950-1999|tv_show|melancholy:1/188.00/188.00',
    '1950-1999|tv_show|mystery:1/188.00/188.00',
    '1950-1999|movie|dark academia:1/128.00/128.00',
    '1950-1999|movie|melancholy:1/128.00/128.00',
    '1950-1999|book|dark academia:1/NULL/NULL',
    '1950-1999|book|melancholy:1/NULL/NULL',
    '1950-1999|book|mystery:1/NULL/NULL',
    'before 1950|song|melancholy:2/11.00/5.50',
    'before 1950|song|dark academia:1/6.00/6.00',
    'before 1950|song|cozy:1/5.00/5.00');
SELECT 'T6a era x media type x vibe report (13 cells, report order)' AS test, @expected AS expected,
       @actual AS actual, IF(@actual <=> @expected, 'PASS', 'FAIL') AS result;
 
-- T6b  Every has_tag row lands in exactly one cell: 13 cells whose item counts add up to 14
SET @cells = (SELECT COUNT(*)   FROM olap_cells);
SET @items = (SELECT SUM(items) FROM olap_cells);
SET @plain = (SELECT COUNT(*)   FROM has_tag);
SELECT 'T6b cell item counts add up to all has_tag rows' AS test, @plain AS expected, @items AS actual,
       IF(@cells = 13 AND @items = @plain AND @plain = 14, 'PASS', 'FAIL') AS result;
 
-- T6c  The report agrees with a one-dimension query: adding the cells of each vibe gives the
--      same item count as a plain GROUP BY on the vibe alone
SET @from_cells = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', n) ORDER BY vibe SEPARATOR ', ')
    FROM (SELECT vibe, SUM(items) AS n FROM olap_cells GROUP BY vibe) AS q);
SET @from_plain = (
    SELECT GROUP_CONCAT(CONCAT(vibe, '/', n) ORDER BY vibe SEPARATOR ', ')
    FROM (SELECT t.name AS vibe, COUNT(*) AS n
          FROM has_tag AS h JOIN tag AS t ON t.tag_id = h.tag_id
          GROUP BY t.name) AS q);
SELECT 'T6c cells add up to the plain per-vibe counts' AS test, @from_plain AS expected,
       @from_cells AS actual,
       IF(@from_cells <=> @from_plain AND @from_plain = 'cozy/2, dark academia/3, melancholy/5, mystery/4',
          'PASS', 'FAIL') AS result;
 
-- T6d  Books have no duration: their 3 cells have NULL (not 0) for SUM and AVG, and the
--      cell with 2 songs shows SUM 11.00 and AVG 5.50
SET @null_cells = (SELECT COUNT(*) FROM olap_cells
                   WHERE media_type = 'book' AND total_minutes IS NULL AND avg_minutes IS NULL);
SET @two_songs  = (SELECT CONCAT(items, '/', total_minutes, '/', avg_minutes) FROM olap_cells
                   WHERE media_type = 'song' AND vibe = 'melancholy');
SELECT 'T6d NULL for books, SUM/AVG for the 2-item cell' AS test, '3 and 2/11.00/5.50' AS expected,
       CONCAT(@null_cells, ' and ', @two_songs) AS actual,
       IF(@null_cells = 3 AND @two_songs = '2/11.00/5.50', 'PASS', 'FAIL') AS result;
 
DROP TEMPORARY TABLE IF EXISTS olap_cells;
 
-- ---------------------------------------------------------------------
-- Clean up: drop the helper and put the SQL mode back.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS expect_error;
SET SESSION sql_mode = @old_sql_mode