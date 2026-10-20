-- =====================================================================
-- Run AFTER the database is built (run_all.sql), from media-tracker/sql:
--     mysql -u root -p -t < normalization_tests.sql
-- Everything runs inside a transaction and is rolled back at the end,
-- so the sample data is unchanged afterwards.
--
-- Success criterion: every test prints  result = 'PASS'.
-- =====================================================================

USE media_tracker;

-- Helper for Test 8. Created before the transaction because creating a
-- procedure ends (commits) any open transaction in MySQL.
DROP PROCEDURE IF EXISTS try_duplicate_email;
DELIMITER //
CREATE PROCEDURE try_duplicate_email()
BEGIN
    DECLARE blocked INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET blocked = 1;
    INSERT INTO users (username, email, password_hash)
    VALUES ('grace2', 'grace@example.com', '$2b$12$placeholderhashgrace22222');
    SELECT 'T8 DB blocks an FD violation (duplicate email)' AS test,
           IF(blocked = 1, 'PASS', 'FAIL') AS result;
END //
DELIMITER ;

START TRANSACTION;

-- Extra sample data for the tests: two more reviews of The Secret History
-- (media 1 already has 3 vibes and 1 review).
INSERT INTO reviews VALUES (2, 1, 'Beautiful and unsettling.'),
                           (3, 1, 'Made me want to learn Greek.');

-- =====================================================================
-- PART A: 4NF — why vibes and reviews live in separate tables
-- =====================================================================
-- Vibes and reviews are two INDEPENDENT multivalued facts about a media
-- item:  media_id ->> tag_id   and   media_id ->> user_id (reviewer).
-- If they were stored in one table, every vibe would have to be paired
-- with every reviewer (a cross product). We build that bad table here
-- only to compare against.

CREATE TEMPORARY TABLE bad_media_facts AS
SELECT ht.media_id, ht.tag_id, r.user_id
FROM has_tag ht
JOIN reviews r ON r.media_id = ht.media_id;

-- Test 1: the combined table repeats data; our 4NF tables do not.
--   Media 1 has 3 vibes and 3 reviewers.
--   Bad design: 3 x 3 = 9 rows.   4NF design: 3 + 3 = 6 rows.
SET @bad_rows = (SELECT COUNT(*) FROM bad_media_facts WHERE media_id = 1);
SET @our_rows = (SELECT COUNT(*) FROM has_tag WHERE media_id = 1)
              + (SELECT COUNT(*) FROM reviews WHERE media_id = 1);
SELECT 'T1 redundancy: combined table vs 4NF tables' AS test,
       @bad_rows AS bad_rows,
       @our_rows AS our_rows,
       IF(@bad_rows = 9 AND @our_rows = 6, 'PASS', 'FAIL') AS result;

-- Test 2: INSERTION anomaly avoided.
--   Adding one new vibe ('cozy') to media 1 is ONE row in has_tag.
--   In the bad table it would need one row per reviewer (3 rows).
INSERT INTO has_tag VALUES (1, 3);
SELECT 'T2 insertion: adding a vibe = 1 row' AS test,
       ROW_COUNT() AS rows_inserted,
       (SELECT COUNT(*) FROM reviews WHERE media_id = 1) AS rows_bad_design_needs,
       IF((SELECT COUNT(*) FROM has_tag WHERE media_id = 1 AND tag_id = 3) = 1,
          'PASS', 'FAIL') AS result;

-- Test 3: DELETION anomaly avoided.
--   Deleting every review of a media item must NOT delete its vibes.
--   (review_tags rows go first: the foreign key has no ON DELETE CASCADE.)
DELETE FROM review_tags WHERE media_id = 1;
DELETE FROM reviews WHERE media_id = 1;
SELECT 'T3 deletion: vibes survive when reviews are removed' AS test,
       (SELECT COUNT(*) FROM reviews WHERE media_id = 1) AS reviews_left,
       (SELECT COUNT(*) FROM has_tag WHERE media_id = 1) AS vibes_left,
       IF((SELECT COUNT(*) FROM has_tag WHERE media_id = 1) = 4,
          'PASS', 'FAIL') AS result;

-- Test 4: Deleting a vibe from one media item must NOT delete the vibe
--   itself (the tag row) or remove it from other media.
DELETE FROM has_tag WHERE media_id = 1 AND tag_id = 4;   -- melancholy
SELECT 'T4 deletion: tag still exists for other media' AS test,
       (SELECT COUNT(*) FROM tag WHERE tag_id = 4) AS tag_rows,
       (SELECT COUNT(*) FROM has_tag WHERE tag_id = 4) AS other_media_with_tag,
       IF((SELECT COUNT(*) FROM tag WHERE tag_id = 4) = 1
          AND (SELECT COUNT(*) FROM has_tag WHERE tag_id = 4) > 0,
          'PASS', 'FAIL') AS result;

