-- subquery_queries.sql
-- Sub-queries (nested logic)
--
-- Keywords covered: IN / NOT IN, EXISTS / NOT EXISTS, ALL, WITH, correlated sub-queries
-- Patterns covered: negated existential conditions, queries in the projection (SELECT list),
--                   correlated sub-queries, multiple aggregations (an aggregate over an aggregate)
--
-- A sub-query is a query inside a query. It works because every query returns ONE table, so
-- the result of one query can be the input of another: a condition in WHERE, a table in FROM,
-- or a single value in the SELECT list.
--
-- Two kinds:
--   uncorrelated  runs once, and its result is then used (sections 1, 4 and 7, and the WITH steps of 8)
--   correlated    mentions a column of the OUTER query, so it is re-evaluated for every outer
--                 row (sections 2, 3, 5 and 6, and the NOT EXISTS in 8)
--
-- What the keywords do:
--   x IN (sub-query)        TRUE if x equals one of the values the sub-query returns
--   x NOT IN (sub-query)    TRUE if it equals none of them (FALSE/UNKNOWN if the list holds a NULL)
--   EXISTS (sub-query)      TRUE if the sub-query returns at least one row (what it selects is ignored)
--   NOT EXISTS (sub-query)  TRUE if it returns no row at all
--   x >= ALL (sub-query)    TRUE if x is >= every value returned (TRUE when the sub-query is empty)
--   WITH name AS (query)    gives a sub-query a name so it can be used like a table, and reused
--
-- Seed data used throughout (what the answers below rely on):
--   users:     1 muskan, 2 divina, 3 grace
--   tracks:    (muskan, The Secret History, finished), (divina, Knives Out, in_progress),
--              (grace, Twin Peaks, want_to_consume)          -> nobody tracks media 4, 5, 6, 7
--   reviews:   muskan reviewed The Secret History, tagging it dark academia and melancholy
--   friends:   muskan follows divina, divina follows muskan, grace follows muskan
--   recommends: the group Spooky Season Club recommends Twin Peaks and Serial
--   tv_episodes of Twin Peaks (media 2): 94, 47, 47 minutes      podcast_episodes of Serial: 41, 52, 46
--   has_tag (14 rows): see grouping_queries.sql
--
-- Everything here is a SELECT, so the data is unchanged and the file can be run any number of
-- times. Run it after seed_data.sql and BEFORE load_csv.sql (that script adds more media, which
-- changes the answers). subquery_tests.sql checks every query in this file.

USE media_tracker;

-- =====================================================================
-- 1) IN: A SUB-QUERY THAT FEEDS ANOTHER QUERY'S CONDITION (nested three levels deep)
-- =====================================================================

-- 1a) Question:  Which media items carry a vibe that muskan used when tagging one of her reviews?
--     Idea:      work from the inside out: muskan's user_id -> the tags she used -> the media that
--                have any of those tags -> the media rows.
--     RA:        T = π tag_id (σ user_id = muskan (review_tags))
--                M = π media_id (has_tag ⋈ T)
--                answer = π media_id, title (media ⋉ M)        (⋉ = semi-join: keep media rows that match)
--     Why a sub-query: the answer needs only media columns, so the matching rows of the other
--                tables must act as a FILTER, not be joined in (a join would repeat a media row once
--                per matching tag).
-- Expected:   5 rows: The Secret History (1), Twin Peaks (2), Moonlight Sonata (5),
--             Dead Poets Society (6), Clair de Lune (7)
SELECT m.media_id, m.title
FROM media AS m
WHERE m.media_id IN (SELECT h.media_id
                     FROM has_tag AS h
                     WHERE h.tag_id IN (SELECT rt.tag_id
                                        FROM review_tags AS rt
                                        WHERE rt.user_id = (SELECT u.user_id
                                                            FROM users AS u
                                                            WHERE u.username = 'muskan')))
ORDER BY m.media_id;

-- 1b) Question:  The same, but only media muskan has NOT reviewed yet (a recommendation for her).
--     RA:        answer(1a) − π media_id, title (media ⋈ σ user_id = muskan (reviews))
-- Expected:   4 rows: Twin Peaks (2), Moonlight Sonata (5), Dead Poets Society (6), Clair de Lune (7)
SELECT m.media_id, m.title
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
ORDER BY m.media_id;

-- =====================================================================
-- 2) NEGATED EXISTENTIAL CONDITIONS: "there is NO row such that ..."
--    A plain join can only say "there is a matching row". To say "there is none" you need
--    NOT EXISTS (or NOT IN), and the check has to look at the OTHER table's rows.
-- =====================================================================

