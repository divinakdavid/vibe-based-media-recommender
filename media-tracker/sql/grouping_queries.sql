-- grouping_queries.sql
-- Grouping & Aggregation
--
-- Keywords covered: DISTINCT (δ), GROUP BY (ɣ), COUNT, MIN, MAX, SUM, AVG, ANY_VALUE, WHERE vs HAVING
--
-- Seed data used throughout (has_tag, 14 rows):
--   dark academia: The Secret History (book), Moonlight Sonata (song), Dead Poets Society (movie)
--   mystery:       The Secret History (book), Twin Peaks (tv), Knives Out (movie), Serial (podcast)
--   cozy:          Knives Out (movie), Clair de Lune (song)
--   melancholy:    The Secret History (book), Twin Peaks (tv), Moonlight Sonata (song),
--                  Dead Poets Society (movie), Clair de Lune (song)
 
USE media_tracker;
 
-- =====================================================================
-- 1) DISTINCT REMOVES DUPLICATE TUPLES
-- Question:   Which non-song media released before 2000 have the 'mystery' OR the
--             'melancholy' vibe?   (3 constraints: vibe list, year, type)
-- π:          media id, title, type, release year
-- FROM / ⋈:   media ⋈ media_with_type ⋈ has_tag ⋈ tag
-- σ:          tag IN ('mystery','melancholy') AND release_year < 2000 AND type <> 'song'
-- Why duplicates: has_tag has one row per (item, vibe). An item that has BOTH vibes joins to
--             two rows, and the output schema contains no tag column to tell them apart,
--             so the two output tuples are identical. A SQL result has no key, so SQL keeps both.
-- =====================================================================
 
-- 1a) WITHOUT DISTINCT
-- Expected:   5 rows. The Secret History and Twin Peaks each appear twice (they have both
--             vibes), Dead Poets Society once (melancholy only).
SELECT m.media_id, m.title, mt.media_type, m.release_year
FROM media AS m
JOIN media_with_type AS mt ON mt.media_id = m.media_id
JOIN has_tag AS h          ON h.media_id  = m.media_id
JOIN tag     AS t          ON t.tag_id    = h.tag_id
WHERE t.name IN ('mystery', 'melancholy')
  AND m.release_year < 2000
  AND mt.media_type <> 'song'
ORDER BY m.title;
 
-- 1b) WITH DISTINCT (δ): one tuple per distinct combination of the output columns
-- Expected:   3 rows: Dead Poets Society, The Secret History, Twin Peaks
SELECT DISTINCT m.media_id, m.title, mt.media_type, m.release_year
FROM media AS m
JOIN media_with_type AS mt ON mt.media_id = m.media_id
JOIN has_tag AS h          ON h.media_id  = m.media_id
JOIN tag     AS t          ON t.tag_id    = h.tag_id
WHERE t.name IN ('mystery', 'melancholy')
  AND m.release_year < 2000
  AND mt.media_type <> 'song'
ORDER BY m.title;
 
-- 1c) DISTINCT is the same as GROUP BY on all the output columns (one tuple per
--     "equivalence class", slide "Revisiting Duplicate Elimination")
-- Expected:   the same 3 rows as 1b
SELECT m.media_id, m.title, mt.media_type, m.release_year
FROM media AS m
JOIN media_with_type AS mt ON mt.media_id = m.media_id
JOIN has_tag AS h          ON h.media_id  = m.media_id
JOIN tag     AS t          ON t.tag_id    = h.tag_id
WHERE t.name IN ('mystery', 'melancholy')
  AND m.release_year < 2000
  AND mt.media_type <> 'song'
GROUP BY m.media_id, m.title, mt.media_type, m.release_year
ORDER BY m.title;
 
