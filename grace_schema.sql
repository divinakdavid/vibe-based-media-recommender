

CREATE DATABASE IF NOT EXISTS media_tracker;
USE media_tracker;

-- Drop in any order while rebuilding, then turn FK checks back on.
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS recommends, member_of, user_groups, friends, review_tags,
    reviews, tracks, has_tag, tag, songs, podcasts, movies, tv_shows, books,
    media, users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        INT          AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL          -- never store the plain password
);

-- ---------------------------------------------------------------------
-- MEDIA (parent) and the ISA children
-- Each child uses media_id as its primary key AND as a foreign key to
-- media, so a book "is a" media item.
-- ---------------------------------------------------------------------
CREATE TABLE media (
    media_id      INT          AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    release_year  INT,
    summary       TEXT,
    media_type    VARCHAR(10)  NOT NULL
);

CREATE TABLE books (
    media_id    INT PRIMARY KEY,
    author      VARCHAR(255) NOT NULL,
    isbn        VARCHAR(13)  UNIQUE,              -- candidate key, not the PK
    page_count  INT,
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
);

CREATE TABLE tv_shows (
    media_id       INT PRIMARY KEY,
    director       VARCHAR(255),
    episode_count  INT,
    season_count   INT,
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
);

CREATE TABLE movies (
    media_id          INT PRIMARY KEY,
    director          VARCHAR(255),
    duration_minutes  INT,
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
);

CREATE TABLE podcasts (
    media_id       INT PRIMARY KEY,
    episode_count  INT,
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
);

