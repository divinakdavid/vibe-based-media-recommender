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
-- SETUP: valid media rows for the child-table tests below. Media 905 and 906 also get their
-- child row now, because the episode tests need a real show and a real podcast to point at.
-- ---------------------------------------------------------------------
INSERT INTO media (media_id, title, release_year, summary) VALUES
    (901, 'Test Book A',   2020, 'x'),
    (902, 'Test Book B',   2020, 'x'),
    (903, 'Test Movie',    2020, 'x'),
    (904, 'Test Song',     2020, 'x'),
    (905, 'Test Show',     2020, 'x'),
    (906, 'Test Podcast',  2020, 'x');

INSERT INTO tv_shows (media_id, director) VALUES (905, 'D');
INSERT INTO podcasts (media_id)           VALUES (906);

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
INSERT INTO media (title, release_year, summary)
VALUES ('   ', 2000, 'x');

-- TEST 11: chk_release_year, year before 1400.           Expect: ERROR 3819
INSERT INTO media (title, release_year, summary)
VALUES ('Too Old', 1200, 'x');

-- ---------------------------------------------------------------------
-- media children (these use the setup rows 901-907)
-- ---------------------------------------------------------------------
-- TEST 12: chk_page_count, zero pages.                   Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (901, 'A', '9780000000002', 0);

-- TEST 13: chk_isbn_length, ISBN with only 5 characters. Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (902, 'A', '12345', 100);

-- TEST 14: chk_movie_duration, zero minutes.             Expect: ERROR 3819
INSERT INTO movies (media_id, director, duration_minutes)
VALUES (903, 'D', 0);

-- TEST 15: chk_song_duration, negative length.           Expect: ERROR 3819
INSERT INTO songs (media_id, artist, duration_minutes)
VALUES (904, 'A', -3.5);

-- ---------------------------------------------------------------------
-- episodes (weak entity sets; they use the show 905 and the podcast 906 from the setup)
-- ---------------------------------------------------------------------
-- TEST 16: chk_tv_episode_numbers, season number 0.      Expect: ERROR 3819
INSERT INTO tv_episodes (media_id, season_number, episode_number, title)
VALUES (905, 0, 1, 'Pilot');

-- TEST 17: chk_tv_episode_title, blank title.            Expect: ERROR 3819
INSERT INTO tv_episodes (media_id, season_number, episode_number, title)
VALUES (905, 1, 1, '   ');

-- TEST 18: chk_tv_episode_duration, zero minutes.        Expect: ERROR 3819
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (905, 1, 1, 'Pilot', 0);

-- TEST 19: chk_podcast_episode_number, episode number 0. Expect: ERROR 3819
INSERT INTO podcast_episodes (media_id, episode_number, title)
VALUES (906, 0, 'Pilot');

-- TEST 20: chk_podcast_episode_title, blank title.       Expect: ERROR 3819
INSERT INTO podcast_episodes (media_id, episode_number, title)
VALUES (906, 1, '   ');

-- TEST 21: chk_podcast_episode_duration, negative length. Expect: ERROR 3819
INSERT INTO podcast_episodes (media_id, episode_number, title, duration_minutes)
VALUES (906, 1, 'Pilot', -5);

-- ---------------------------------------------------------------------
-- tag, reviews, tracks
-- ---------------------------------------------------------------------
-- TEST 22: chk_tag_not_blank, blank tag name.            Expect: ERROR 3819
INSERT INTO tag (name)
VALUES ('   ');

-- TEST 23: chk_review_not_blank, blank review.           Expect: ERROR 3819
INSERT INTO reviews (user_id, media_id, user_review)
VALUES (3, 1, '   ');

-- TEST 24: chk_media_status, status not in the list.     Expect: ERROR 3819
INSERT INTO tracks (user_id, media_id, media_status)
VALUES (3, 1, 'binge_watching');

-- ---------------------------------------------------------------------
-- KNOWN LIMITATION (this one is ACCEPTED, it does not fail)
-- Each media item is meant to be in exactly one child table, but MySQL cannot declare that rule
-- across tables. Media 903 is a movie, yet nothing stops it also being added to books, and the
-- setup rows above are media rows with no child row at all. integrity_audit.sql reports both
-- kinds of problem; they are rules the data entry has to respect.
-- ---------------------------------------------------------------------
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (903, 'Wrong table', NULL, NULL);

-- ---------------------------------------------------------------------
-- CLEAN UP: remove everything the tests added
-- ---------------------------------------------------------------------
-- ON DELETE CASCADE removes the child rows (the wrong books row, tv_shows, podcasts) with them.
DELETE FROM media WHERE media_id >= 901;

-- Both lists should match the seed data exactly (3 users, 7 media items, 1 group)
SELECT user_id, username FROM users;
SELECT media_id, title FROM media;
SELECT group_id, group_name FROM user_groups;