-- 2a) Question:  Which media items has nobody tracked?
--     RA:        π media_id, title (media)  −  π media_id, title (media ⋈ tracks)
--     Why:       a join keeps only items WITH trackers; the question asks for the items WITHOUT.
--     Correlated: the inner query uses m.media_id from the outer query.
-- Expected:   4 rows: Serial (4), Moonlight Sonata (5), Dead Poets Society (6), Clair de Lune (7)
SELECT m.media_id, m.title
FROM media AS m
WHERE NOT EXISTS (SELECT 1
                  FROM tracks AS t
                  WHERE t.media_id = m.media_id)
ORDER BY m.media_id;

-- 2b) Question:  Which users have never written a review?
--     RA:        π user_id, username (users)  −  π user_id, username (users ⋈ reviews)
-- Expected:   2 rows: divina (2), grace (3)
SELECT u.user_id, u.username
FROM users AS u
WHERE NOT EXISTS (SELECT 1
                  FROM reviews AS r
                  WHERE r.user_id = u.user_id)
ORDER BY u.user_id;

-- 2c) THE NULL TRAP: NOT IN versus NOT EXISTS
--     NOT IN compares with every value in the list. If ONE of those values is NULL, the comparison
--     "x = NULL" is UNKNOWN, so "x NOT IN (4, NULL)" is never TRUE and EVERY row is dropped.
--     Here the list is the tracked media ids plus one NULL (as would happen with a nullable column).
-- Expected:   0 rows (not 4!)
SELECT m.media_id, m.title
FROM media AS m
WHERE m.media_id NOT IN (SELECT t.media_id FROM tracks AS t
                         UNION ALL
                         SELECT NULL)
ORDER BY m.media_id;

--     NOT EXISTS is immune: it only asks whether a matching row exists.
-- Expected:   the same 4 rows as 2a, even though a NULL row is added to the other side
SELECT m.media_id, m.title
FROM media AS m
WHERE NOT EXISTS (SELECT 1
                  FROM (SELECT t.media_id FROM tracks AS t
                        UNION ALL
                        SELECT NULL) AS listed
                  WHERE listed.media_id = m.media_id)
ORDER BY m.media_id;

-- =====================================================================
-- 3) "FOR ALL" QUESTIONS: a double negation (relational division)
--    "Every X has property P" is the same as "there is NO X without P".
-- =====================================================================

-- 3a) Question:  Which groups recommend EVERY TV show?
--     RA:        G = π group_id (user_groups),  S = π media_id (tv_shows)
--                answer = G  −  π group_id ( (G × S)  −  π group_id, media_id (recommends) )
--                (take every group/show pair, remove the pairs that ARE recommended, and the
--                 groups left over are the ones missing a show; subtract them from all groups)
--     Reading:   the outer NOT EXISTS ranges over TV shows; the inner NOT EXISTS asks whether
--                this group lacks a recommendation of that show.
--     Careful:   with NO TV shows at all, every group would qualify (nothing is missing).
-- Expected:   1 row: Spooky Season Club (1), the only group, which recommends the only TV show
SELECT g.group_id, g.group_name
FROM user_groups AS g
WHERE NOT EXISTS (SELECT 1
                  FROM tv_shows AS s
                  WHERE NOT EXISTS (SELECT 1
                                    FROM recommends AS r
                                    WHERE r.group_id = g.group_id
                                      AND r.media_id = s.media_id));

-- 3b) The same question for movies.
-- Expected:   0 rows: the group recommends a TV show and a podcast, but neither movie
SELECT g.group_id, g.group_name
FROM user_groups AS g
WHERE NOT EXISTS (SELECT 1
                  FROM movies AS s
                  WHERE NOT EXISTS (SELECT 1
                                    FROM recommends AS r
                                    WHERE r.group_id = g.group_id
                                      AND r.media_id = s.media_id));

-- =====================================================================
-- 4) ALL: COMPARE WITH EVERY VALUE A SUB-QUERY RETURNS
-- =====================================================================

-- 4a) Question:  Which vibe is used on the most media items?   (ties would all be returned)
--     RA:        C = γ tag_id, COUNT(*) → n (has_tag)
--                answer = the C rows whose n is not smaller than any other n
--     Why:       WHERE cannot use COUNT; the maximum has to be computed by ANOTHER aggregation
--                over the same groups, and the HAVING compares against all of it.
-- Expected:   1 row: melancholy, 5 items
SELECT t.name, COUNT(*) AS items
FROM tag AS t
JOIN has_tag AS h ON h.tag_id = t.tag_id
GROUP BY t.tag_id, t.name
HAVING COUNT(*) >= ALL (SELECT COUNT(*)
                        FROM has_tag
                        GROUP BY tag_id);