CREATE TABLE songs (
    media_id          INT PRIMARY KEY,
    artist            VARCHAR(255) NOT NULL,
    duration_minutes  DECIMAL(5,2),               -- e.g. 3.45 for a short song
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
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

-- ---------------------------------------------------------------------
-- TRACKS  (Users M:N Media, with media_status)
-- ---------------------------------------------------------------------
CREATE TABLE tracks (
    user_id       INT,
    media_id      INT,
    media_status  VARCHAR(15) NOT NULL,
    PRIMARY KEY (user_id, media_id),
    FOREIGN KEY (user_id)  REFERENCES users(user_id)  ON DELETE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- REVIEWS  (Users M:N Media, with user_review)
-- REVIEW_TAGS: review_tags was multivalued on the ERD, so it gets its own
-- table to stay in BCNF. It reuses the same tag list as media.
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    user_id      INT,
    media_id     INT,
    user_review  TEXT NOT NULL,
    PRIMARY KEY (user_id, media_id),
    FOREIGN KEY (user_id)  REFERENCES users(user_id)  ON DELETE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media(media_id) ON DELETE CASCADE
);

CREATE TABLE review_tags (
    user_id   INT,
    media_id  INT,
    tag_id    INT,
    PRIMARY KEY (user_id, media_id, tag_id),
    FOREIGN KEY (user_id, media_id) REFERENCES reviews(user_id, media_id)
        ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tag(tag_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- FRIENDS  (Users M:N Users: follower -> followed)
-- ---------------------------------------------------------------------
CREATE TABLE friends (
    follower_id  INT,
    followed_id  INT,
    PRIMARY KEY (follower_id, followed_id),
    FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (followed_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- GROUPS  (called user_groups because GROUPS is a reserved word in MySQL)
-- CREATES is one-to-many (each group has one creator), so it becomes the
-- creator_id column instead of its own table.
-- ---------------------------------------------------------------------
CREATE TABLE user_groups (
    group_id    INT          AUTO_INCREMENT PRIMARY KEY,
    group_name  VARCHAR(100) NOT NULL,
    creator_id  INT          NOT NULL,
    FOREIGN KEY (creator_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- MEMBER OF  (Users M:N Groups)
CREATE TABLE member_of (
    group_id  INT,
    user_id   INT,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES user_groups(group_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users(user_id)        ON DELETE CASCADE
);

-- RECOMMENDS  (Groups M:N Media)
CREATE TABLE recommends (
    group_id  INT,
    media_id  INT,
    PRIMARY KEY (group_id, media_id),
    FOREIGN KEY (group_id) REFERENCES user_groups(group_id) ON DELETE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media(media_id)       ON DELETE CASCADE
);

-- =====================================================================
-- CHECK CONSTRAINTS (Grace) — added separately with ALTER TABLE
-- =====================================================================
ALTER TABLE media    ADD CONSTRAINT chk_media_type
    CHECK (media_type IN ('book','tv_show','movie','podcast','song'));
ALTER TABLE media    ADD CONSTRAINT chk_release_year
    CHECK (release_year BETWEEN 1400 AND 2100);
ALTER TABLE books    ADD CONSTRAINT chk_page_count       CHECK (page_count > 0);
ALTER TABLE tv_shows ADD CONSTRAINT chk_tv_counts
    CHECK (season_count > 0 AND episode_count >= season_count);
ALTER TABLE movies   ADD CONSTRAINT chk_movie_duration   CHECK (duration_minutes > 0);
ALTER TABLE podcasts ADD CONSTRAINT chk_podcast_episodes CHECK (episode_count > 0);
ALTER TABLE songs    ADD CONSTRAINT chk_song_duration    CHECK (duration_minutes > 0);
ALTER TABLE users    ADD CONSTRAINT chk_email            CHECK (email LIKE '%_@_%._%');
ALTER TABLE tracks   ADD CONSTRAINT chk_media_status
    CHECK (media_status IN ('want_to_consume','in_progress','finished','dropped'));

-- No following yourself. MySQL won't allow a CHECK on a column that has
-- ON DELETE CASCADE, so this rule is enforced with triggers instead.
DROP TRIGGER IF EXISTS no_self_follow_insert;
DROP TRIGGER IF EXISTS no_self_follow_update;
DELIMITER //
CREATE TRIGGER no_self_follow_insert BEFORE INSERT ON friends
FOR EACH ROW
BEGIN
    IF NEW.follower_id = NEW.followed_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A user cannot follow themselves';
    END IF;
END //
CREATE TRIGGER no_self_follow_update BEFORE UPDATE ON friends
FOR EACH ROW
BEGIN
    IF NEW.follower_id = NEW.followed_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A user cannot follow themselves';
    END IF;
END //
DELIMITER ;

-- =====================================================================
-- SAMPLE DATA
-- =====================================================================
INSERT INTO users (username, email, password_hash) VALUES
  ('muskan', 'muskan@example.com', 'hash1'),
  ('divina', 'divina@example.com', 'hash2'),
  ('grace',  'grace@example.com',  'hash3');

INSERT INTO media (title, release_year, summary, media_type) VALUES
  ('The Secret History', 1992, 'Classics students and a murder.',  'book'),    -- 1
  ('Twin Peaks',         1990, 'A strange small-town mystery.',    'tv_show'), -- 2
  ('Knives Out',         2019, 'A detective untangles a family.',  'movie'),   -- 3
  ('Serial',             2014, 'Investigative true crime.',        'podcast'), -- 4
  ('Moonlight Sonata',   1801, 'Piano sonata, first movement.',    'song'),    -- 5
  ('Dead Poets Society', 1989, 'An English teacher inspires a boarding school.', 'movie'), -- 6
  ('Clair de Lune',      1905, 'Quiet, dreamy piano piece.',       'song');    -- 7

INSERT INTO books    (media_id, author, isbn, page_count)   VALUES (1, 'Donna Tartt', '9781400031702', 559);
INSERT INTO tv_shows (media_id, director, episode_count, season_count) VALUES (2, 'David Lynch', 48, 3);
INSERT INTO movies   (media_id, director, duration_minutes) VALUES (3, 'Rian Johnson', 130), (6, 'Peter Weir', 128);
INSERT INTO podcasts (media_id, episode_count)              VALUES (4, 40);
INSERT INTO songs    (media_id, artist, duration_minutes)   VALUES (5, 'Beethoven', 6.00), (7, 'Debussy', 5.00);

INSERT INTO tag (name) VALUES ('dark academia'), ('mystery'), ('cozy'), ('melancholy');

INSERT INTO has_tag VALUES
  (1,1),(1,2),(1,4),   -- The Secret History: dark academia, mystery, melancholy
  (2,2),(2,4),         -- Twin Peaks: mystery, melancholy
  (3,2),(3,3),         -- Knives Out: mystery, cozy
  (4,2),               -- Serial: mystery
  (5,4),(5,1),         -- Moonlight Sonata: melancholy, dark academia
  (6,1),(6,4),         -- Dead Poets Society: dark academia, melancholy
  (7,4),(7,3);         -- Clair de Lune: melancholy, cozy

INSERT INTO tracks  VALUES (1, 1, 'finished'), (2, 3, 'in_progress'), (3, 2, 'want_to_consume');
INSERT INTO reviews VALUES (1, 1, 'Obsessed. Reread every autumn.');
INSERT INTO review_tags VALUES (1, 1, 1), (1, 1, 4);
INSERT INTO friends VALUES (1, 2), (2, 1), (3, 1);

INSERT INTO user_groups (group_name, creator_id) VALUES ('Spooky Season Club', 3);
INSERT INTO member_of  VALUES (1, 1), (1, 2), (1, 3);
INSERT INTO recommends VALUES (1, 2), (1, 4);

-- =====================================================================
-- DEMO QUERY 1: "Pick a vibe"
-- The user picks a vibe and gets media of every type that has it.
-- Change 'melancholy' to try another vibe.
-- =====================================================================
SELECT t.name AS vibe, m.media_type, m.title
FROM tag t
JOIN has_tag ht ON ht.tag_id = t.tag_id
JOIN media m    ON m.media_id = ht.media_id
WHERE t.name = 'melancholy'
ORDER BY m.media_type, m.title;