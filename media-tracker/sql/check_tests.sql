-- check_tests.sql
-- Proves that each CHECK constraint (and the foreign keys) rejects bad data.
-- Every INSERT/DELETE marked "Expect: ERROR ..." is SUPPOSED to fail. If MySQL accepts one,
-- that constraint is not working.
--
-- Run it after seed_data.sql. A failing statement stops the mysql client unless you use --force:
--     mysql --force -t -u root -p < check_tests.sql          (command line, from this folder)
-- In MySQL Workbench, run the statements one at a time and expect a red error on each test.
--
-- Error codes:  3819 = CHECK constraint violated
--               1451 = cannot delete a row that other rows still point to
--               1452 = cannot insert a row that points to a missing parent row
--
-- The test rows use ids 901 and up and are deleted again at the end.

USE media_tracker;

-- ---------------------------------------------------------------------
-- SETUP: valid media rows (no child rows yet) for the child-table tests below
-- ---------------------------------------------------------------------
INSERT INTO media (media_id, title, release_year, summary, media_type) VALUES
    (901, 'Test Book A',   2020, 'x', 'book'),
    (902, 'Test Book B',   2020, 'x', 'book'),
    (903, 'Test Show A',   2020, 'x', 'tv_show'),
    (904, 'Test Show B',   2020, 'x', 'tv_show'),
    (905, 'Test Movie',    2020, 'x', 'movie'),
    (906, 'Test Podcast',  2020, 'x', 'podcast'),
    (907, 'Test Song',     2020, 'x', 'song');

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------
-- TEST 1: chk_email, no @ sign.                          Expect: ERROR 3819
INSERT INTO users (username, email, password_hash)
VALUES ('test_a', 'not-an-email', '$2b$12$placeholderhashtestuser00');

-- TEST 2: chk_email, two @ signs.                        Expect: ERROR 3819
INSERT INTO users (username, email, password_hash)
VALUES ('test_b', 'a@@b.c', '$2b$12$placeholderhashtestuser00');

-- TEST 3: chk_email, contains a space.                   Expect: ERROR 3819
INSERT INTO users (username, email, password_hash)
VALUES ('test_c', 'a b@c.com', '$2b$12$placeholderhashtestuser00');

-- TEST 4: chk_username_len, username shorter than 3.     Expect: ERROR 3819
INSERT INTO users (username, email, password_hash)
VALUES ('ab', 'short@example.com', '$2b$12$placeholderhashtestuser00');

-- TEST 5: chk_password_hash_len, hash shorter than 20.   Expect: ERROR 3819
INSERT INTO users (username, email, password_hash)
VALUES ('test_d', 'weakpw@example.com', 'hash1');

-- ---------------------------------------------------------------------
-- friends and groups
-- ---------------------------------------------------------------------
-- TEST 6: chk_no_self_follow, user 1 follows user 1.     Expect: ERROR 3819
INSERT INTO friends (follower_id, followed_id)
VALUES (1, 1);

-- TEST 7: chk_group_name_not_blank, blank group name.    Expect: ERROR 3819
INSERT INTO user_groups (group_name, creator_id)
VALUES ('   ', 1);

-- TEST 8: foreign key, group created by a user that does not exist.   Expect: ERROR 1452
INSERT INTO user_groups (group_name, creator_id)
VALUES ('Ghost Group', 999);

-- TEST 9: foreign key, delete grace (user 3) while she still owns a group.   Expect: ERROR 1451
DELETE FROM users WHERE user_id = 3;

-- ---------------------------------------------------------------------
-- media
-- ---------------------------------------------------------------------
-- TEST 10: chk_title_not_blank, blank title.             Expect: ERROR 3819
INSERT INTO media (title, release_year, summary, media_type)
VALUES ('   ', 2000, 'x', 'book');

-- TEST 11: chk_release_year, year before 1400.           Expect: ERROR 3819
INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Too Old', 1200, 'x', 'book');

-- TEST 12: chk_media_type, type not in the list.         Expect: ERROR 3819
INSERT INTO media (title, release_year, summary, media_type)
VALUES ('Video Game', 2020, 'x', 'game');

-- ---------------------------------------------------------------------
-- media children (these use the setup rows 901-907)
-- ---------------------------------------------------------------------
-- TEST 13: chk_page_count, zero pages.                   Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (901, 'A', '9780000000002', 0);

-- TEST 14: chk_isbn_length, ISBN with only 5 characters. Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (902, 'A', '12345', 100);

-- TEST 15: chk_tv_counts, zero seasons.                  Expect: ERROR 3819
INSERT INTO tv_shows (media_id, director, episode_count, season_count)
VALUES (903, 'D', 5, 0);

-- TEST 16: chk_tv_counts, fewer episodes than seasons.   Expect: ERROR 3819
INSERT INTO tv_shows (media_id, director, episode_count, season_count)
VALUES (904, 'D', 2, 5);

-- TEST 17: chk_movie_duration, zero minutes.             Expect: ERROR 3819
INSERT INTO movies (media_id, director, duration_minutes)
VALUES (905, 'D', 0);

-- TEST 18: chk_podcast_episodes, zero episodes.          Expect: ERROR 3819
INSERT INTO podcasts (media_id, episode_count)
VALUES (906, 0);

-- TEST 19: chk_song_duration, negative length.           Expect: ERROR 3819
INSERT INTO songs (media_id, artist, duration_minutes)
VALUES (907, 'A', -3.5);

-- ---------------------------------------------------------------------
-- tag, reviews, tracks
-- ---------------------------------------------------------------------
-- TEST 20: chk_tag_not_blank, blank tag name.            Expect: ERROR 3819
INSERT INTO tag (name)
VALUES ('   ');

-- TEST 21: chk_review_not_blank, blank review.           Expect: ERROR 3819
INSERT INTO reviews (user_id, media_id, user_review)
VALUES (3, 1, '   ');

-- TEST 22: chk_media_status, status not in the list.     Expect: ERROR 3819
INSERT INTO tracks (user_id, media_id, media_status)
VALUES (3, 1, 'binge_watching');

-- ---------------------------------------------------------------------
-- KNOWN LIMITATION (this one is ACCEPTED, it does not fail)
-- Media 905 is a movie, but nothing stops it also being added to books. A CHECK cannot compare
-- two tables. Planned fix for the next sprint: stricter inheritance / referential constraints.
-- ---------------------------------------------------------------------
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (905, 'Wrong table', NULL, NULL);

-- ---------------------------------------------------------------------
-- CLEAN UP: remove everything the tests added
-- ---------------------------------------------------------------------
DELETE FROM books WHERE media_id = 905;
DELETE FROM media WHERE media_id >= 901;

-- Both lists should match the seed data exactly (3 users, 7 media items, 1 group)
SELECT user_id, username FROM users;
SELECT media_id, title FROM media;
SELECT group_id, group_name FROM user_groups;
