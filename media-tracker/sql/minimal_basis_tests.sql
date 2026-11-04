-- minimal_basis_tests.sql
-- Evidence for the minimal basis in docs/minimal_basis.md.
--
--   T1  every FD in the minimal basis (28 FDs) holds in the data
--   T2  every left side in the basis (17) is a PRIMARY KEY or UNIQUE index, and title is not one
--   T3  no left side can be shortened: the schema accepts rows that break every shorter version
--   T4  MySQL rejects a row that would break a basis FD
--   T5  the data is unchanged afterwards
--
-- Runs in a transaction and rolls back, so the data is unchanged and the file can be rerun.
-- From the sql folder:  mysql -u root -p -t < minimal_basis_tests.sql

USE media_tracker;

START TRANSACTION;

-- ---------------------------------------------------------------------
-- T1  Every FD in the minimal basis holds in the data.
--     X -> A is broken if two rows agree on X but differ on A. Each check joins the table
--     to itself on X and counts the rows where A differs (<=> treats two NULLs as equal).
--     One row per table that has FDs; the five key-only tables have an empty basis.
-- ---------------------------------------------------------------------
SELECT CONCAT('T1 ', tbl) AS test, 0 AS expected, violations AS actual,
       IF(violations = 0, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'users (5 FDs)' AS tbl,
          (SELECT COUNT(*) FROM users a JOIN users b ON a.user_id = b.user_id
           WHERE NOT (a.username <=> b.username) OR NOT (a.email <=> b.email)
              OR NOT (a.password_hash <=> b.password_hash))
        + (SELECT COUNT(*) FROM users a JOIN users b ON a.username = b.username
           WHERE NOT (a.user_id <=> b.user_id))
        + (SELECT COUNT(*) FROM users a JOIN users b ON a.email = b.email
           WHERE NOT (a.user_id <=> b.user_id)) AS violations
    UNION ALL
    SELECT 'user_groups (2 FDs)',
          (SELECT COUNT(*) FROM user_groups a JOIN user_groups b ON a.group_id = b.group_id
           WHERE NOT (a.group_name <=> b.group_name) OR NOT (a.creator_id <=> b.creator_id))
    UNION ALL
    SELECT 'media (3 FDs)',
          (SELECT COUNT(*) FROM media a JOIN media b ON a.media_id = b.media_id
           WHERE NOT (a.title <=> b.title) OR NOT (a.release_year <=> b.release_year)
              OR NOT (a.summary <=> b.summary))
    UNION ALL
    SELECT 'books (4 FDs)',
          (SELECT COUNT(*) FROM books a JOIN books b ON a.media_id = b.media_id
           WHERE NOT (a.author <=> b.author) OR NOT (a.isbn <=> b.isbn)
              OR NOT (a.page_count <=> b.page_count))
        + (SELECT COUNT(*) FROM books a JOIN books b ON a.isbn = b.isbn   -- NULL isbns never join
           WHERE NOT (a.media_id <=> b.media_id))
    UNION ALL
    SELECT 'tv_shows (1 FD)',
          (SELECT COUNT(*) FROM tv_shows a JOIN tv_shows b ON a.media_id = b.media_id
           WHERE NOT (a.director <=> b.director))
    UNION ALL
    SELECT 'movies (2 FDs)',
          (SELECT COUNT(*) FROM movies a JOIN movies b ON a.media_id = b.media_id
           WHERE NOT (a.director <=> b.director)
              OR NOT (a.duration_minutes <=> b.duration_minutes))
    UNION ALL
    SELECT 'podcasts (1 FD)',
          (SELECT COUNT(*) FROM podcasts a JOIN podcasts b ON a.media_id = b.media_id
           WHERE NOT (a.host <=> b.host))
    UNION ALL
    SELECT 'songs (2 FDs)',
          (SELECT COUNT(*) FROM songs a JOIN songs b ON a.media_id = b.media_id
           WHERE NOT (a.artist <=> b.artist)
              OR NOT (a.duration_minutes <=> b.duration_minutes))
    UNION ALL
    SELECT 'tv_episodes (2 FDs)',
          (SELECT COUNT(*) FROM tv_episodes a JOIN tv_episodes b
             ON a.media_id = b.media_id AND a.season_number = b.season_number
            AND a.episode_number = b.episode_number
           WHERE NOT (a.title <=> b.title)
              OR NOT (a.duration_minutes <=> b.duration_minutes))
    UNION ALL
    SELECT 'podcast_episodes (2 FDs)',
          (SELECT COUNT(*) FROM podcast_episodes a JOIN podcast_episodes b
             ON a.media_id = b.media_id AND a.episode_number = b.episode_number
           WHERE NOT (a.title <=> b.title)
              OR NOT (a.duration_minutes <=> b.duration_minutes))
    UNION ALL
    SELECT 'tag (2 FDs)',
          (SELECT COUNT(*) FROM tag a JOIN tag b ON a.tag_id = b.tag_id
           WHERE NOT (a.name <=> b.name))
        + (SELECT COUNT(*) FROM tag a JOIN tag b ON a.name = b.name
           WHERE NOT (a.tag_id <=> b.tag_id))
    UNION ALL
    SELECT 'tracks (1 FD)',
          (SELECT COUNT(*) FROM tracks a JOIN tracks b
             ON a.user_id = b.user_id AND a.media_id = b.media_id
           WHERE NOT (a.media_status <=> b.media_status))
    UNION ALL
    SELECT 'reviews (1 FD)',
          (SELECT COUNT(*) FROM reviews a JOIN reviews b
             ON a.user_id = b.user_id AND a.media_id = b.media_id
           WHERE NOT (a.user_review <=> b.user_review))
) AS fd_checks;

