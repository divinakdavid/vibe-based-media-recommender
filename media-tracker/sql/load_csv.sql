-- load_csv.sql
-- Loads new media from the CSV files in ../data into the existing tables.
-- Run it AFTER seed_data.sql (it needs the tags that the seed data creates).
-- Safe to re-run: IGNORE skips rows that were already loaded. The loaded rows are kept
-- (media_id 101-105), so they appear in later queries.
--
-- SETUP (LOAD DATA LOCAL INFILE is switched off by default, on the server AND the client):
--   Command line: start the client from the sql/ folder so '../data' resolves:
--       mysql --local-infile=1 -u root -p
--       mysql> SET GLOBAL local_infile = 1;
--       mysql> SOURCE load_csv.sql;
--   MySQL Workbench: Database > Manage Connections > your connection > Advanced tab >
--       "Others" box: add   OPT_LOCAL_INFILE=1   then reconnect and run   SET GLOBAL local_infile = 1;
--       Workbench cannot resolve '../data', so replace each path below with the full path
--       to the CSV file (forward slashes, e.g. 'C:/project/media-tracker/data/media.csv').
--
-- How blanks are handled: an empty CSV field would load as '' (or 0 for a number), which is
-- data loss. Reading each optional column into a variable and applying NULLIF(@x, '') turns
-- a blank into NULL, which is what "unknown" means in the schema.
-- Decimal fields such as 103.5 load without truncation because duration_minutes is DECIMAL(5,2).

USE media_tracker;

-- ---------------------------------------------------------------------
-- media (the parent rows must be loaded before the child rows)
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '../data/media.csv'
IGNORE INTO TABLE media
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, title, @release_year, @summary, media_type)
SET release_year = NULLIF(@release_year, ''),
    summary      = NULLIF(@summary, '');
SHOW WARNINGS;

-- ---------------------------------------------------------------------
-- media children
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- has_tag (links the new media to the existing tags)
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '../data/has_tag.csv'
IGNORE INTO TABLE has_tag
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, tag_id);
SHOW WARNINGS;

-- ---------------------------------------------------------------------
-- CHECK: the loaded media and their vibes (one row per tag)
-- ---------------------------------------------------------------------
SELECT m.media_id, m.title, m.release_year, m.media_type, t.name AS vibe
FROM media m
JOIN has_tag ht ON ht.media_id = m.media_id
JOIN tag t      ON t.tag_id = ht.tag_id
WHERE m.media_id >= 101
ORDER BY m.media_id, t.name;

-- Child rows, to confirm nothing was cut off (e.g. 103.50 minutes, 3.25 minutes) and blanks are NULL
SELECT media_id, author, isbn, page_count FROM books  WHERE media_id >= 101;
SELECT media_id, director, duration_minutes FROM movies WHERE media_id >= 101;
SELECT media_id, artist, duration_minutes   FROM songs  WHERE media_id >= 101;
