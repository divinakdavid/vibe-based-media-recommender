-- alter_table.sql
-- ALTER TABLE demo: add a column to an existing table, give it a CHECK, fill it in for
-- rows that already exist, then remove it again.
-- Run after seed_data.sql.
--
-- ALTER TABLE commits straight away in MySQL and cannot be rolled back, so this script
-- cleans up with a second ALTER instead of a ROLLBACK. It leaves the schema as it found it.
-- If it stops halfway, run PART 4 by hand before running it again.
--
-- This is a demo only. A column we want to keep goes into the CREATE TABLE in the
-- schema files, followed by a rebuild (see the README workflow).

USE media_tracker;

-- =====================================================================
-- PART 1: add the column
-- =====================================================================
-- A star rating on each review. It has to allow NULL (or have a DEFAULT) because
-- reviews already has rows, and they get NULL the moment the column appears.
ALTER TABLE reviews
    ADD COLUMN rating TINYINT NULL AFTER user_review;

ALTER TABLE reviews
    ADD CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5);

DESCRIBE reviews;
SELECT user_id, media_id, rating FROM reviews;      -- existing rows: rating is NULL

-- =====================================================================
-- PART 2: add data to the new column
-- =====================================================================
UPDATE reviews
SET rating = 5
WHERE user_id  = (SELECT user_id  FROM users WHERE username = 'muskan')
  AND media_id = (SELECT media_id FROM media WHERE title = 'The Secret History');

SELECT u.username, m.title, r.rating, r.user_review
FROM reviews r
JOIN users u ON u.user_id = r.user_id
JOIN media m ON m.media_id = r.media_id;

-- =====================================================================
-- PART 3: the new CHECK is live (this UPDATE is rejected with error 3819)
-- =====================================================================
-- Uncomment to see it fail. Left commented so SOURCE doesn't stop here.
-- UPDATE reviews SET rating = 6;

-- =====================================================================
-- PART 4: undo
-- =====================================================================
ALTER TABLE reviews
    DROP CHECK chk_rating,
    DROP COLUMN rating;

DESCRIBE reviews;
