-- sfw_queries.sql
--
--   1. English question
--   2. Output schema      SELECT / π
--   3. Source table(s)    FROM / JOIN / ⋈
--   4. Predicates         WHERE / σ
--   5. Expected result, worked out from seed_data.sql BEFORE running the query
--
-- Keywords covered: SELECT, FROM, WHERE, × (FROM a, b), JOIN, AND, OR, NOT, IS, AS, LIKE,
--                   ORDER BY, LIMIT                                              (13/13)
--

USE media_tracker;

-- =====================================================================
-- 1) COMPLEX CONDITIONS (3 constraints, 4 tables)
-- Question:   Which season-1 episodes of a mystery show are longer than 45 minutes,
--             longest first?
-- π:          show title, season, episode number, episode title, duration
-- FROM / ⋈:   tv_episodes ⋈ media ⋈ has_tag ⋈ tag
-- σ:          duration_minutes > 45  AND  tag = 'mystery'  AND  season_number = 1
-- Algebra:    π(...) σ(duration>45 ∧ name='mystery' ∧ season=1) (tv_episodes ⋈ media ⋈ has_tag ⋈ tag)
-- Expected:   2 rows: Twin Peaks / Pilot (94.00), Twin Peaks / Traces to Nowhere (47.00)
--             Season 2's "May the Giant Be with You" (47 min) is removed by season = 1.
--             Serial is also a mystery, but it is a podcast: its episodes are in
--             podcast_episodes, not tv_episodes.
-- =====================================================================
SELECT m.title AS show_title, e.season_number, e.episode_number,
       e.title AS episode, e.duration_minutes
FROM tv_episodes AS e
JOIN media   AS m ON m.media_id = e.media_id
JOIN has_tag AS h ON h.media_id = m.media_id
JOIN tag     AS g ON g.tag_id   = h.tag_id
WHERE e.duration_minutes > 45
  AND g.name = 'mystery'
  AND e.season_number = 1
ORDER BY e.duration_minutes DESC;

-- =====================================================================
-- 2-5) CONSTRAINTS WRITTEN AS QUERIES (lecture: "σ(...) = Ø")
-- Each query looks for rows that BREAK a rule, so the expected answer is 0 rows.
-- COUNT(*) is used so the 0 is visible on screen (an empty result prints nothing).
-- =====================================================================

-- 2) VALUE RANGE
-- Question:   Which media items were released before the year 1400?
-- Algebra:    σ(release_year < 1400)(media) = Ø
-- Expected:   0 rows. chk_release_year stops such rows from being stored at all.
SELECT COUNT(*) AS violations          -- the rows would be: media_id, title, release_year
FROM media
WHERE release_year < 1400;

-- 3) ATTRIBUTE RELATIONSHIP
-- Question:   Which users follow themselves?
-- Algebra:    σ(follower_id = followed_id)(friends) = Ø
-- Expected:   0 rows. chk_no_self_follow stops such rows from being stored at all.
SELECT COUNT(*) AS violations          -- the rows would be: follower_id, followed_id
FROM friends
WHERE follower_id = followed_id;

-- 4) KEY / UNIQUENESS, using × (two copies of media in FROM)
-- Question:   Are there two different media items with the same title?
-- Algebra:    σ(a.title = b.title)(ρa(media) ⋈ a.media_id < b.media_id ρb(media)) = Ø
-- Expected:   0 rows. Nothing in the schema forces titles to be unique, so this query is
--             the only thing that catches it (sfw_tests.sql adds a duplicate to prove it).
SELECT COUNT(*) AS violations          -- the rows would be: a.media_id, a.title, b.media_id
FROM media AS a, media AS b
WHERE a.media_id < b.media_id
  AND a.title = b.title;

