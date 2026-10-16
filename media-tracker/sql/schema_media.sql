
USE media_tracker;

-- ---------------------------------------------------------------------
-- MEDIA (parent)
-- ---------------------------------------------------------------------
CREATE TABLE media (
    media_id      INT           AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(255)  NOT NULL,
    release_year  INT,
    summary       TEXT
);

-- ---------------------------------------------------------------------
-- ISA children
-- ---------------------------------------------------------------------
CREATE TABLE books (
    media_id    INT           PRIMARY KEY,
    author      VARCHAR(255)  NOT NULL,
    isbn        VARCHAR(13)   UNIQUE,            -- candidate key (not the PK because it can be NULL)
    page_count  INT,
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE tv_shows (
    media_id  INT           PRIMARY KEY,
    director  VARCHAR(255),
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE movies (
    media_id          INT           PRIMARY KEY,
    director          VARCHAR(255),
    duration_minutes  DECIMAL(5,2),              -- decimal minutes: 103.50 = 1 h 43 min 30 s
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE podcasts (
    media_id  INT  PRIMARY KEY,
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE songs (
    media_id          INT           PRIMARY KEY,
    artist            VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),              -- decimal minutes: 3.50 = 3 min 30 s (NOT 3:50)
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- WEAK ENTITIES: episodes (identifying relationship "Has episode")
-- ---------------------------------------------------------------------
CREATE TABLE tv_episodes (
    media_id          INT,                       -- owner: the TV show
    season_number     INT,                       -- partial key
    episode_number    INT,                       -- partial key
    title             VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),
    PRIMARY KEY (media_id, season_number, episode_number),
    FOREIGN KEY (media_id) REFERENCES tv_shows (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE podcast_episodes (
    media_id          INT,                       -- owner: the podcast
    episode_number    INT,                       -- partial key
    title             VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),
    PRIMARY KEY (media_id, episode_number),
    FOREIGN KEY (media_id) REFERENCES podcasts (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- TAG and HAS_TAG  (Media M:N Tag). A tag is a "vibe" such as 'cozy'.
-- ---------------------------------------------------------------------
CREATE TABLE tag (
    tag_id  INT          AUTO_INCREMENT PRIMARY KEY,
    name    VARCHAR(50)  NOT NULL UNIQUE
);

CREATE TABLE has_tag (
    media_id  INT,
    tag_id    INT,
    PRIMARY KEY (media_id, tag_id),
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (tag_id)   REFERENCES tag (tag_id)     ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- MEDIA_WITH_TYPE: every media row plus its type, worked out from its child table.
-- A row with no child row (not yet completed) shows NULL.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW media_with_type AS
SELECT m.media_id, m.title, m.release_year, m.summary,
       CASE
           WHEN b.media_id IS NOT NULL THEN 'book'
           WHEN t.media_id IS NOT NULL THEN 'tv_show'
           WHEN v.media_id IS NOT NULL THEN 'movie'
           WHEN p.media_id IS NOT NULL THEN 'podcast'
           WHEN s.media_id IS NOT NULL THEN 'song'
       END AS media_type
FROM media m
LEFT JOIN books    b ON b.media_id = m.media_id
LEFT JOIN tv_shows t ON t.media_id = m.media_id
LEFT JOIN movies   v ON v.media_id = m.media_id
LEFT JOIN podcasts p ON p.media_id = m.media_id
LEFT JOIN songs    s ON s.media_id = m.media_id;