-- =====================================================================
-- 2) GROUP BY PARTITIONS TUPLES
-- Question:   Which media items are the most popular, measured by how many vibes they have?
-- π:          media id, title, COUNT of vibes
-- FROM / ⋈:   media ⋈ has_tag
-- ɣ:          GROUP BY media_id: one equivalence class (one output tuple) per media item.
--             Every has_tag row falls in exactly one group, so the counts add up to 14.
-- FD:         media_id → title, so title can be selected without an aggregate function
--             (media_id is media's primary key).
-- Expected:   7 rows, most vibes first, ties alphabetical:
--             The Secret History 3
--             Clair de Lune 2, Dead Poets Society 2, Knives Out 2, Moonlight Sonata 2, Twin Peaks 2, Serial 1
-- =====================================================================
SELECT m.media_id, m.title, COUNT(h.tag_id) AS vibe_count
FROM media AS m
JOIN has_tag AS h ON h.media_id = m.media_id
GROUP BY m.media_id, m.title
ORDER BY vibe_count DESC, m.title;
 
-- =====================================================================
-- 3) ANY_VALUE: ONE SCALAR PER GROUP FOR A COLUMN THAT IS NOT DETERMINED BY THE GROUP BY KEY
-- Question:   For each vibe, show an example title and how many items have the vibe.
-- Problem:    tag_id does NOT determine title (a vibe has many titles), so "which title goes
--             in the output tuple?" has no answer. The non-key column has to be
--             mapped to a single value by an aggregate function: ANY_VALUE, MIN, MAX ...
-- =====================================================================
 
-- 3a) The fix. Both columns are valid, they just mean different things:
--     ANY_VALUE(title)  one title from the group. Which one is arbitrary (MySQL picks one,
--                       usually the first row it reads), so do not rely on WHICH one.
--     MIN(title)        the alphabetically first title. Deterministic: same answer every run.
-- Expected:   4 rows. items: dark academia 3, mystery 4, cozy 2, melancholy 5.
--             first_title: dark academia = Dead Poets Society, mystery = Knives Out,
--                          cozy = Clair de Lune, melancholy = Clair de Lune.
--             any_title: one of the titles tagged with that vibe.
SELECT t.tag_id,
       t.name           AS vibe,
       ANY_VALUE(m.title) AS any_title,
       MIN(m.title)       AS first_title,
       COUNT(*)           AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id   = t.tag_id
JOIN media   AS m ON m.media_id = h.media_id
GROUP BY t.tag_id
ORDER BY t.tag_id;
 
-- 3b) The case that needs NO aggregate function: tag_id → name (tag_id is the primary key),
--     so every row in a group has the same name and MySQL accepts it as it is (slide
--     "Handling non-key attributes", the A → B case).
-- Expected:   4 rows: dark academia 3, mystery 4, cozy 2, melancholy 5
SELECT t.tag_id, t.name AS vibe, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id = t.tag_id
GROUP BY t.tag_id
ORDER BY t.tag_id;
 
-- 3c) The failing version (commented out so run_all.sql keeps running; it is run for real,
--     with its error, by grouping_queries_tests.sql):
--
-- SELECT t.tag_id, m.title, COUNT(*) AS items
-- FROM tag AS t
-- JOIN has_tag AS h ON h.tag_id   = t.tag_id
-- JOIN media   AS m ON m.media_id = h.media_id
-- GROUP BY t.tag_id;
--
-- Expected:   Expression #2 of SELECT list is not in GROUP BY clause and
--             contains nonaggregated column 'media_tracker.m.title' which is not functionally
--             dependent on columns in GROUP BY clause
 
-- =====================================================================
-- 4) WHERE vs HAVING
--   WHERE   filters the INPUT tuples, before they are grouped.
--           It cannot use an aggregate function.
--   HAVING  filters the GROUPS, after grouping. It can use aggregates.
--
--   They give IDENTICAL results exactly when the condition only mentions GROUP BY columns:
--   every tuple in a group has the same value there, so a group either passes as a whole
--   (all its tuples pass the WHERE) or fails as a whole (HAVING drops the group). Prefer
--   WHERE in that case: it throws tuples away before grouping, so there is less to group.
--
--   They give DIFFERENT results when the condition is on a column that is not a GROUP BY
--   column (WHERE removes tuples, which changes the counts) or on an aggregate (HAVING only).
-- =====================================================================
 
-- 4a) Condition on a GROUP BY column, with WHERE
-- Question:   How many media items have each of the vibes 'mystery' and 'melancholy'?
-- Expected:   2 rows: melancholy 5, mystery 4
SELECT t.name AS vibe, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id = t.tag_id
WHERE t.name IN ('mystery', 'melancholy')
GROUP BY t.name
ORDER BY t.name;
 
