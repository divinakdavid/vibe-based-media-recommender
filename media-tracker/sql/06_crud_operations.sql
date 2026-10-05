-- 06_crud_operations.sql                                    OWNER: Lane B (Rules & Operations)
-- Basic INSERT / UPDATE / DELETE for EVERY table.
-- Wrapped in a transaction that ROLLS BACK at the end, so you can re-run it as often as you
-- like without changing the seed data. To keep the changes, change ROLLBACK to COMMIT.
-- Rows are looked up by natural keys (username, title, tag name) instead of hard-coded ids.

USE media_tracker;

-- MySQL Workbench blocks UPDATE/DELETE whose WHERE doesn't use a key column (error 1175).
-- Turn that off for this session; it is turned back on at the bottom.
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;

-- =====================================================================
-- PART 1: INSERT  (parents first, then link tables)
-- =====================================================================

-- users
INSERT INTO users (username, email, password_hash) VALUES
    ('demo_user',   'demo@example.com',   '$2b$12$demohashdemohashdemoh'),
    ('demo_friend', 'friend@example.com', '$2b$12$demohashdemohashfrien');
SELECT user_id, username FROM users WHERE username LIKE 'demo\_%';

-- user_groups (Creates: creator_id = demo_user)
INSERT INTO user_groups (group_name, creator_id)
SELECT 'Demo Group', user_id FROM users WHERE username = 'demo_user';
SELECT group_id, group_name, creator_id FROM user_groups WHERE group_name = 'Demo Group';

-- member_of
INSERT INTO member_of (group_id, user_id)
SELECT g.group_id, u.user_id
FROM user_groups g, users u
WHERE g.group_name = 'Demo Group' AND u.username = 'demo_user';

-- friends: demo_user follows demo_friend
INSERT INTO friends (follower_id, followed_id)
SELECT a.user_id, b.user_id
FROM users a, users b
WHERE a.username = 'demo_user' AND b.username = 'demo_friend';

-- media + one child row each.
-- MySQL has no RETURNING, so LAST_INSERT_ID() gives the media_id we just created.
-- Do NOT list media_type in the child INSERT, MySQL fills it in.
INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Demo Book', 2020, 'A demo book.', 'book');
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (LAST_INSERT_ID(), 'Demo Author', '9781234567897', 300);

INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Demo Show', 2021, 'A demo show.', 'tv_show');
INSERT INTO tv_shows (media_id, director, episode_count, season_count)
VALUES (LAST_INSERT_ID(), 'Demo Director', 16, 2);

INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Demo Movie', 2022, 'A demo movie.', 'movie');
INSERT INTO movies (media_id, director, duration_minutes)
VALUES (LAST_INSERT_ID(), 'Demo Director', 110);

INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Demo Podcast', 2019, 'A demo podcast.', 'podcast');
INSERT INTO podcasts (media_id, episode_count)
VALUES (LAST_INSERT_ID(), 25);

INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Demo Song', 2023, 'A demo song.', 'song');
INSERT INTO songs (media_id, artist, duration_minutes)
VALUES (LAST_INSERT_ID(), 'Demo Artist', 3.50);

SELECT media_id, title, media_type FROM media WHERE title LIKE 'Demo %';

-- tag
INSERT INTO tag (name) VALUES ('demo_vibe');

-- has_tag
INSERT INTO has_tag (media_id, tag_id)
SELECT m.media_id, t.tag_id
FROM media m, tag t
WHERE m.title = 'Demo Book' AND t.name = 'demo_vibe';

-- recommends
INSERT INTO recommends (group_id, media_id)
SELECT g.group_id, m.media_id
FROM user_groups g, media m
WHERE g.group_name = 'Demo Group' AND m.title = 'Demo Book';

-- reviews
INSERT INTO reviews (user_id, media_id, user_review)
SELECT u.user_id, m.media_id, 'Great demo book.'
FROM users u, media m
WHERE u.username = 'demo_user' AND m.title = 'Demo Book';

-- review_tags
INSERT INTO review_tags (user_id, media_id, tag_id)
SELECT u.user_id, m.media_id, t.tag_id
FROM users u, media m, tag t
WHERE u.username = 'demo_user' AND m.title = 'Demo Book' AND t.name = 'demo_vibe';

-- tracks
INSERT INTO tracks (user_id, media_id, media_status)
SELECT u.user_id, m.media_id, 'want_to_consume'
FROM users u, media m
WHERE u.username = 'demo_user' AND m.title = 'Demo Book';


-- =====================================================================
-- PART 2: UPDATE
-- =====================================================================

UPDATE users SET email = 'demo.updated@example.com' WHERE username = 'demo_user';

UPDATE user_groups SET group_name = 'Demo Group (renamed)' WHERE group_name = 'Demo Group';

