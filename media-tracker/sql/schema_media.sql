-- schema_media.sql
-- Tables about media: media (parent), its five ISA child tables, tag and has_tag.
--
-- ISA: each child table uses media_id as its primary key AND as a foreign key to media,
-- so a book "is a" media item. media.media_type records which child table a row belongs to.

USE media_tracker;

-- ---------------------------------------------------------------------
-- MEDIA (parent)
-- ---------------------------------------------------------------------
CREATE TABLE media (
    media_id      INT           AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(255)  NOT NULL,
    release_year  INT,
    summary       TEXT,
    media_type    VARCHAR(10)   NOT NULL         -- book | tv_show | movie | podcast | song
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
);

CREATE TABLE tv_shows (
    media_id       INT           PRIMARY KEY,
    director       VARCHAR(255),
    episode_count  INT,
    season_count   INT,
    FOREIGN KEY (media_id) REFERENCES media (media_id)
);

CREATE TABLE movies (
    media_id          INT           PRIMARY KEY,
    director          VARCHAR(255),
    duration_minutes  DECIMAL(5,2),              -- decimal minutes: 103.50 = 1 h 43 min 30 s
    FOREIGN KEY (media_id) REFERENCES media (media_id)
);

CREATE TABLE podcasts (
    media_id       INT  PRIMARY KEY,
    episode_count  INT,
    FOREIGN KEY (media_id) REFERENCES media (media_id)
);

CREATE TABLE songs (
    media_id          INT           PRIMARY KEY,
    artist            VARCHAR(255)  NOT NULL,
    duration_minutes  DECIMAL(5,2),              -- decimal minutes: 3.50 = 3 min 30 s (NOT 3:50)
    FOREIGN KEY (media_id) REFERENCES media (media_id)
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
    FOREIGN KEY (media_id) REFERENCES media (media_id),
    FOREIGN KEY (tag_id)   REFERENCES tag (tag_id)
);