-- 4b) The same condition, with HAVING: same 2 rows, same counts
-- Expected:   identical to 4a
SELECT t.name AS vibe, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id = t.tag_id
GROUP BY t.name
HAVING t.name IN ('mystery', 'melancholy')
ORDER BY t.name;
 
-- 4c) Condition on a column that is NOT in GROUP BY, with WHERE: tuples are dropped first,
--     so the counts change
-- Question:   For each vibe, how many items released before 2000 have it?
-- Expected:   cozy 1 (Clair de Lune), dark academia 3, melancholy 5, mystery 2
--             (Knives Out is 2019, Serial is 2014, so they no longer count)
SELECT t.name AS vibe, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id   = t.tag_id
JOIN media   AS m ON m.media_id = h.media_id
WHERE m.release_year < 2000
GROUP BY t.name
ORDER BY t.name;
 
-- 4d) HAVING on an aggregate of that column: a different question. Groups are kept or
--     dropped as a whole, and nothing is removed from the ones that stay.
-- Question:   Which vibes have at least one item released before 2000, and how many items
--             (of any year) do they have?
-- Expected:   cozy 2, dark academia 3, melancholy 5, mystery 4 (all four vibes qualify)
SELECT t.name AS vibe, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id   = t.tag_id
JOIN media   AS m ON m.media_id = h.media_id
GROUP BY t.name
HAVING MIN(m.release_year) < 2000
ORDER BY t.name;
 
-- 4e) A condition on a group (an aggregate): HAVING is the only option
-- Question:   Which vibes are shared by at least 4 media items?
-- Expected:   2 rows: melancholy 5, mystery 4
--             (WHERE COUNT(*) >= 4 is rejected: ERROR 1111, see grouping_queries_tests.sql)
SELECT t.name AS vibe, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id = t.tag_id
GROUP BY t.name
HAVING COUNT(*) >= 4
ORDER BY t.name;
 
-- =====================================================================
-- 5) AGGREGATION FUNCTIONS: COUNT, MIN, MAX, SUM, AVG, ANY_VALUE
-- Each one maps the set of values in a group onto a single scalar:
--   COUNT(*)    number of rows in the group (COUNT(x) skips NULLs in x)
--   MIN / MAX   smallest / largest value
--   SUM / AVG   total / mean of a numeric column (both ignore NULLs)
--   ANY_VALUE   one arbitrary value of the column (the slides' ANY())
-- Durations (duration_minutes, in decimal minutes) are stored in four tables: movies, songs,
-- tv_episodes and podcast_episodes. To compare media types, the queries below first stack
-- them with UNION ALL, which keeps every row as it is (plain UNION would also remove duplicate
-- tuples, like DISTINCT does, and could change the sums).
-- Seed data used here:
--   movies:           Knives Out 130, Dead Poets Society 128
--   songs:            Moonlight Sonata 6.00, Clair de Lune 5.00
--   Twin Peaks (tv):  S1E1 94, S1E2 47, S2E1 47
--   Serial (podcast): E1 41, E2 52, E3 46
-- =====================================================================
 
-- 5a) All five functions at once: duration summary per media type
-- Question:   For movies and for songs, how many items are there, and what are the shortest,
--             longest, total and average durations? Show one example title too.
-- π:          media type, COUNT, MIN, MAX, SUM, AVG of duration, one title
-- FROM / ⋈:   (movies ⋈ media) UNION ALL (songs ⋈ media)
-- ɣ:          GROUP BY media_type
-- FD:         title is not determined by media_type (a type has many titles), so it needs an
--             aggregate: ANY_VALUE picks one, and which one is not defined.
-- Expected:   2 rows
--             movie  items 2, shortest 128.00, longest 130.00, total 258.00, average 129.00
--             song   items 2, shortest   5.00, longest   6.00, total  11.00, average   5.50
--             example_title: a movie title / a song title (either one of the two)
SELECT d.media_type,
       COUNT(*)                          AS items,
       MIN(d.duration_minutes)           AS shortest,
       MAX(d.duration_minutes)           AS longest,
       SUM(d.duration_minutes)           AS total_minutes,
       ROUND(AVG(d.duration_minutes), 2) AS average_minutes,
       ANY_VALUE(d.title)                AS example_title