-- 5) FUNCTIONAL DEPENDENCY  username → email
-- Question:   Are there two users with the same username but different emails?
-- Algebra:    σ(u1.email <> u2.email)(ρu1(users) ⋈ u1.username = u2.username ρu2(users)) = Ø
-- Expected:   0 rows. username is UNIQUE, so the FD always holds.
SELECT COUNT(*) AS violations          -- the rows would be: username, email, other email
FROM users AS u1, users AS u2
WHERE u1.username = u2.username
  AND u1.email <> u2.email;

-- =====================================================================
-- 6) SELF-JOIN WITH AS
-- Question:   Which pairs of users follow each other?
-- π:          the two usernames
-- FROM / ⋈:   friends AS f1 ⋈ friends AS f2 (the reverse follow) ⋈ users (twice, for names)
-- σ:          f1.follower_id < f1.followed_id   (list each pair once)
-- Expected:   1 row: muskan, divina
-- =====================================================================
SELECT u1.username AS user_a, u2.username AS user_b
FROM friends AS f1
JOIN friends AS f2 ON f2.follower_id = f1.followed_id
                  AND f2.followed_id = f1.follower_id
JOIN users   AS u1 ON u1.user_id = f1.follower_id
JOIN users   AS u2 ON u2.user_id = f1.followed_id
WHERE f1.follower_id < f1.followed_id;

-- =====================================================================
-- 7) THE REMAINING KEYWORDS
-- =====================================================================

-- 7a) NOT
-- Question:   What is each user tracking that they have NOT finished?
-- Expected:   divina / Knives Out / in_progress, grace / Twin Peaks / want_to_consume
SELECT u.username, m.title, t.media_status
FROM tracks AS t
JOIN users  AS u ON u.user_id  = t.user_id
JOIN media  AS m ON m.media_id = t.media_id
WHERE NOT t.media_status = 'finished'
ORDER BY u.username;

-- 7b) IS
-- Question:   Which books have an ISBN recorded?
-- Expected:   The Secret History, 9781400031702
SELECT m.title, b.isbn
FROM books AS b
JOIN media AS m ON m.media_id = b.media_id
WHERE b.isbn IS NOT NULL;

-- 7c) LIKE and AS
-- Question:   Which songs have "Sonata" in the title or a title starting with "Clair",
--             longest first? Show them as song / artist / minutes.
-- Expected:   Moonlight Sonata / Beethoven / 6.00, Clair de Lune / Debussy / 5.00
SELECT m.title AS song, s.artist, s.duration_minutes AS minutes
FROM songs AS s
JOIN media AS m ON m.media_id = s.media_id
WHERE m.title LIKE '%Sonata%'
   OR m.title LIKE 'Clair%'
ORDER BY minutes DESC;

-- 7d) LIMIT
-- Question:   What are the 3 newest media items?
-- Expected:   Knives Out (2019), Serial (2014), The Secret History (1992)
SELECT title, release_year
FROM media
ORDER BY release_year DESC
LIMIT 3;

-- =====================================================================
-- 8) COMPLEX-PREDICATE DML: the same FROM and WHERE as query 1, used to change data
-- Question:   Tag every episode that query 1 finds as part of a "Mystery Marathon".
-- Expected:   ROW_COUNT() = 2 (exactly the two rows query 1 returned), then ROLLBACK
--             puts the titles back.
-- =====================================================================
START TRANSACTION;

UPDATE tv_episodes AS e
JOIN media   AS m ON m.media_id = e.media_id
JOIN has_tag AS h ON h.media_id = m.media_id
JOIN tag     AS g ON g.tag_id   = h.tag_id
SET e.title = CONCAT(e.title, ' (Mystery Marathon)')
WHERE e.duration_minutes > 45
  AND g.name = 'mystery'
  AND e.season_number = 1;

SELECT ROW_COUNT() AS rows_changed;                  -- expected 2

SELECT season_number, episode_number, title          -- the two changed titles
FROM tv_episodes
WHERE media_id = 2
ORDER BY season_number, episode_number;

ROLLBACK;                                            -- titles back to normal