-- member_of only has key columns, so "update" means moving a member to another group
UPDATE member_of
SET group_id = (SELECT group_id FROM user_groups WHERE group_name = 'Spooky Season Club')
WHERE user_id  = (SELECT user_id  FROM users       WHERE username   = 'demo_user')
  AND group_id = (SELECT group_id FROM user_groups WHERE group_name = 'Demo Group (renamed)');

-- friends: re-point demo_user's follow from demo_friend to muskan
UPDATE friends
SET followed_id = (SELECT user_id FROM users WHERE username = 'muskan')
WHERE follower_id = (SELECT user_id FROM users WHERE username = 'demo_user')
  AND followed_id = (SELECT user_id FROM users WHERE username = 'demo_friend');

UPDATE media SET summary = 'An updated demo summary.' WHERE title = 'Demo Book';
UPDATE media SET release_year = 2018 WHERE title = 'Demo Podcast';

UPDATE books    SET page_count = 350            WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Book');
UPDATE tv_shows SET episode_count = 20          WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Show');
UPDATE movies   SET duration_minutes = 125      WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Movie');
UPDATE podcasts SET episode_count = 30          WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Podcast');
UPDATE songs    SET duration_minutes = 4.25     WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Song');

UPDATE tag SET name = 'demo_vibe_renamed' WHERE name = 'demo_vibe';

-- has_tag: swap the demo tag for 'cozy' on Demo Book
UPDATE has_tag
SET tag_id = (SELECT tag_id FROM tag WHERE name = 'cozy')
WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Book')
  AND tag_id   = (SELECT tag_id   FROM tag   WHERE name  = 'demo_vibe_renamed');

-- recommends: group now recommends Demo Movie instead of Demo Book
UPDATE recommends
SET media_id = (SELECT media_id FROM media WHERE title = 'Demo Movie')
WHERE group_id = (SELECT group_id FROM user_groups WHERE group_name = 'Demo Group (renamed)')
  AND media_id = (SELECT media_id FROM media WHERE title = 'Demo Book');

UPDATE reviews
SET user_review = 'Edited: still a great demo book.'
WHERE user_id  = (SELECT user_id  FROM users WHERE username = 'demo_user')
  AND media_id = (SELECT media_id FROM media WHERE title = 'Demo Book');

UPDATE review_tags
SET tag_id = (SELECT tag_id FROM tag WHERE name = 'cozy')
WHERE user_id  = (SELECT user_id  FROM users WHERE username = 'demo_user')
  AND media_id = (SELECT media_id FROM media WHERE title = 'Demo Book')
  AND tag_id   = (SELECT tag_id   FROM tag   WHERE name  = 'demo_vibe_renamed');

UPDATE tracks
SET media_status = 'finished'
WHERE user_id  = (SELECT user_id  FROM users WHERE username = 'demo_user')
  AND media_id = (SELECT media_id FROM media WHERE title = 'Demo Book');

-- Peek at a few updated rows before we delete them
SELECT username, email FROM users WHERE username = 'demo_user';
SELECT title, summary FROM media WHERE title = 'Demo Book';


-- =====================================================================
-- PART 3: DELETE  (children first, parents last)
-- =====================================================================

DELETE FROM review_tags
WHERE user_id = (SELECT user_id FROM users WHERE username = 'demo_user');

DELETE FROM reviews
WHERE user_id = (SELECT user_id FROM users WHERE username = 'demo_user');

DELETE FROM tracks
WHERE user_id = (SELECT user_id FROM users WHERE username = 'demo_user');

DELETE FROM recommends
WHERE group_id = (SELECT group_id FROM user_groups WHERE group_name = 'Demo Group (renamed)');

DELETE FROM has_tag
WHERE media_id IN (SELECT media_id FROM media WHERE title LIKE 'Demo %');

DELETE FROM tag WHERE name = 'demo_vibe_renamed';

DELETE FROM books    WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Book');
DELETE FROM tv_shows WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Show');
DELETE FROM movies   WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Movie');
DELETE FROM podcasts WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Podcast');
DELETE FROM songs    WHERE media_id = (SELECT media_id FROM media WHERE title = 'Demo Song');

DELETE FROM media WHERE title LIKE 'Demo %';

DELETE FROM friends
WHERE follower_id = (SELECT user_id FROM users WHERE username = 'demo_user');

DELETE FROM member_of
WHERE user_id = (SELECT user_id FROM users WHERE username = 'demo_user');

-- Must delete the group before its creator (creator_id is ON DELETE RESTRICT)
DELETE FROM user_groups WHERE group_name = 'Demo Group (renamed)';

DELETE FROM users WHERE username IN ('demo_user', 'demo_friend');

-- Everything above was practice. Undo it all:
ROLLBACK;
-- Change ROLLBACK to COMMIT if you want the changes to stick.

SET SQL_SAFE_UPDATES = 1;