FROM (
    SELECT 'movie' AS media_type, m.title, mo.duration_minutes
    FROM movies AS mo
    JOIN media  AS m ON m.media_id = mo.media_id
    UNION ALL
    SELECT 'song', m.title, s.duration_minutes
    FROM songs AS s
    JOIN media AS m ON m.media_id = s.media_id
) AS d
GROUP BY d.media_type
ORDER BY d.media_type;
 
-- 5b) The same functions per show: episode statistics
-- Question:   For each TV show and podcast, how many episodes does it have, how many minutes
--             in total, and what are the average, longest and shortest episodes?
-- FROM / ⋈:   (tv_episodes ⋈ media) UNION ALL (podcast_episodes ⋈ media)
-- ɣ:          GROUP BY media_id (title and type are determined by it, so they need no aggregate)
-- Expected:   2 rows
--             Serial      podcast  3 episodes, total 139.00, average 46.33, longest 52.00, shortest 41.00
--             Twin Peaks  tv_show  3 episodes, total 188.00, average 62.67, longest 94.00, shortest 47.00
SELECT d.title, d.media_type,
       COUNT(*)                          AS episodes,
       SUM(d.duration_minutes)           AS total_minutes,
       ROUND(AVG(d.duration_minutes), 2) AS average_minutes,
       MAX(d.duration_minutes)           AS longest,
       MIN(d.duration_minutes)           AS shortest
FROM (
    SELECT m.media_id, m.title, 'tv_show' AS media_type, e.duration_minutes
    FROM tv_episodes AS e
    JOIN media AS m ON m.media_id = e.media_id
    UNION ALL
    SELECT m.media_id, m.title, 'podcast', e.duration_minutes
    FROM podcast_episodes AS e
    JOIN media AS m ON m.media_id = e.media_id
) AS d
GROUP BY d.media_id, d.title, d.media_type
ORDER BY d.title;
 
-- 5c) Filtering on an AVERAGE: HAVING (the condition is on the group, so WHERE cannot be used)
-- Question:   Which shows or podcasts have an average episode longer than 50 minutes?
-- σ:          HAVING AVG(duration_minutes) > 50
-- Expected:   1 row: Twin Peaks, 62.67
--             (Serial averages 46.33, so its whole group is dropped)
SELECT d.title, ROUND(AVG(d.duration_minutes), 2) AS average_minutes
FROM (
    SELECT m.media_id, m.title, e.duration_minutes
    FROM tv_episodes AS e
    JOIN media AS m ON m.media_id = e.media_id
    UNION ALL
    SELECT m.media_id, m.title, e.duration_minutes
    FROM podcast_episodes AS e
    JOIN media AS m ON m.media_id = e.media_id
) AS d
GROUP BY d.media_id, d.title
HAVING AVG(d.duration_minutes) > 50
ORDER BY d.title;
 
-- 5d) Filtering on a SET DURATION: WHERE (the condition is on each episode, so tuples are
--     dropped BEFORE they are counted and summed)
-- Question:   Counting only episodes shorter than 60 minutes, how many does each show or
--             podcast have and how many minutes do they add up to?
-- σ:          WHERE duration_minutes < 60
-- Expected:   2 rows
--             Serial      3 episodes, 139.00 minutes (all three are under 60)
--             Twin Peaks  2 episodes,  94.00 minutes (the 94-minute pilot is left out)
SELECT d.title, COUNT(*) AS short_episodes, SUM(d.duration_minutes) AS total_minutes
FROM (
    SELECT m.media_id, m.title, e.duration_minutes
    FROM tv_episodes AS e
    JOIN media AS m ON m.media_id = e.media_id
    UNION ALL
    SELECT m.media_id, m.title, e.duration_minutes
    FROM podcast_episodes AS e
    JOIN media AS m ON m.media_id = e.media_id
) AS d
WHERE d.duration_minutes < 60
GROUP BY d.media_id, d.title
ORDER BY d.title;
 
-- 5e) MIN and MAX on a non-duration column: oldest and newest item of each type
-- Question:   For each media type, how many items are there and what are the earliest and
--             latest release years?
-- FROM / ⋈:   media_with_type (the view derives the type from the child tables)
-- Expected:   5 rows
--             book 1 items, 1992 to 1992      movie 2 items, 1989 to 2019
--             podcast 1 item, 2014 to 2014    song 2 items, 1801 to 1905
--             tv_show 1 item, 1990 to 1990
SELECT mt.media_type,
       COUNT(*)             AS items,
       MIN(mt.release_year) AS oldest,
       MAX(mt.release_year) AS newest
