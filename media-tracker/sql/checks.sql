-- checks.sql
-- Every CHECK constraint, added with ALTER TABLE so they are easy to find.
-- Run after the three schema_*.sql files. Requires MySQL 8.0.16+.
-- A violation raises error 3819: "Check constraint '...' is violated."
-- Constraint names must be unique across the whole database, hence the chk_ names.
--
-- A NULL value passes a CHECK (e.g. an unknown release_year is allowed).
-- Make the column NOT NULL in the schema if it must always be filled in.

USE media_tracker;

-- ---------------- users ----------------
ALTER TABLE users ADD CONSTRAINT chk_username_len
    CHECK (CHAR_LENGTH(TRIM(username)) >= 3);

-- Email shape: something@something.something, with no spaces and only one @.
ALTER TABLE users ADD CONSTRAINT chk_email
    CHECK (email LIKE '%_@_%._%'
           AND email NOT LIKE '% %'
           AND email NOT LIKE '%@%@%');

ALTER TABLE users ADD CONSTRAINT chk_password_hash_len
    CHECK (CHAR_LENGTH(password_hash) >= 20);     -- a real bcrypt hash is 60 characters

-- ---------------- friends ----------------
ALTER TABLE friends ADD CONSTRAINT chk_no_self_follow
    CHECK (follower_id <> followed_id);

-- ---------------- user_groups ----------------
ALTER TABLE user_groups ADD CONSTRAINT chk_group_name_not_blank
    CHECK (CHAR_LENGTH(TRIM(group_name)) >= 1);

-- ---------------- media ----------------
ALTER TABLE media ADD CONSTRAINT chk_title_not_blank
    CHECK (CHAR_LENGTH(TRIM(title)) >= 1);

ALTER TABLE media ADD CONSTRAINT chk_media_type
    CHECK (media_type IN ('book', 'tv_show', 'movie', 'podcast', 'song'));

ALTER TABLE media ADD CONSTRAINT chk_release_year
    CHECK (release_year BETWEEN 1400 AND 2100);

-- ---------------- media children ----------------
ALTER TABLE books ADD CONSTRAINT chk_page_count
    CHECK (page_count > 0);

-- An ISBN has 10 or 13 characters (digits only, no hyphens).
ALTER TABLE books ADD CONSTRAINT chk_isbn_length
    CHECK (CHAR_LENGTH(isbn) IN (10, 13));

ALTER TABLE tv_shows ADD CONSTRAINT chk_tv_counts
    CHECK (season_count > 0 AND episode_count >= season_count);

ALTER TABLE movies   ADD CONSTRAINT chk_movie_duration   CHECK (duration_minutes > 0);
ALTER TABLE podcasts ADD CONSTRAINT chk_podcast_episodes CHECK (episode_count > 0);
ALTER TABLE songs    ADD CONSTRAINT chk_song_duration    CHECK (duration_minutes > 0);

-- ---------------- tag ----------------
ALTER TABLE tag ADD CONSTRAINT chk_tag_not_blank
    CHECK (CHAR_LENGTH(TRIM(name)) >= 1);

-- ---------------- tracks / reviews ----------------
ALTER TABLE tracks ADD CONSTRAINT chk_media_status
    CHECK (media_status IN ('want_to_consume', 'in_progress', 'finished', 'dropped'));

ALTER TABLE reviews ADD CONSTRAINT chk_review_not_blank
    CHECK (CHAR_LENGTH(TRIM(user_review)) >= 1);
