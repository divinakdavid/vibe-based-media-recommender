-- schema_media.sql
-- Tables about media: media (parent), its five ISA child tables, two weak entity sets for
-- episodes, tag and has_tag.
--
-- ISA: each child table uses media_id as its primary key AND as a foreign key to media,
-- so a book "is a" media item. Each media row is meant to be in exactly one child table.
-- MySQL cannot declare that rule, so integrity_audit.sql checks it.
-- The type of an item is not stored: it is whichever child table holds the row
-- (see the media_with_type view at the end of the ISA section).
--
-- Foreign keys: ON DELETE CASCADE / RESTRICT and ON UPDATE RESTRICT are explained in
-- schema_users_groups.sql and docs/referential_integrity.md.

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
    FOREIGN KEY (media_id) REFERENCES media (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

CREATE TABLE tv_shows (
    media_id       INT           PRIMARY KEY,
    director       VARCHAR(255),
    FOREIGN KEY (media_id) REFERENCES media (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

CREATE TABLE movies (
    media_id          INT           PRIMARY KEY,
    director          VARCHAR(255),
    duration_minutes  DECIMAL(5,2),              -- decimal minutes: 103.50 = 1 h 43 min 30 s
    FOREIGN KEY (media_id) REFERENCES media (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

-- podcasts has no attributes of its own. It is still its own subset because podcast_episodes
-- (below) depends on it, which is what distinguishes it from the other media types.
CREATE TABLE podcasts (
    media_id  INT  PRIMARY KEY,
    FOREIGN KEY (media_id) REFERENCES media (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

CREATE TABLE songs (
    media_id          INT           PRIMARY KEY,
    artist            VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),              -- decimal minutes: 3.50 = 3 min 30 s (NOT 3:50)
    FOREIGN KEY (media_id) REFERENCES media (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

-- ---------------------------------------------------------------------
-- WEAK ENTITY SETS: episodes
-- An episode cannot be identified without its show, so part of its primary key is the owner's
-- key (media_id) and the rest is its own discriminator (season/episode number). The
-- identifying relationship is the foreign key; it needs no table of its own.
-- ON DELETE CASCADE: an episode cannot outlive its show.
-- These replace the old flat episode_count / season_count columns, which were derivable.
-- ---------------------------------------------------------------------
CREATE TABLE tv_episodes (
    media_id          INT,
    season_number     INT,
    episode_number    INT,
    title             VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),
    PRIMARY KEY (media_id, season_number, episode_number),
    FOREIGN KEY (media_id) REFERENCES tv_shows (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

CREATE TABLE podcast_episodes (
    media_id          INT,
    episode_number    INT,
    title             VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),
    PRIMARY KEY (media_id, episode_number),
    FOREIGN KEY (media_id) REFERENCES podcasts (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT
);

-- ---------------------------------------------------------------------
-- MEDIA_WITH_TYPE (a view, so it stores no data)
-- The type of a media item is derived from which child table holds its row, so there is no
-- media_type column to keep in sync. Use this view wherever a query needs the type.
-- ---------------------------------------------------------------------
CREATE VIEW media_with_type AS
SELECT m.media_id, m.title, m.release_year, m.summary,
       CASE
           WHEN b.media_id  IS NOT NULL THEN 'book'
           WHEN tv.media_id IS NOT NULL THEN 'tv_show'
           WHEN mo.media_id IS NOT NULL THEN 'movie'
           WHEN p.media_id  IS NOT NULL THEN 'podcast'
           WHEN s.media_id  IS NOT NULL THEN 'song'
       END AS media_type
FROM media m
LEFT JOIN books    b  ON b.media_id  = m.media_id
LEFT JOIN tv_shows tv ON tv.media_id = m.media_id
LEFT JOIN movies   mo ON mo.media_id = m.media_id
LEFT JOIN podcasts p  ON p.media_id  = m.media_id
LEFT JOIN songs    s  ON s.media_id  = m.media_id;

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
    FOREIGN KEY (media_id) REFERENCES media (media_id)
        ON DELETE CASCADE  ON UPDATE RESTRICT,
    FOREIGN KEY (tag_id)   REFERENCES tag (tag_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);