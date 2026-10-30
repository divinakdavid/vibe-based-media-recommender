-- fk_tests.sql
-- Tests every ON DELETE / ON UPDATE policy: what MySQL must REFUSE and what it must CASCADE.
-- Run it after seed_data.sql. It builds its own test rows (ids 951 and up), exercises them,
-- and deletes everything again, so the database ends as it started.
--
--   Part 1  RESTRICT tests: each statement marked "Expect: ERROR ..." is SUPPOSED to fail.
--   Part 2  CASCADE tests: delete a parent, then count its children. Every "rows_left" must
--           equal "expected" (0), i.e. no orphaned rows are left behind.
--
-- Run it with --force so the client keeps going after the expected errors:
--     mysql --force -t -u root -p < fk_tests.sql          (command line, from this folder)
-- In MySQL Workbench, run it statement by statement and expect a red error on each TEST.
-- Afterwards run integrity_audit.sql: every violation count must still be 0.
--
-- Error codes:  1451 = cannot delete or update a parent row that other rows still point to
--               1452 = cannot add a row that points to a missing parent row
-- COUNT is used in Part 2 only so each result prints as a visible number.

USE media_tracker;

-- ---------------------------------------------------------------------
-- SETUP: one parent of every kind, with children pointing at each
-- ---------------------------------------------------------------------
INSERT INTO users (user_id, username, email, password_hash) VALUES
    (951, 'fk_owner',  'fk_owner@example.com',  '$2b$12$fktestplaceholderhash01'),
    (952, 'fk_friend', 'fk_friend@example.com', '$2b$12$fktestplaceholderhash02');

INSERT INTO user_groups (group_id, group_name, creator_id) VALUES
    (951, 'FK Test Group', 951);                              -- fk_owner created it

INSERT INTO member_of (group_id, user_id) VALUES
    (951, 951),
    (951, 952);

INSERT INTO friends (follower_id, followed_id) VALUES
    (951, 952);

INSERT INTO media (media_id, title, release_year, summary) VALUES
    (951, 'FK Test Book',    2020, 'x'),
    (952, 'FK Test Show',    2020, 'x'),
    (953, 'FK Test Podcast', 2020, 'x');

INSERT INTO books (media_id, author, isbn, page_count) VALUES (951, 'A', '9780000000002', 100);
INSERT INTO tv_shows (media_id, director)              VALUES (952, 'D');
INSERT INTO podcasts (media_id)                        VALUES (953);

INSERT INTO tv_episodes (media_id, season_number, episode_number, title) VALUES
    (952, 1, 1, 'Episode 1'),
    (952, 1, 2, 'Episode 2');

INSERT INTO podcast_episodes (media_id, episode_number, title) VALUES
    (953, 1, 'Episode 1');

INSERT INTO tag (tag_id, name) VALUES
    (951, 'fk_test_vibe');

INSERT INTO has_tag (media_id, tag_id) VALUES
    (951, 951);

-- group 951 recommends two items; the seed group 1 also recommends the book
INSERT INTO recommends (group_id, media_id) VALUES
    (951, 951),
    (951, 952),
    (1,   951);

-- fk_owner reviews and tracks the book; fk_friend reviews and tracks seed media 1
INSERT INTO reviews (user_id, media_id, user_review) VALUES
    (951, 951, 'x'),
    (952, 1,   'x');

INSERT INTO review_tags (user_id, media_id, tag_id) VALUES
    (951, 951, 951),
    (952, 1,   951);

INSERT INTO tracks (user_id, media_id, media_status) VALUES
    (951, 951, 'finished'),
    (952, 1,   'dropped');

-- =====================================================================
-- PART 1: RESTRICT and rejected references (each must fail)
-- =====================================================================

-- TEST 1: user_groups.creator_id is ON DELETE RESTRICT: a group's creator cannot be deleted.
--                                                        Expect: ERROR 1451
DELETE FROM users WHERE user_id = 951;

-- TEST 2: has_tag.tag_id and review_tags.tag_id are ON DELETE RESTRICT: a tag in use cannot
--         be deleted.                                    Expect: ERROR 1451
DELETE FROM tag WHERE tag_id = 951;

-- TEST 3: every foreign key is ON UPDATE RESTRICT: a referenced user id cannot be changed.
--                                                        Expect: ERROR 1451
UPDATE users SET user_id = 9951 WHERE user_id = 951;

-- TEST 4: ...and the same for a referenced media id.     Expect: ERROR 1451
UPDATE media SET media_id = 9951 WHERE media_id = 951;

-- TEST 5: composite foreign key: fk_friend never reviewed media 951, so a review tag for that
--         pair cannot exist.                             Expect: ERROR 1452
INSERT INTO review_tags (user_id, media_id, tag_id) VALUES (952, 951, 951);

-- TEST 6: weak entity: media 951 is a book, not a TV show, so it cannot have TV episodes.
--                                                        Expect: ERROR 1452
INSERT INTO tv_episodes (media_id, season_number, episode_number, title)
VALUES (951, 1, 1, 'Wrong parent');

-- TEST 7: a row cannot point at a user that does not exist.   Expect: ERROR 1452
INSERT INTO tracks (user_id, media_id, media_status) VALUES (9999, 951, 'finished');

-- =====================================================================
-- PART 2: CASCADE (delete a parent, then every child count must be 0)
-- =====================================================================

