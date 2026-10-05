-- alter_table.sql
-- ALTER TABLE demo: add a column to an existing table, fill it with data, then remove it again.
-- Safe to re-run: the last step puts the table back exactly as it was.
-- Run it after seed_data.sql.

USE media_tracker;

-- 1) Before: reviews has three columns
DESCRIBE reviews;

-- 2) Add a nullable star rating (existing reviews get NULL) and limit it to 1-5
ALTER TABLE reviews
    ADD COLUMN rating TINYINT NULL AFTER user_review;

ALTER TABLE reviews
    ADD CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5);

DESCRIBE reviews;
SELECT user_id, media_id, rating FROM reviews;

-- 3) Fill in the new column for muskan's review of The Secret History (user 1, media 1)
UPDATE reviews
SET rating = 5
WHERE user_id = 1 AND media_id = 1;

SELECT u.username, m.title, r.rating, r.user_review
FROM reviews r
JOIN users u ON u.user_id = r.user_id
JOIN media m ON m.media_id = r.media_id;

-- 4) Undo: drop the constraint and the column so the schema matches schema_activity.sql again
ALTER TABLE reviews
    DROP CHECK chk_rating,
    DROP COLUMN rating;

DESCRIBE reviews;
