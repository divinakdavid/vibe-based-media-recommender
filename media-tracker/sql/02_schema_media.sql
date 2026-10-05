-- 02_schema_media.sql                                      
-- Tables about MEDIA: media (parent), its ISA children, tag, has_tag.

USE media_tracker;

-- ---------------------------------------------------------------------
-- MEDIA (parent)
-- UNIQUE (media_id, media_type) lets each child table prove it matches the
-- parent's media_type (see the foreign keys below).
-- ---------------------------------------------------------------------
CREATE TABLE media (
    media_id      INT          AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    release_year  INT,
    summary       TEXT,
    media_type    VARCHAR(10)  NOT NULL,
    UNIQUE (media_id, media_type)
);

-- ---------------------------------------------------------------------
-- ISA children. Each child uses media_id as its primary key AND as a foreign
-- key to media, so a book "is a" media item.
--
-- media_type in a child is a STORED GENERATED column holding a constant
-- ('book', 'movie', ...). Together with the composite foreign key, MySQL
-- guarantees a row in books can only point at a media row whose media_type is
-- 'book' (same for the other children). So a movie can never be put in books.
-- You never insert media_type into a child table; MySQL fills it in.
-- ---------------------------------------------------------------------
CREATE TABLE books (
    media_id    INT PRIMARY KEY,
    media_type  VARCHAR(10) AS ('book') STORED NOT NULL,
    author      VARCHAR(255) NOT NULL,
    isbn        VARCHAR(13)  UNIQUE,              
    page_count  INT,
    FOREIGN KEY (media_id, media_type) REFERENCES media(media_id, media_type) ON DELETE CASCADE
);

CREATE TABLE tv_shows (
    media_id       INT PRIMARY KEY,
    media_type     VARCHAR(10) AS ('tv_show') STORED NOT NULL,
    director       VARCHAR(255),
    episode_count  INT,
    season_count   INT,
    FOREIGN KEY (media_id, media_type) REFERENCES media(media_id, media_type) ON DELETE CASCADE
);

CREATE TABLE movies (
    media_id          INT PRIMARY KEY,
    media_type        VARCHAR(10) AS ('movie') STORED NOT NULL,
    director          VARCHAR(255),
    duration_minutes  INT,
    FOREIGN KEY (media_id, media_type) REFERENCES media(media_id, media_type) ON DELETE CASCADE
);

CREATE TABLE podcasts (
    media_id       INT PRIMARY KEY,
    media_type     VARCHAR(10) AS ('podcast') STORED NOT NULL,
    episode_count  INT,
    FOREIGN KEY (media_id, media_type) REFERENCES media(media_id, media_type) ON DELETE CASCADE
);

CREATE TABLE songs (
    media_id          INT PRIMARY KEY,
    media_type        VARCHAR(10) AS ('song') STORED NOT NULL,
    artist            VARCHAR(255) NOT NULL,
    duration_minutes  DECIMAL(5,2),               -- decimal minutes: 3.50 = 3 min 30 sec (NOT 3:50)
    FOREIGN KEY (media_id, media_type) REFERENCES media(media_id, media_type) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- TAG and HAS TAG  (Media M:N Tag)
-- ---------------------------------------------------------------------
CREATE TABLE tag (
    tag_id  INT         AUTO_INCREMENT PRIMARY KEY,
    name    VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE has_tag (
    media_id  INT,
    tag_id    INT,
    PRIMARY KEY (media_id, tag_id),
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)   REFERENCES tag(tag_id)     ON DELETE CASCADE
);