-- ---------------------------------------------------------------------
-- T2  Every left side in the basis is declared as a PRIMARY KEY or UNIQUE index, so MySQL
--     enforces every FD in the basis. Both lists are written as "table" + "col1,col2,...".
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE basis_lhs (tbl VARCHAR(64), lhs VARCHAR(255));
INSERT INTO basis_lhs VALUES
    ('users', 'user_id'), ('users', 'username'), ('users', 'email'),
    ('user_groups', 'group_id'),
    ('media', 'media_id'),
    ('books', 'media_id'), ('books', 'isbn'),
    ('tv_shows', 'media_id'), ('movies', 'media_id'), ('podcasts', 'media_id'),
    ('songs', 'media_id'),
    ('tv_episodes', 'media_id,season_number,episode_number'),
    ('podcast_episodes', 'media_id,episode_number'),
    ('tag', 'tag_id'), ('tag', 'name'),
    ('tracks', 'user_id,media_id'),
    ('reviews', 'user_id,media_id');

CREATE TEMPORARY TABLE unique_indexes AS
SELECT TABLE_NAME AS tbl,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS cols
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'media_tracker' AND NON_UNIQUE = 0
GROUP BY TABLE_NAME, INDEX_NAME;

SET @actual = (SELECT COUNT(*) FROM basis_lhs AS b
               JOIN unique_indexes AS k ON k.tbl = b.tbl AND k.cols = b.lhs);
SET @missing = (SELECT GROUP_CONCAT(CONCAT(b.tbl, '(', b.lhs, ')') SEPARATOR ', ')
                FROM basis_lhs AS b
                LEFT JOIN unique_indexes AS k ON k.tbl = b.tbl AND k.cols = b.lhs
                WHERE k.tbl IS NULL);
SELECT 'T2a every basis left side is a PRIMARY KEY or UNIQUE' AS test,
       17 AS expected, @actual AS actual, IFNULL(@missing, '') AS missing,
       IF(@actual = 17 AND @missing IS NULL, 'PASS', 'FAIL') AS result;

-- title -> media_id is NOT in the basis (a book and its film can share a title), so title
-- must not be declared unique either.
SET @actual = (SELECT COUNT(*) FROM unique_indexes WHERE tbl = 'media' AND cols = 'title');
SELECT 'T2b title is not a key (title -> media_id is not an FD)' AS test,
       0 AS expected, @actual AS actual,
       IF(@actual = 0, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T3  No attribute can be dropped from a left side (step 2 of the algorithm).
--     For each composite left side we add rows the schema accepts, then show that every
--     shorter version of each FD is broken while the full FD still holds.
--     If a shorter FD were a real rule, no legal data could break it.
-- ---------------------------------------------------------------------
-- tracks and reviews: muskan (1) gets a second item, The Secret History (1) a second user.
INSERT INTO tracks (user_id, media_id, media_status) VALUES
    (1, 2, 'in_progress'),
    (2, 1, 'dropped');
INSERT INTO reviews (user_id, media_id, user_review) VALUES
    (1, 2, 'Strange and wonderful.'),
    (2, 1, 'Beautiful and unsettling.');

-- tv_episodes and podcast_episodes: a second show and a second podcast, each with an
-- episode 1, so that the episode number alone no longer picks out one title.
INSERT INTO media (media_id, title, release_year, summary) VALUES
    (991, 'Test Show',    2020, 'Test row, removed by ROLLBACK.'),
    (992, 'Test Podcast', 2020, 'Test row, removed by ROLLBACK.');
INSERT INTO tv_shows (media_id, director) VALUES (991, NULL);
INSERT INTO podcasts (media_id, host)     VALUES (992, NULL);
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes)
    VALUES (991, 1, 1, 'Another Pilot', 30.00);