-- TEST 8: deleting a group removes its memberships and its recommendations.
DELETE FROM user_groups WHERE group_id = 951;
SELECT 'delete group -> its member_of rows'   AS test, COUNT(*) AS rows_left, 0 AS expected
FROM member_of WHERE group_id = 951;
SELECT 'delete group -> its recommends rows'  AS test, COUNT(*) AS rows_left, 0 AS expected
FROM recommends WHERE group_id = 951;

-- TEST 9: deleting a TV show cascades twice: media -> tv_shows -> tv_episodes.
DELETE FROM media WHERE media_id = 952;
SELECT 'delete media -> its tv_shows row'     AS test, COUNT(*) AS rows_left, 0 AS expected
FROM tv_shows WHERE media_id = 952;
SELECT 'delete media -> its tv_episodes'      AS test, COUNT(*) AS rows_left, 0 AS expected
FROM tv_episodes WHERE media_id = 952;

-- TEST 10: deleting a podcast cascades the same way: media -> podcasts -> podcast_episodes.
DELETE FROM media WHERE media_id = 953;
SELECT 'delete media -> its podcasts row'     AS test, COUNT(*) AS rows_left, 0 AS expected
FROM podcasts WHERE media_id = 953;
SELECT 'delete media -> its podcast_episodes' AS test, COUNT(*) AS rows_left, 0 AS expected
FROM podcast_episodes WHERE media_id = 953;

-- TEST 11: deleting a book removes everything that was about it.
DELETE FROM media WHERE media_id = 951;
SELECT 'delete media -> its books row'        AS test, COUNT(*) AS rows_left, 0 AS expected
FROM books WHERE media_id = 951;
SELECT 'delete media -> its has_tag rows'     AS test, COUNT(*) AS rows_left, 0 AS expected
FROM has_tag WHERE media_id = 951;
SELECT 'delete media -> its recommends rows'  AS test, COUNT(*) AS rows_left, 0 AS expected
FROM recommends WHERE media_id = 951;
SELECT 'delete media -> its tracks rows'      AS test, COUNT(*) AS rows_left, 0 AS expected
FROM tracks WHERE media_id = 951;
SELECT 'delete media -> its reviews'          AS test, COUNT(*) AS rows_left, 0 AS expected
FROM reviews WHERE media_id = 951;
SELECT 'delete media -> its review_tags'      AS test, COUNT(*) AS rows_left, 0 AS expected
FROM review_tags WHERE media_id = 951;

-- TEST 12: deleting a user removes their friendships, memberships, tracks and reviews
-- (a review's tags go with the review: users -> reviews -> review_tags).
DELETE FROM users WHERE user_id = 952;
SELECT 'delete user -> friends rows'          AS test, COUNT(*) AS rows_left, 0 AS expected
FROM friends WHERE follower_id = 952 OR followed_id = 952;
SELECT 'delete user -> member_of rows'        AS test, COUNT(*) AS rows_left, 0 AS expected
FROM member_of WHERE user_id = 952;
SELECT 'delete user -> tracks rows'           AS test, COUNT(*) AS rows_left, 0 AS expected
FROM tracks WHERE user_id = 952;
SELECT 'delete user -> reviews'               AS test, COUNT(*) AS rows_left, 0 AS expected
FROM reviews WHERE user_id = 952;
SELECT 'delete user -> review_tags'           AS test, COUNT(*) AS rows_left, 0 AS expected
FROM review_tags WHERE user_id = 952;

-- TEST 13: RESTRICT lets go once nothing points at the parent: the group is gone, so its
-- creator can now be deleted, and no review tag uses the tag any more, so it can be deleted.
DELETE FROM users WHERE user_id = 951;
DELETE FROM tag WHERE tag_id = 951;
SELECT 'delete unused user and tag: rows left' AS test,
       (SELECT COUNT(*) FROM users WHERE user_id >= 951)
     + (SELECT COUNT(*) FROM tag   WHERE tag_id  >= 951) AS rows_left, 0 AS expected;

-- =====================================================================
-- CLEAN-UP CHECK: nothing from these tests may remain in any table
-- =====================================================================
SELECT 'test rows left in the whole database' AS test,
       (SELECT COUNT(*) FROM users            WHERE user_id  >= 951)
     + (SELECT COUNT(*) FROM user_groups      WHERE group_id >= 951)
     + (SELECT COUNT(*) FROM member_of        WHERE group_id >= 951 OR user_id >= 951)
     + (SELECT COUNT(*) FROM friends          WHERE follower_id >= 951 OR followed_id >= 951)
     + (SELECT COUNT(*) FROM media            WHERE media_id >= 951)
     + (SELECT COUNT(*) FROM tag              WHERE tag_id   >= 951)
     + (SELECT COUNT(*) FROM tv_episodes      WHERE media_id >= 951)
     + (SELECT COUNT(*) FROM podcast_episodes WHERE media_id >= 951)
     + (SELECT COUNT(*) FROM has_tag          WHERE media_id >= 951 OR tag_id >= 951)
     + (SELECT COUNT(*) FROM recommends       WHERE group_id >= 951 OR media_id >= 951)
     + (SELECT COUNT(*) FROM reviews          WHERE user_id >= 951 OR media_id >= 951)
     + (SELECT COUNT(*) FROM review_tags      WHERE user_id >= 951 OR media_id >= 951 OR tag_id >= 951)
     + (SELECT COUNT(*) FROM tracks           WHERE user_id >= 951 OR media_id >= 951) AS rows_left,
       0 AS expected;
