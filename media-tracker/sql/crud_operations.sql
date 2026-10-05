-- crud_operations.sql
-- Basic INSERT, UPDATE and DELETE on every table.
-- Safe to re-run: it adds demo rows, changes them, then deletes them, so the database ends
-- up exactly as it started.
--
-- Demo rows use ids 801 and up so they can never clash with the seed data (ids 1-7).
-- Foreign keys have no ON DELETE action, so the DELETE section removes child rows
-- before the parent rows they point to.

USE media_tracker;

-- =====================================================================
-- PART 1: INSERT  (parent rows first, then the rows that point to them)
-- =====================================================================

INSERT INTO users (user_id, username, email, password_hash) VALUES
    (801, 'demo_user',   'demo@example.com',   '$2b$12$demohashdemohashdemoh'),
    (802, 'demo_friend', 'friend@example.com', '$2b$12$demohashdemohashfrien');

INSERT INTO user_groups (group_id, group_name, creator_id) VALUES
    (801, 'Demo Group', 801);

INSERT INTO member_of (group_id, user_id) VALUES
    (801, 801);

INSERT INTO friends (follower_id, followed_id) VALUES
    (801, 802);

-- Each media item is a row in media plus a row in its child table
INSERT INTO media (media_id, title, release_year, summary, media_type) VALUES
    (801, 'Demo Book',    2020, 'A demo book.',    'book'),
    (802, 'Demo Show',    2021, 'A demo show.',    'tv_show'),
    (803, 'Demo Movie',   2022, 'A demo movie.',   'movie'),
    (804, 'Demo Podcast', 2019, 'A demo podcast.', 'podcast'),
    (805, 'Demo Song',    2023, 'A demo song.',    'song');

INSERT INTO books    (media_id, author, isbn, page_count)                  VALUES (801, 'Demo Author', '9781234567897', 300);
INSERT INTO tv_shows (media_id, director, episode_count, season_count)     VALUES (802, 'Demo Director', 16, 2);
INSERT INTO movies   (media_id, director, duration_minutes)                VALUES (803, 'Demo Director', 110.50);
INSERT INTO podcasts (media_id, episode_count)                             VALUES (804, 25);
INSERT INTO songs    (media_id, artist, duration_minutes)                  VALUES (805, 'Demo Artist', 3.50);

INSERT INTO tag (tag_id, name) VALUES
    (801, 'demo_vibe');

INSERT INTO has_tag (media_id, tag_id) VALUES
    (801, 801);

INSERT INTO recommends (group_id, media_id) VALUES
    (801, 801);

INSERT INTO reviews (user_id, media_id, user_review) VALUES
    (801, 801, 'Great demo book.');

INSERT INTO review_tags (user_id, media_id, tag_id) VALUES
    (801, 801, 801);

INSERT INTO tracks (user_id, media_id, media_status) VALUES
    (801, 801, 'want_to_consume');

-- Look at what we just added
SELECT user_id, username, email FROM users WHERE user_id >= 801;
SELECT media_id, title, media_type FROM media WHERE media_id >= 801;


-- =====================================================================
-- PART 2: UPDATE
-- =====================================================================

UPDATE users       SET email = 'demo.updated@example.com' WHERE user_id = 801;
UPDATE user_groups SET group_name = 'Demo Group (renamed)' WHERE group_id = 801;

-- member_of and friends only have key columns, so "updating" means pointing the row elsewhere:
-- demo_user moves into group 1 (Spooky Season Club) and follows muskan (user 1) instead.
UPDATE member_of SET group_id = 1    WHERE group_id = 801 AND user_id = 801;
UPDATE friends   SET followed_id = 1 WHERE follower_id = 801 AND followed_id = 802;

UPDATE media SET summary = 'An updated demo summary.' WHERE media_id = 801;
UPDATE media SET release_year = 2018                  WHERE media_id = 804;

UPDATE books    SET page_count = 350            WHERE media_id = 801;
UPDATE tv_shows SET episode_count = 20          WHERE media_id = 802;
UPDATE movies   SET duration_minutes = 125.25   WHERE media_id = 803;
UPDATE podcasts SET episode_count = 30          WHERE media_id = 804;
UPDATE songs    SET duration_minutes = 4.25     WHERE media_id = 805;

UPDATE tag SET name = 'demo_vibe_renamed' WHERE tag_id = 801;

-- has_tag, recommends and review_tags: swap one key value for another
-- (tag 3 is 'cozy', media 803 is Demo Movie).
UPDATE has_tag     SET tag_id = 3    WHERE media_id = 801 AND tag_id = 801;
UPDATE recommends  SET media_id = 803 WHERE group_id = 801 AND media_id = 801;
UPDATE review_tags SET tag_id = 3    WHERE user_id = 801 AND media_id = 801 AND tag_id = 801;

UPDATE reviews SET user_review = 'Edited: still a great demo book.' WHERE user_id = 801 AND media_id = 801;
UPDATE tracks  SET media_status = 'finished'                        WHERE user_id = 801 AND media_id = 801;

-- Look at a few of the changed rows
SELECT user_id, username, email FROM users WHERE user_id = 801;
SELECT media_id, title, summary FROM media WHERE media_id = 801;
SELECT media_id, duration_minutes FROM movies WHERE media_id = 803;


-- =====================================================================
-- PART 3: DELETE  (rows that point to others first, the rows they point to last)
-- =====================================================================

DELETE FROM review_tags WHERE user_id = 801 AND media_id = 801 AND tag_id = 3;
DELETE FROM reviews     WHERE user_id = 801 AND media_id = 801;
DELETE FROM tracks      WHERE user_id = 801 AND media_id = 801;
DELETE FROM recommends  WHERE group_id = 801 AND media_id = 803;
DELETE FROM has_tag     WHERE media_id = 801 AND tag_id = 3;
DELETE FROM tag         WHERE tag_id = 801;

DELETE FROM books    WHERE media_id = 801;
DELETE FROM tv_shows WHERE media_id = 802;
DELETE FROM movies   WHERE media_id = 803;
DELETE FROM podcasts WHERE media_id = 804;
DELETE FROM songs    WHERE media_id = 805;
DELETE FROM media    WHERE media_id >= 801;

DELETE FROM friends    WHERE follower_id = 801 AND followed_id = 1;
DELETE FROM member_of  WHERE group_id = 1 AND user_id = 801;
DELETE FROM user_groups WHERE group_id = 801;    -- the group must go before its creator
DELETE FROM users      WHERE user_id >= 801;

-- Back to the seed data: 3 users and 7 media items
SELECT user_id, username FROM users;
SELECT media_id, title FROM media;
