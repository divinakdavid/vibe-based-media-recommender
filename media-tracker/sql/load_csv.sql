
USE media_tracker;

-- ---------------------------------------------------------------------
-- media (the parent rows must be loaded before the child rows)
-- media.csv has no media_type column: the type comes from which child CSV a row appears in.
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '../data/media.csv'
IGNORE INTO TABLE media
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(media_id, title, @release_year, @summary)
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
FROM media_with_type m
JOIN has_tag ht ON ht.media_id = m.media_id
JOIN tag t      ON t.tag_id = ht.tag_id
WHERE m.media_id >= 101
ORDER BY m.media_id, t.name;

-- Child rows, to confirm nothing was cut off (e.g. 103.50 minutes, 3.25 minutes) and blanks are NULL
SELECT media_id, author, isbn, page_count FROM books  WHERE media_id >= 101;
SELECT media_id, director, duration_minutes FROM movies WHERE media_id >= 101;
SELECT media_id, artist, duration_minutes   FROM songs  WHERE media_id >= 101;
