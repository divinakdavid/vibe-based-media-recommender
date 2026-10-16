

USE media_tracker;

-- ---------------------------------------------------------------------
-- SETUP: valid media rows for the child-table tests below
-- (901-902 will be books, 903 a TV show, 904 a podcast, 905 a movie, 906 a song)
-- ---------------------------------------------------------------------
INSERT INTO media (media_id, title, release_year, summary) VALUES
    (901, 'Test Book A',   2020, 'x'),
    (902, 'Test Book B',   2020, 'x'),
    (903, 'Test Show',     2020, 'x'),
    (904, 'Test Podcast',  2020, 'x'),
    (905, 'Test Movie',    2020, 'x'),
    (906, 'Test Song',     2020, 'x');

INSERT INTO tv_shows (media_id, director) VALUES (903, 'D');
INSERT INTO podcasts (media_id)           VALUES (904);

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
-- TEST 6: trg_no_self_follow_insert, user 1 follows user 1.   Expect: ERROR 1644
INSERT INTO friends (follower_id, followed_id)
VALUES (1, 1);

-- TEST 7: chk_group_name_not_blank, blank group name.    Expect: ERROR 3819
INSERT INTO user_groups (group_name, creator_id)
VALUES ('   ', 1);

-- TEST 8: foreign key, group created by a user that does not exist.   Expect: ERROR 1452
INSERT INTO user_groups (group_name, creator_id)
VALUES ('Ghost Group', 999);

-- TEST 9: ON DELETE RESTRICT, delete grace (user 3) while she still owns a group.   Expect: ERROR 1451
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
-- media children (these use the setup rows 901-906)
-- ---------------------------------------------------------------------
-- TEST 12: chk_page_count, zero pages.                   Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (901, 'A', '9780000000002', 0);

-- TEST 13: chk_isbn_format, ISBN with only 5 digits.     Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (902, 'A', '12345', 100);

-- TEST 14: chk_isbn_format, right length but has hyphens. Expect: ERROR 3819
INSERT INTO books (media_id, author, isbn, page_count)
VALUES (902, 'A', '978-14000317', 100);

-- TEST 15: chk_movie_duration, zero minutes.             Expect: ERROR 3819
INSERT INTO movies (media_id, director, duration_minutes)
VALUES (905, 'D', 0);

-- TEST 16: chk_song_duration, negative length.           Expect: ERROR 3819
INSERT INTO songs (media_id, artist, duration_minutes)
VALUES (906, 'A', -3.5);

-- ---------------------------------------------------------------------
-- episodes (weak entities; 903 is a TV show, 904 a podcast)
-- ---------------------------------------------------------------------
-- TEST 17: chk_tv_episode_numbers, season 0.             Expect: ERROR 3819
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (903, 0, 1, 'Ep', 40);

-- TEST 18: chk_tv_episode_title, blank title.            Expect: ERROR 3819
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (903, 1, 1, '   ', 40);

-- TEST 19: chk_tv_episode_duration, zero minutes.        Expect: ERROR 3819
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (903, 1, 1, 'Ep', 0);

-- TEST 20: weak entity, episode of a show that does not exist.   Expect: ERROR 1452
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (999, 1, 1, 'Orphan Episode', 40);

-- TEST 21: weak entity, TV episode on a podcast (904 is not a TV show).   Expect: ERROR 1452
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
VALUES (904, 1, 1, 'Wrong Owner', 40);

-- TEST 22: chk_podcast_episode_number, episode 0.        Expect: ERROR 3819
INSERT INTO podcast_episodes (media_id, episode_number, title, duration_minutes)
VALUES (904, 0, 'Ep', 30);

-- TEST 23: chk_podcast_episode_title, blank title.       Expect: ERROR 3819
INSERT INTO podcast_episodes (media_id, episode_number, title, duration_minutes)
VALUES (904, 1, '   ', 30);

-- TEST 24: chk_podcast_episode_duration, negative.       Expect: ERROR 3819
INSERT INTO podcast_episodes (media_id, episode_number, title, duration_minutes)
VALUES (904, 1, 'Ep', -5);

-- ---------------------------------------------------------------------
-- tag, reviews, tracks
-- ---------------------------------------------------------------------
-- TEST 25: chk_tag_not_blank, blank tag name.            Expect: ERROR 3819
INSERT INTO tag (name)
VALUES ('   ');

-- TEST 26: chk_tag_lowercase, tag with capital letters.  Expect: ERROR 3819
INSERT INTO tag (name)
VALUES ('Cozy Vibes');

-- TEST 27: chk_review_not_blank, blank review.           Expect: ERROR 3819
INSERT INTO reviews (user_id, media_id, user_review)
VALUES (3, 1, '   ');

-- TEST 28: chk_media_status, status not in the list.     Expect: ERROR 3819
INSERT INTO tracks (user_id, media_id, media_status)
VALUES (3, 1, 'binge_watching');

-- ---------------------------------------------------------------------
-- KNOWN LIMITATION (this one is ACCEPTED, it does not fail)
-- The ISA should be disjoint: a media item is exactly one type. Nothing yet stops media 905
-- from being both a movie and a book. A CHECK cannot compare two tables; planned fix for the
-- next sprint: triggers on the child tables.
-- ---------------------------------------------------------------------
INSERT INTO movies (media_id, director, duration_minutes) VALUES (905, 'D', 100);
INSERT INTO books  (media_id, author, isbn, page_count)  VALUES (905, 'Wrong table', NULL, NULL);

-- ---------------------------------------------------------------------
-- CLEAN UP: deleting the test media removes their child rows too (ON DELETE CASCADE)
-- ---------------------------------------------------------------------
DELETE FROM media WHERE media_id >= 901;

-- Both lists should match the seed data exactly (3 users, 7 media items, 1 group)
SELECT user_id, username FROM users;
SELECT media_id, title FROM media;
SELECT group_id, group_name FROM user_groups;