FROM media_with_type AS mt
GROUP BY mt.media_type
ORDER BY mt.media_type;

-- =====================================================================
-- 6) OLAP-STYLE REPORT: GROUP BY OVER SEVERAL ATTRIBUTES AND MEASURES
-- A classic OLAP report slices a fact table across attributes and reports measures (COUNT, SUM ...) 
-- for every combination, sorted by the measures.
-- This database has no star schema, so the pieces come from existing tables:
--   fact table          has_tag: one row per (media item, vibe)
--   dimension 1: era     derived from media.release_year (before 1950, 1950-1999, 2000 and later)
--   dimension 2: type    media_with_type.media_type
--   dimension 3: vibe    tag.name
--   measures             COUNT(*) items, SUM and AVG of the item's running time in minutes
-- The running time of an item is: a movie's or song's duration_minutes, or the SUM of a show's or
-- podcast's episode durations. Books have no duration, so their running time is NULL; SUM and AVG
-- ignore NULLs and give NULL when a group has no value at all (a book cell shows NULL, not 0).
-- ɣ:          GROUP BY era, media_type, vibe: one output tuple per combination that has data
-- ORDER BY:   newest era first, then the biggest total running time first (like year DESC,
--             total_revenue DESC in a sales report); ties by type and vibe
-- Expected:   13 rows (the item counts add up to the 14 rows of has_tag)
--   2000 and later  podcast  mystery        1 item,  139.00 minutes, average 139.00
--   2000 and later  movie    cozy           1 item,  130.00 minutes, average 130.00
--   2000 and later  movie    mystery        1 item,  130.00 minutes, average 130.00
--   1950-1999       tv_show  melancholy     1 item,  188.00 minutes, average 188.00
--   1950-1999       tv_show  mystery        1 item,  188.00 minutes, average 188.00
--   1950-1999       movie    dark academia  1 item,  128.00 minutes, average 128.00
--   1950-1999       movie    melancholy     1 item,  128.00 minutes, average 128.00
--   1950-1999       book     dark academia  1 item,  NULL,           NULL
--   1950-1999       book     melancholy     1 item,  NULL,           NULL
--   1950-1999       book     mystery        1 item,  NULL,           NULL
--   before 1950     song     melancholy     2 items,  11.00 minutes, average 5.50  (Moonlight Sonata + Clair de Lune)
--   before 1950     song     dark academia  1 item,    6.00 minutes, average 6.00
--   before 1950     song     cozy           1 item,    5.00 minutes, average 5.00
-- =====================================================================
SELECT e.era,
       mt.media_type,
       t.name                    AS vibe,
       COUNT(*)                  AS items,
       SUM(im.minutes)           AS total_minutes,
       ROUND(AVG(im.minutes), 2) AS avg_minutes
FROM has_tag AS h
JOIN media           AS m  ON m.media_id  = h.media_id
JOIN media_with_type AS mt ON mt.media_id = m.media_id
JOIN tag             AS t  ON t.tag_id    = h.tag_id
JOIN (
    -- era dimension; era_no is only there so the eras sort in time order, not alphabetically
    SELECT media_id,
           CASE WHEN release_year < 1950 THEN 1 WHEN release_year < 2000 THEN 2 ELSE 3 END AS era_no,
           CASE WHEN release_year < 1950 THEN 'before 1950'
                WHEN release_year < 2000 THEN '1950-1999'
                ELSE '2000 and later' END AS era
    FROM media
) AS e ON e.media_id = m.media_id
LEFT JOIN (
    -- one running time per media item (LEFT JOIN: books have none and must stay in the report)
    SELECT media_id, duration_minutes AS minutes FROM movies
    UNION ALL
    SELECT media_id, duration_minutes FROM songs
    UNION ALL
    SELECT media_id, SUM(duration_minutes) FROM tv_episodes GROUP BY media_id
    UNION ALL
    SELECT media_id, SUM(duration_minutes) FROM podcast_episodes GROUP BY media_id
) AS im ON im.media_id = m.media_id
GROUP BY e.era_no, e.era, mt.media_type, t.name
ORDER BY e.era_no DESC, total_minutes DESC, mt.media_type, t.name;