-- 4b) Question:  Which media items were released before EVERY movie?
--     Careful:   "< ALL (empty set)" is TRUE, so with no movies at all every item would match.
-- Expected:   2 rows: Moonlight Sonata (1801), Clair de Lune (1905)   (the movies are 1989 and 2019)
SELECT m.media_id, m.title, m.release_year
FROM media AS m
WHERE m.release_year < ALL (SELECT m2.release_year
                            FROM media AS m2
                            JOIN movies AS mv ON mv.media_id = m2.media_id)
ORDER BY m.media_id;

-- =====================================================================
-- 5) CORRELATED SUB-QUERIES: the inner query depends on the current outer row
-- =====================================================================

-- 5a) Question:  Which TV episodes are longer than the average episode of THEIR OWN show?
--     RA:        A = γ media_id, AVG(duration_minutes) → avg (tv_episodes)
--                answer = σ duration_minutes > avg (tv_episodes ⋈ A)     (join each episode to its show's average)
--     Why correlated: there is one average PER SHOW, so the inner query needs e.media_id.
--     How it runs: for each outer episode e, MySQL evaluates the inner query with e.media_id.
--                  e = (Twin Peaks, S1E1, 94 min): the inner average over show 2 is
--                  (94 + 47 + 47) / 3 = 62.67, and 94 > 62.67, so the episode is kept.
--                  e = (Twin Peaks, S1E2, 47 min): 47 > 62.67 is FALSE, so it is dropped.
-- Expected:   1 row: Twin Peaks, season 1, episode 1, "Pilot", 94.00
SELECT e.media_id, e.season_number, e.episode_number, e.title, e.duration_minutes
FROM tv_episodes AS e
WHERE e.duration_minutes > (SELECT AVG(e2.duration_minutes)
                            FROM tv_episodes AS e2
                            WHERE e2.media_id = e.media_id)
ORDER BY e.media_id, e.season_number, e.episode_number;

-- 5b) Question:  Which media items were released after the average release year of their OWN TYPE?
--     RA:        A = γ media_type, AVG(release_year) → avg (media_with_type)
--                answer = σ release_year > avg (media_with_type ⋈ A)
--     Averages:  book 1992, tv_show 1990, movie 2004, podcast 2014, song 1853
-- Expected:   2 rows: Knives Out (movie, 2019), Clair de Lune (song, 1905)
SELECT m.media_id, m.title, m.media_type, m.release_year
FROM media_with_type AS m
WHERE m.release_year > (SELECT AVG(m2.release_year)
                        FROM media_with_type AS m2
                        WHERE m2.media_type = m.media_type)
ORDER BY m.media_id;

-- 5c) Question:  Which users have reviewed something they ALSO track?   (EXISTS inside EXISTS)
--     RA:        π user_id, username (users ⋈ π user_id (reviews ⋈ tracks))
--                (reviews ⋈ tracks joins on BOTH user_id and media_id: the same user, the same item)
-- Expected:   1 row: muskan (1)
SELECT u.user_id, u.username
FROM users AS u
WHERE EXISTS (SELECT 1
              FROM reviews AS r
              WHERE r.user_id = u.user_id
                AND EXISTS (SELECT 1
                            FROM tracks AS t
                            WHERE t.user_id = r.user_id
                              AND t.media_id = r.media_id));

-- =====================================================================
-- 6) QUERIES IN THE PROJECTION: a sub-query that supplies one value of the SELECT list
--    The sub-query must return exactly ONE value (one row, one column) per outer row.
-- =====================================================================

-- 6a) Question:  For every user: how many items have they finished, and how many reviews written?
--     RA:        users, with each count added from its own grouped result (a left outer join to
--                γ user_id, COUNT(*) (σ status = finished (tracks)) and to γ user_id, COUNT(*) (reviews),
--                with a missing group turned into 0)
--     Why:       users with no tracks or reviews must still appear, with 0.
-- Expected:   3 rows: muskan 1 finished / 1 review, divina 0 / 0, grace 0 / 0
SELECT u.user_id, u.username,
       (SELECT COUNT(*)
        FROM tracks AS t
        WHERE t.user_id = u.user_id AND t.media_status = 'finished') AS finished,
       (SELECT COUNT(*)
        FROM reviews AS r
        WHERE r.user_id = u.user_id) AS reviews
FROM users AS u
ORDER BY u.user_id;

-- 6b) Question:  For every media item: how many vibes does it have, and how many people track it?
--     Why not a join: joining has_tag AND tracks and then counting (1) drops every item that has no
--                tracker, and (2) would count each vibe once per tracker, because every vibe row is
--                paired with every tracker row. Two independent counts must be computed separately.
-- Expected:   7 rows (media_id: vibes / trackers):
--             1: 3 / 1   2: 2 / 1   3: 2 / 1   4: 1 / 0   5: 2 / 0   6: 2 / 0   7: 2 / 0
SELECT m.media_id, m.title,
       (SELECT COUNT(*) FROM has_tag AS h WHERE h.media_id = m.media_id) AS vibes,
       (SELECT COUNT(*) FROM tracks  AS t WHERE t.media_id = m.media_id) AS trackers
