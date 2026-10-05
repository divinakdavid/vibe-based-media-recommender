-- 07_check_tests.sql                                        OWNER: Lane B (Rules & Operations)
-- Proves every rule in 04_checks.sql (plus two foreign-key rules) actually rejects bad data.
-- Each test tries to insert/delete ONE bad thing. If MySQL rejects it, the test PASSES.
-- Everything runs inside a transaction that is rolled back, so no data is changed.
-- Run after 05_seed_data.sql. Works in the mysql client and MySQL Workbench.
-- RULE: when you add a CHECK to 04_checks.sql, add a test for it here.
--
-- MySQL error codes used below:
--   3819 = a CHECK constraint was violated
--   1452 = cannot add a child row (foreign key failed)
--   1451 = cannot delete a parent row (ON DELETE RESTRICT)

USE media_tracker;

DROP PROCEDURE IF EXISTS run_check_tests;
DROP TEMPORARY TABLE IF EXISTS check_test_results;

-- MEMORY engine is not transactional, so results survive the ROLLBACK at the end.
CREATE TEMPORARY TABLE check_test_results (
    test_no          INT AUTO_INCREMENT PRIMARY KEY,
    constraint_name  VARCHAR(70),
    result           VARCHAR(10)
) ENGINE=MEMORY;

DELIMITER //

CREATE PROCEDURE run_check_tests()
BEGIN
    START TRANSACTION;

    -- ---------- users ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_email (no @)', 'PASS');
        INSERT INTO users (username, email, password_hash) VALUES ('test_a', 'not-an-email', REPEAT('x', 30));
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_email (no @)', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_email (double @@)', 'PASS');
        INSERT INTO users (username, email, password_hash) VALUES ('test_b', 'a@@b.c', REPEAT('x', 30));
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_email (double @@)', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_email (contains space)', 'PASS');
        INSERT INTO users (username, email, password_hash) VALUES ('test_c', 'a b@c.com', REPEAT('x', 30));
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_email (contains space)', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_username_len', 'PASS');
        INSERT INTO users (username, email, password_hash) VALUES ('ab', 'short@example.com', REPEAT('x', 30));
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_username_len', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_password_hash_len', 'PASS');
        INSERT INTO users (username, email, password_hash) VALUES ('test_d', 'weakpw@example.com', 'hash1');
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_password_hash_len', 'FAIL');
    END;

    -- ---------- friends ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_no_self_follow', 'PASS');
        INSERT INTO friends (follower_id, followed_id)
        SELECT user_id, user_id FROM users WHERE username = 'muskan';
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_no_self_follow', 'FAIL');
    END;

    -- ---------- user_groups ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_group_name_not_blank', 'PASS');
        INSERT INTO user_groups (group_name, creator_id)
        SELECT '   ', user_id FROM users WHERE username = 'muskan';
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_group_name_not_blank', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 1451
            INSERT INTO check_test_results (constraint_name, result) VALUES ('creator_id ON DELETE RESTRICT', 'PASS');
        DELETE FROM users WHERE username = 'grace';      -- grace created 'Spooky Season Club'
        INSERT INTO check_test_results (constraint_name, result) VALUES ('creator_id ON DELETE RESTRICT', 'FAIL');
    END;

    -- ---------- media ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_title_not_blank', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('  ', 2000, 'x', 'book');
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_title_not_blank', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_release_year', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Too Old', 1200, 'x', 'book');
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_release_year', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_media_type', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Video Game', 2020, 'x', 'game');
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_media_type', 'FAIL');
    END;

    -- ---------- media children (valid media row first, then a bad child row) ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_page_count', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Book 1', 2020, 'x', 'book');
        INSERT INTO books (media_id, author, isbn, page_count) VALUES (LAST_INSERT_ID(), 'A', '9780000000002', 0);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_page_count', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_isbn_format', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Book 2', 2020, 'x', 'book');
        INSERT INTO books (media_id, author, isbn, page_count) VALUES (LAST_INSERT_ID(), 'A', 'ABCDEFGHIJ', 100);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_isbn_format', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_tv_counts (0 seasons)', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Show 1', 2020, 'x', 'tv_show');
        INSERT INTO tv_shows (media_id, director, episode_count, season_count) VALUES (LAST_INSERT_ID(), 'D', 5, 0);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_tv_counts (0 seasons)', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_tv_counts (episodes < seasons)', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Show 2', 2020, 'x', 'tv_show');
        INSERT INTO tv_shows (media_id, director, episode_count, season_count) VALUES (LAST_INSERT_ID(), 'D', 2, 5);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_tv_counts (episodes < seasons)', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_movie_duration', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Movie', 2020, 'x', 'movie');
        INSERT INTO movies (media_id, director, duration_minutes) VALUES (LAST_INSERT_ID(), 'D', 0);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_movie_duration', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_podcast_episodes', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Podcast', 2020, 'x', 'podcast');
        INSERT INTO podcasts (media_id, episode_count) VALUES (LAST_INSERT_ID(), 0);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_podcast_episodes', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_song_duration', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Test Song', 2020, 'x', 'song');
        INSERT INTO songs (media_id, artist, duration_minutes) VALUES (LAST_INSERT_ID(), 'A', -3.5);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_song_duration', 'FAIL');
    END;

    -- ---------- a movie must not be insertable into books (composite foreign key, error 1452) ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 1452
            INSERT INTO check_test_results (constraint_name, result) VALUES ('fk_child_matches_media_type', 'PASS');
        INSERT INTO media (title, release_year, summary, media_type) VALUES ('Actually A Movie', 2020, 'x', 'movie');
        INSERT INTO books (media_id, author, isbn, page_count) VALUES (LAST_INSERT_ID(), 'A', '9780000000019', 100);
        INSERT INTO check_test_results (constraint_name, result) VALUES ('fk_child_matches_media_type', 'FAIL');
    END;

    -- ---------- tag ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_tag_lowercase', 'PASS');
        INSERT INTO tag (name) VALUES ('LOUDTAG');
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_tag_lowercase', 'FAIL');
    END;

    -- ---------- reviews / tracks ----------
    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_review_not_blank', 'PASS');
        INSERT INTO reviews (user_id, media_id, user_review)
        SELECT u.user_id, m.media_id, '   '
        FROM users u, media m WHERE u.username = 'grace' AND m.title = 'The Secret History';
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_review_not_blank', 'FAIL');
    END;

    BEGIN
        DECLARE EXIT HANDLER FOR 3819
            INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_media_status', 'PASS');
        INSERT INTO tracks (user_id, media_id, media_status)
        SELECT u.user_id, m.media_id, 'binge_watching'
        FROM users u, media m WHERE u.username = 'grace' AND m.title = 'The Secret History';
        INSERT INTO check_test_results (constraint_name, result) VALUES ('chk_media_status', 'FAIL');
    END;

    ROLLBACK;   -- throw away anything a failed test accidentally inserted
END //

DELIMITER ;

CALL run_check_tests();

-- One row per test: PASS = bad data was rejected, FAIL = bad data got in (fix the constraint!)
SELECT test_no, constraint_name, result FROM check_test_results ORDER BY test_no;

SELECT SUM(result = 'PASS') AS passed, SUM(result = 'FAIL') AS failed, COUNT(*) AS total
FROM check_test_results;

DROP PROCEDURE IF EXISTS run_check_tests;
DROP TEMPORARY TABLE IF EXISTS check_test_results;