INSERT INTO podcast_episodes (media_id, episode_number, title, duration_minutes)
    VALUES (992, 1, 'Another Episode One', 30.00);

-- T3a tracks: (user_id, media_id) -> media_status
SET @short = (SELECT EXISTS (SELECT 1 FROM tracks a JOIN tracks b ON a.user_id = b.user_id
                             WHERE NOT (a.media_status <=> b.media_status)))
           + (SELECT EXISTS (SELECT 1 FROM tracks a JOIN tracks b ON a.media_id = b.media_id
                             WHERE NOT (a.media_status <=> b.media_status)));
SET @full = (SELECT COUNT(*) FROM tracks a JOIN tracks b
               ON a.user_id = b.user_id AND a.media_id = b.media_id
             WHERE NOT (a.media_status <=> b.media_status));
SELECT 'T3a tracks: user_id and media_id both needed' AS test,
       'shorter: 2 of 2 broken | full: 0' AS expected,
       CONCAT('shorter: ', @short, ' of 2 broken | full: ', @full) AS actual,
       IF(@short = 2 AND @full = 0, 'PASS', 'FAIL') AS result;

-- T3b reviews: (user_id, media_id) -> user_review
SET @short = (SELECT EXISTS (SELECT 1 FROM reviews a JOIN reviews b ON a.user_id = b.user_id
                             WHERE NOT (a.user_review <=> b.user_review)))
           + (SELECT EXISTS (SELECT 1 FROM reviews a JOIN reviews b ON a.media_id = b.media_id
                             WHERE NOT (a.user_review <=> b.user_review)));
SET @full = (SELECT COUNT(*) FROM reviews a JOIN reviews b
               ON a.user_id = b.user_id AND a.media_id = b.media_id
             WHERE NOT (a.user_review <=> b.user_review));
SELECT 'T3b reviews: user_id and media_id both needed' AS test,
       'shorter: 2 of 2 broken | full: 0' AS expected,
       CONCAT('shorter: ', @short, ' of 2 broken | full: ', @full) AS actual,
       IF(@short = 2 AND @full = 0, 'PASS', 'FAIL') AS result;

-- T3c tv_episodes: (media_id, season_number, episode_number) -> title, duration_minutes
--     Each of the 3 shorter left sides is checked against both right sides: 6 shorter FDs.
SET @short =
    -- drop episode_number: (media_id, season_number)
      (SELECT EXISTS (SELECT 1 FROM tv_episodes a JOIN tv_episodes b
                        ON a.media_id = b.media_id AND a.season_number = b.season_number
                      WHERE NOT (a.title <=> b.title)))
    + (SELECT EXISTS (SELECT 1 FROM tv_episodes a JOIN tv_episodes b
                        ON a.media_id = b.media_id AND a.season_number = b.season_number
                      WHERE NOT (a.duration_minutes <=> b.duration_minutes)))
    -- drop season_number: (media_id, episode_number)
    + (SELECT EXISTS (SELECT 1 FROM tv_episodes a JOIN tv_episodes b
                        ON a.media_id = b.media_id AND a.episode_number = b.episode_number
                      WHERE NOT (a.title <=> b.title)))
    + (SELECT EXISTS (SELECT 1 FROM tv_episodes a JOIN tv_episodes b
                        ON a.media_id = b.media_id AND a.episode_number = b.episode_number
                      WHERE NOT (a.duration_minutes <=> b.duration_minutes)))
    -- drop media_id: (season_number, episode_number)
    + (SELECT EXISTS (SELECT 1 FROM tv_episodes a JOIN tv_episodes b
                        ON a.season_number = b.season_number AND a.episode_number = b.episode_number
                      WHERE NOT (a.title <=> b.title)))
    + (SELECT EXISTS (SELECT 1 FROM tv_episodes a JOIN tv_episodes b
                        ON a.season_number = b.season_number AND a.episode_number = b.episode_number
                      WHERE NOT (a.duration_minutes <=> b.duration_minutes)));
SET @full = (SELECT COUNT(*) FROM tv_episodes a JOIN tv_episodes b
               ON a.media_id = b.media_id AND a.season_number = b.season_number
              AND a.episode_number = b.episode_number
             WHERE NOT (a.title <=> b.title)
                OR NOT (a.duration_minutes <=> b.duration_minutes));
SELECT 'T3c tv_episodes: all 3 key columns needed' AS test,
       'shorter: 6 of 6 broken | full: 0' AS expected,
       CONCAT('shorter: ', @short, ' of 6 broken | full: ', @full) AS actual,
       IF(@short = 6 AND @full = 0, 'PASS', 'FAIL') AS result;