FROM media AS m
ORDER BY m.media_id;

-- =====================================================================
-- 7) MULTIPLE AGGREGATIONS: an aggregate over an aggregate
--    One GROUP BY cannot compute "the average of a count". First count per item (one level of
--    grouping), then average those counts per type (a second level), so the first query becomes a
--    table in the FROM clause of the second.
-- =====================================================================

-- 7a) Question:  On average, how many vibes does an item of each media type have?
--     RA:        P = γ media_id, media_type, COUNT(tag_id) → vibes (media_with_type ⟕ has_tag)
--                answer = γ media_type, AVG(vibes) → avg_vibes, COUNT(*) → items (P)
--     Careful:   the LEFT JOIN keeps items with no vibe (count 0) so they pull the average down.
-- Expected:   5 rows (type: average vibes, items): book 3.0 (1), movie 2.0 (2), podcast 1.0 (1),
--             song 2.0 (2), tv_show 2.0 (1)
SELECT per_item.media_type, AVG(per_item.vibes) AS avg_vibes, COUNT(*) AS items
FROM (SELECT mt.media_id, mt.media_type, COUNT(h.tag_id) AS vibes
      FROM media_with_type AS mt
      LEFT JOIN has_tag AS h ON h.media_id = mt.media_id
      GROUP BY mt.media_id, mt.media_type) AS per_item
GROUP BY per_item.media_type
ORDER BY per_item.media_type;

-- 7b) Question:  Which media type has the highest average number of vibes?
--     WITH names each step, so per_type can be used twice: as the table and inside the ALL.
-- Expected:   1 row: book, 3.0
WITH per_item AS (SELECT mt.media_id, mt.media_type, COUNT(h.tag_id) AS vibes
                  FROM media_with_type AS mt
                  LEFT JOIN has_tag AS h ON h.media_id = mt.media_id
                  GROUP BY mt.media_id, mt.media_type),
     per_type AS (SELECT media_type, AVG(vibes) AS avg_vibes
                  FROM per_item
                  GROUP BY media_type)
SELECT media_type, avg_vibes
FROM per_type
WHERE avg_vibes >= ALL (SELECT avg_vibes FROM per_type);

-- =====================================================================
-- 8) PUTTING IT TOGETHER: a recommendation built from named steps (WITH), IN and NOT EXISTS
-- =====================================================================

-- 8a) Question:  What can we recommend to grace? Items finished by someone she follows that she has
--                not tracked herself.   (Change 'grace' in the first step to try another user.)
--     RA:        F = π followed_id (friends ⋈ σ username = grace (users))
--                D = π media_id (σ status = finished (tracks) ⋈ F)
--                answer = π media_id, title (media ⋉ D)  −  π media_id, title (media ⋈ tracks of grace)
-- Expected:   1 row: The Secret History (1)   (she follows muskan, who finished it; grace tracks only Twin Peaks)
WITH me AS (SELECT user_id
            FROM users
            WHERE username = 'grace'),
     followed AS (SELECT f.followed_id AS user_id
                  FROM friends AS f
                  JOIN me ON f.follower_id = me.user_id),
     finished_by_followed AS (SELECT DISTINCT t.media_id
                              FROM tracks AS t
                              JOIN followed AS fo ON fo.user_id = t.user_id
                              WHERE t.media_status = 'finished')
SELECT m.media_id, m.title
FROM media AS m
WHERE m.media_id IN (SELECT media_id FROM finished_by_followed)
  AND NOT EXISTS (SELECT 1
                  FROM tracks AS t
                  JOIN me ON t.user_id = me.user_id
                  WHERE t.media_id = m.media_id);

-- 8b) The same for muskan.
-- Expected:   0 rows: she follows divina, who has finished nothing
WITH me AS (SELECT user_id
            FROM users
            WHERE username = 'muskan'),
     followed AS (SELECT f.followed_id AS user_id
                  FROM friends AS f
                  JOIN me ON f.follower_id = me.user_id),
     finished_by_followed AS (SELECT DISTINCT t.media_id
                              FROM tracks AS t
                              JOIN followed AS fo ON fo.user_id = t.user_id
                              WHERE t.media_status = 'finished')
SELECT m.media_id, m.title
FROM media AS m
WHERE m.media_id IN (SELECT media_id FROM finished_by_followed)
  AND NOT EXISTS (SELECT 1
                  FROM tracks AS t
                  JOIN me ON t.user_id = me.user_id
                  WHERE t.media_id = m.media_id);