-- integrity_audit.sql
-- Referential integrity audit: counts orphaned rows, one line per foreign key.
-- Every number in the "violations" column must be 0. Read-only, safe to re-run at any time
-- (run it after any of the other scripts to prove they left no orphans behind).
--
-- Each foreign key is the relational algebra constraint  pi_cols(Child) is a subset of
-- pi_cols(Parent)  i.e.  pi_cols(Child) - pi_cols(Parent) = empty set. The SQL below is the
-- same expression: LEFT JOIN each child row to its parent and keep the rows that found none.
--
-- The last two lines audit a rule that MySQL cannot declare (see schema_media.sql): each media
-- row must be in exactly one child table, so there must be
--   no media row that is in no child table, and
--   no media row that is in more than one child table.
-- This file uses COUNT and UNION ALL only so that all 24 checks print as one table.

USE media_tracker;

--  1) friends.follower_id -> users
SELECT 'friends.follower_id -> users' AS constraint_checked, COUNT(*) AS violations
FROM friends c
LEFT JOIN users p ON p.user_id = c.follower_id
WHERE p.user_id IS NULL
UNION ALL

--  2) friends.followed_id -> users
SELECT 'friends.followed_id -> users' AS constraint_checked, COUNT(*) AS violations
FROM friends c
LEFT JOIN users p ON p.user_id = c.followed_id
WHERE p.user_id IS NULL
UNION ALL

--  3) user_groups.creator_id -> users
SELECT 'user_groups.creator_id -> users' AS constraint_checked, COUNT(*) AS violations
FROM user_groups c
LEFT JOIN users p ON p.user_id = c.creator_id
WHERE p.user_id IS NULL
UNION ALL

--  4) member_of.group_id -> user_groups
SELECT 'member_of.group_id -> user_groups' AS constraint_checked, COUNT(*) AS violations
FROM member_of c
LEFT JOIN user_groups p ON p.group_id = c.group_id
WHERE p.group_id IS NULL
UNION ALL

--  5) member_of.user_id -> users
SELECT 'member_of.user_id -> users' AS constraint_checked, COUNT(*) AS violations
FROM member_of c
LEFT JOIN users p ON p.user_id = c.user_id
WHERE p.user_id IS NULL
UNION ALL

--  6) books.media_id -> media
SELECT 'books.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM books c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

--  7) tv_shows.media_id -> media
SELECT 'tv_shows.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM tv_shows c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

--  8) movies.media_id -> media
SELECT 'movies.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM movies c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

--  9) podcasts.media_id -> media
SELECT 'podcasts.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM podcasts c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 10) songs.media_id -> media
SELECT 'songs.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM songs c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 11) tv_episodes.media_id -> tv_shows
SELECT 'tv_episodes.media_id -> tv_shows' AS constraint_checked, COUNT(*) AS violations
FROM tv_episodes c
LEFT JOIN tv_shows p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 12) podcast_episodes.media_id -> podcasts
SELECT 'podcast_episodes.media_id -> podcasts' AS constraint_checked, COUNT(*) AS violations
FROM podcast_episodes c
LEFT JOIN podcasts p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 13) has_tag.media_id -> media
SELECT 'has_tag.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM has_tag c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 14) has_tag.tag_id -> tag
SELECT 'has_tag.tag_id -> tag' AS constraint_checked, COUNT(*) AS violations
FROM has_tag c
LEFT JOIN tag p ON p.tag_id = c.tag_id
WHERE p.tag_id IS NULL
UNION ALL

-- 15) tracks.user_id -> users
SELECT 'tracks.user_id -> users' AS constraint_checked, COUNT(*) AS violations
FROM tracks c
LEFT JOIN users p ON p.user_id = c.user_id
WHERE p.user_id IS NULL
UNION ALL

-- 16) tracks.media_id -> media
SELECT 'tracks.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM tracks c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 17) reviews.user_id -> users
SELECT 'reviews.user_id -> users' AS constraint_checked, COUNT(*) AS violations
FROM reviews c
LEFT JOIN users p ON p.user_id = c.user_id
WHERE p.user_id IS NULL
UNION ALL

-- 18) reviews.media_id -> media
SELECT 'reviews.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM reviews c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 19) review_tags.user_id,media_id -> reviews
SELECT 'review_tags.user_id,media_id -> reviews' AS constraint_checked, COUNT(*) AS violations
FROM review_tags c
LEFT JOIN reviews p ON p.user_id = c.user_id AND p.media_id = c.media_id
WHERE p.user_id IS NULL
UNION ALL

-- 20) review_tags.tag_id -> tag
SELECT 'review_tags.tag_id -> tag' AS constraint_checked, COUNT(*) AS violations
FROM review_tags c
LEFT JOIN tag p ON p.tag_id = c.tag_id
WHERE p.tag_id IS NULL
UNION ALL

-- 21) recommends.group_id -> user_groups
SELECT 'recommends.group_id -> user_groups' AS constraint_checked, COUNT(*) AS violations
FROM recommends c
LEFT JOIN user_groups p ON p.group_id = c.group_id
WHERE p.group_id IS NULL
UNION ALL

-- 22) recommends.media_id -> media
SELECT 'recommends.media_id -> media' AS constraint_checked, COUNT(*) AS violations
FROM recommends c
LEFT JOIN media p ON p.media_id = c.media_id
WHERE p.media_id IS NULL
UNION ALL

-- 23) media rows that are in NO child table
SELECT 'Media with no child row' AS constraint_checked, COUNT(*) AS violations
FROM media m
LEFT JOIN books    b  ON b.media_id  = m.media_id
LEFT JOIN tv_shows tv ON tv.media_id = m.media_id
LEFT JOIN movies   mo ON mo.media_id = m.media_id
LEFT JOIN podcasts p  ON p.media_id  = m.media_id
LEFT JOIN songs    s  ON s.media_id  = m.media_id
WHERE b.media_id IS NULL AND tv.media_id IS NULL AND mo.media_id IS NULL
  AND p.media_id IS NULL AND s.media_id IS NULL
UNION ALL

-- 24) media rows that are in MORE THAN ONE child table
SELECT 'Media in two or more child tables' AS constraint_checked, COUNT(*) AS violations
FROM media m
LEFT JOIN books    b  ON b.media_id  = m.media_id
LEFT JOIN tv_shows tv ON tv.media_id = m.media_id
LEFT JOIN movies   mo ON mo.media_id = m.media_id
LEFT JOIN podcasts p  ON p.media_id  = m.media_id
LEFT JOIN songs    s  ON s.media_id  = m.media_id
WHERE (b.media_id IS NOT NULL) + (tv.media_id IS NOT NULL) + (mo.media_id IS NOT NULL)
    + (p.media_id IS NOT NULL) + (s.media_id IS NOT NULL) > 1;