-- T3d podcast_episodes: (media_id, episode_number) -> title, duration_minutes
SET @short =
    -- drop episode_number: (media_id)
      (SELECT EXISTS (SELECT 1 FROM podcast_episodes a JOIN podcast_episodes b
                        ON a.media_id = b.media_id
                      WHERE NOT (a.title <=> b.title)))
    + (SELECT EXISTS (SELECT 1 FROM podcast_episodes a JOIN podcast_episodes b
                        ON a.media_id = b.media_id
                      WHERE NOT (a.duration_minutes <=> b.duration_minutes)))
    -- drop media_id: (episode_number)
    + (SELECT EXISTS (SELECT 1 FROM podcast_episodes a JOIN podcast_episodes b
                        ON a.episode_number = b.episode_number
                      WHERE NOT (a.title <=> b.title)))
    + (SELECT EXISTS (SELECT 1 FROM podcast_episodes a JOIN podcast_episodes b
                        ON a.episode_number = b.episode_number
                      WHERE NOT (a.duration_minutes <=> b.duration_minutes)));
SET @full = (SELECT COUNT(*) FROM podcast_episodes a JOIN podcast_episodes b
               ON a.media_id = b.media_id AND a.episode_number = b.episode_number
             WHERE NOT (a.title <=> b.title)
                OR NOT (a.duration_minutes <=> b.duration_minutes));
SELECT 'T3d podcast_episodes: both key columns needed' AS test,
       'shorter: 4 of 4 broken | full: 0' AS expected,
       CONCAT('shorter: ', @short, ' of 4 broken | full: ', @full) AS actual,
       IF(@short = 4 AND @full = 0, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- T4  MySQL rejects a row that would break a basis FD.
--     INSERT IGNORE turns the error into a warning so the script keeps going;
--     GET DIAGNOSTICS then reads the row count and the error number (1062 = duplicate key).
--     Every other column in these rows is valid, so the key is the only reason to reject them.
-- ---------------------------------------------------------------------
INSERT INTO media (media_id, title, release_year, summary)
VALUES (990, 'Test Book', 2020, 'Test row, removed by ROLLBACK.');

-- T4a isbn -> media_id: a second book with The Secret History's ISBN
SET @err = NULL;
INSERT IGNORE INTO books (media_id, author, isbn, page_count)
VALUES (990, 'Test Author', '9781400031702', 100);
GET DIAGNOSTICS @rows = ROW_COUNT;
GET DIAGNOSTICS CONDITION 1 @err = MYSQL_ERRNO;
SELECT 'T4a isbn -> media_id: duplicate ISBN rejected' AS test,
       '0 rows, error 1062' AS expected,
       CONCAT(@rows, ' rows, error ', IFNULL(@err, 'none')) AS actual,
       IF(@rows = 0 AND @err = 1062, 'PASS', 'FAIL') AS result;

-- T4b name -> tag_id: a second tag called 'cozy'
SET @err = NULL;
INSERT IGNORE INTO tag (name) VALUES ('cozy');
GET DIAGNOSTICS @rows = ROW_COUNT;
GET DIAGNOSTICS CONDITION 1 @err = MYSQL_ERRNO;
SELECT 'T4b name -> tag_id: duplicate tag name rejected' AS test,
       '0 rows, error 1062' AS expected,
       CONCAT(@rows, ' rows, error ', IFNULL(@err, 'none')) AS actual,
       IF(@rows = 0 AND @err = 1062, 'PASS', 'FAIL') AS result;

-- T4c (user_id, media_id) -> media_status: a second status for muskan + The Secret History
SET @err = NULL;
INSERT IGNORE INTO tracks (user_id, media_id, media_status) VALUES (1, 1, 'dropped');
GET DIAGNOSTICS @rows = ROW_COUNT;
GET DIAGNOSTICS CONDITION 1 @err = MYSQL_ERRNO;
SELECT 'T4c (user_id, media_id) -> media_status: second status rejected' AS test,
       '0 rows, error 1062' AS expected,
       CONCAT(@rows, ' rows, error ', IFNULL(@err, 'none')) AS actual,
       IF(@rows = 0 AND @err = 1062, 'PASS', 'FAIL') AS result;

-- ---------------------------------------------------------------------
-- Undo everything this file changed.
-- ---------------------------------------------------------------------
ROLLBACK;
DROP TEMPORARY TABLE IF EXISTS basis_lhs, unique_indexes;

SET @left = (SELECT COUNT(*) FROM media WHERE media_id IN (990, 991, 992))
          + (SELECT COUNT(*) FROM tracks  WHERE (user_id, media_id) IN ((1, 2), (2, 1)))
          + (SELECT COUNT(*) FROM reviews WHERE (user_id, media_id) IN ((1, 2), (2, 1)));
SELECT 'T5 data unchanged after ROLLBACK' AS test, 0 AS expected, @left AS actual,
       IF(@left = 0, 'PASS', 'FAIL') AS result;
