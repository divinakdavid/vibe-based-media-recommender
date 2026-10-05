-- load_csv.sql
-- Loads extra media from the CSV files in ../data/ with LOAD DATA LOCAL INFILE.
-- Run after seed_data.sql (has_tag.csv uses the seed tag ids 1..4).
--

USE media_tracker;

-- ---------------- media (parent first) ----------------
-- An empty cell arrives as '' and not NULL, so nullable columns are read into a
-- @variable and converted with NULLIF.
LOAD DATA LOCAL INFILE '../data/media.csv'
IGNORE INTO TABLE media
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, title, @release_year, @summary, media_type)
SET release_year = NULLIF(@release_year, ''),
    summary      = NULLIF(@summary, '');
SHOW WARNINGS;

-- ---------------- media children ----------------
-- media_type is left out of every column list: it is generated (see schema_media.sql).
LOAD DATA LOCAL INFILE '../data/books.csv'
IGNORE INTO TABLE books
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, author, @isbn, @page_count)
SET isbn       = NULLIF(@isbn, ''),
    page_count = NULLIF(@page_count, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE '../data/movies.csv'
IGNORE INTO TABLE movies
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, @director, @duration_minutes)
SET director         = NULLIF(@director, ''),
    duration_minutes = NULLIF(@duration_minutes, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE '../data/songs.csv'
IGNORE INTO TABLE songs
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, artist, @duration_minutes)
SET duration_minutes = NULLIF(@duration_minutes, '');
SHOW WARNINGS;

-- ---------------- has_tag ----------------
LOAD DATA LOCAL INFILE '../data/has_tag.csv'
IGNORE INTO TABLE has_tag
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, tag_id);
SHOW WARNINGS;

-- What was loaded
SELECT m.media_id, m.title, m.release_year, m.media_type,
       GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR ', ') AS vibes
FROM media m
LEFT JOIN has_tag ht ON ht.media_id = m.media_id
LEFT JOIN tag t      ON t.tag_id = ht.tag_id
WHERE m.media_id >= 101
GROUP BY m.media_id, m.title, m.release_year, m.media_type
ORDER BY m.media_id;
