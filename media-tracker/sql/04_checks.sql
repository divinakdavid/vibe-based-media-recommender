-- 04_checks.sql                                             OWNER: Lane B (Rules & Operations)
-- Every CHECK constraint, added with ALTER TABLE so they are easy to find and review.
-- Constraint names must be unique across the whole MySQL database, hence the chk_ prefix.
-- Violations raise MySQL error 3819: "Check constraint '...' is violated."
-- Requires MySQL 8.0.16+. Run after the three schema files.
--
-- NULL values pass a CHECK (e.g. a missing release_year is allowed). Use NOT NULL in the
-- schema if a column must always be filled in.

USE media_tracker;

-- ---------------- users ----------------
ALTER TABLE users ADD CONSTRAINT chk_username_len
    CHECK (CHAR_LENGTH(TRIM(username)) >= 3);
-- Real email shape: no spaces, exactly one @, something before it, and a dot in the domain.
ALTER TABLE users ADD CONSTRAINT chk_email
    CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$');
ALTER TABLE users ADD CONSTRAINT chk_password_hash_len
    CHECK (CHAR_LENGTH(password_hash) >= 20);       -- a real bcrypt hash is 60 chars

-- ---------------- friends ----------------
-- No following yourself. (A CHECK is allowed here because the foreign keys only use
-- ON DELETE CASCADE. MySQL does NOT allow a CHECK on a column whose foreign key uses
-- ON UPDATE CASCADE / SET NULL / SET DEFAULT, so don't add those to friends.)
ALTER TABLE friends ADD CONSTRAINT chk_no_self_follow
    CHECK (follower_id <> followed_id);

-- ---------------- user_groups ----------------
ALTER TABLE user_groups ADD CONSTRAINT chk_group_name_not_blank
    CHECK (CHAR_LENGTH(TRIM(group_name)) >= 1);

-- ---------------- media ----------------
ALTER TABLE media ADD CONSTRAINT chk_title_not_blank
    CHECK (CHAR_LENGTH(TRIM(title)) >= 1);
ALTER TABLE media ADD CONSTRAINT chk_media_type
    CHECK (media_type IN ('book','tv_show','movie','podcast','song'));
ALTER TABLE media ADD CONSTRAINT chk_release_year
    CHECK (release_year BETWEEN 1400 AND 2100);

-- ---------------- media children ----------------
-- (media_type in each child is a generated constant, so it needs no CHECK; the composite
--  foreign key to media already rejects a mismatched type.)
ALTER TABLE books ADD CONSTRAINT chk_page_count CHECK (page_count > 0);
ALTER TABLE books ADD CONSTRAINT chk_isbn_format
    CHECK (REGEXP_LIKE(isbn, '^([0-9]{9}[0-9X]|[0-9]{13})$', 'c'));   -- 10 or 13 chars, no hyphens

ALTER TABLE tv_shows ADD CONSTRAINT chk_tv_counts
    CHECK (season_count > 0 AND episode_count >= season_count);

ALTER TABLE movies   ADD CONSTRAINT chk_movie_duration   CHECK (duration_minutes > 0);
ALTER TABLE podcasts ADD CONSTRAINT chk_podcast_episodes CHECK (episode_count > 0);
ALTER TABLE songs    ADD CONSTRAINT chk_song_duration    CHECK (duration_minutes > 0);

-- ---------------- tag ----------------
-- Tags are lowercase. COLLATE utf8mb4_bin makes the comparison case-sensitive
-- (MySQL's default collation ignores case, so name = LOWER(name) alone would always pass).
ALTER TABLE tag ADD CONSTRAINT chk_tag_lowercase
    CHECK ((name COLLATE utf8mb4_bin = LOWER(name)) AND CHAR_LENGTH(TRIM(name)) >= 1);

-- ---------------- tracks / reviews ----------------
ALTER TABLE tracks ADD CONSTRAINT chk_media_status
    CHECK (media_status IN ('want_to_consume','in_progress','finished','dropped'));

ALTER TABLE reviews ADD CONSTRAINT chk_review_not_blank
    CHECK (CHAR_LENGTH(TRIM(user_review)) >= 1);