-- Test 5: UPDATE anomaly avoided.
--   Renaming a vibe changes exactly ONE row, and every media item
--   tagged with it sees the new name.
UPDATE tag SET name = 'sad girl autumn' WHERE tag_id = 4;
SELECT 'T5 update: rename a vibe = 1 row changed' AS test,
       ROW_COUNT() AS rows_changed,
       (SELECT COUNT(*) FROM has_tag ht JOIN tag t ON t.tag_id = ht.tag_id
        WHERE t.name = 'melancholy') AS old_name_left,
       IF((SELECT COUNT(*) FROM has_tag ht JOIN tag t ON t.tag_id = ht.tag_id
           WHERE t.name = 'melancholy') = 0,
          'PASS', 'FAIL') AS result;

-- =====================================================================
-- PART B: Multi-vibe matching returns no duplicate rows
-- =====================================================================
-- Test 6: Media that have BOTH 'dark academia' AND 'sad girl autumn'.
--   Each media item must appear exactly once.
SELECT m.media_id, m.title
FROM media m
JOIN has_tag ht ON ht.media_id = m.media_id
JOIN tag t      ON t.tag_id = ht.tag_id
WHERE t.name IN ('dark academia', 'sad girl autumn')
GROUP BY m.media_id, m.title
HAVING COUNT(DISTINCT t.name) = 2
ORDER BY m.title;

SELECT 'T6 multi-vibe match has no duplicates' AS test,
       COUNT(*) AS rows_returned,
       COUNT(DISTINCT media_id) AS distinct_media,
       IF(COUNT(*) = COUNT(DISTINCT media_id), 'PASS', 'FAIL') AS result
FROM (
    SELECT ht.media_id
    FROM has_tag ht JOIN tag t ON t.tag_id = ht.tag_id
    WHERE t.name IN ('dark academia', 'sad girl autumn')
    GROUP BY ht.media_id
    HAVING COUNT(DISTINCT t.name) = 2
) AS matches;

-- =====================================================================
-- PART C: Every functional dependency holds (no redundancy in the data)
-- Each query looks for two rows that agree on the left side of an FD
-- but disagree on the right side. Zero such rows = the FD holds.
-- =====================================================================
SELECT 'T7 FDs hold in the data' AS test,
       (SELECT COUNT(*) FROM (SELECT username FROM users
            GROUP BY username HAVING COUNT(DISTINCT user_id) > 1) x)   -- username -> user_id
     + (SELECT COUNT(*) FROM (SELECT email FROM users
            GROUP BY email HAVING COUNT(DISTINCT user_id) > 1) x)      -- email -> user_id
     + (SELECT COUNT(*) FROM (SELECT isbn FROM books WHERE isbn IS NOT NULL
            GROUP BY isbn HAVING COUNT(DISTINCT media_id) > 1) x)      -- isbn -> media_id
     + (SELECT COUNT(*) FROM (SELECT name FROM tag
            GROUP BY name HAVING COUNT(DISTINCT tag_id) > 1) x)        -- name -> tag_id
       AS violations,
       IF((SELECT COUNT(*) FROM (SELECT username FROM users
              GROUP BY username HAVING COUNT(DISTINCT user_id) > 1) x)
        + (SELECT COUNT(*) FROM (SELECT email FROM users
              GROUP BY email HAVING COUNT(DISTINCT user_id) > 1) x)
        + (SELECT COUNT(*) FROM (SELECT isbn FROM books WHERE isbn IS NOT NULL
              GROUP BY isbn HAVING COUNT(DISTINCT media_id) > 1) x)
        + (SELECT COUNT(*) FROM (SELECT name FROM tag
              GROUP BY name HAVING COUNT(DISTINCT tag_id) > 1) x) = 0,
          'PASS', 'FAIL') AS result;

-- Test 8: The database itself rejects data that would break an FD.
--   A second user with an existing email would violate email -> user_id.
--   The UNIQUE constraint must block it.
CALL try_duplicate_email();

-- Put everything back the way it was.
ROLLBACK;
DROP TEMPORARY TABLE IF EXISTS bad_media_facts;
DROP PROCEDURE IF EXISTS try_duplicate_email;
