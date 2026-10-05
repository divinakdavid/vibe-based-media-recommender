-- seed_data.sql
-- Sample data so every table has rows to query.
-- Assumes a freshly built schema (drop_all -> schema_* -> checks), so AUTO_INCREMENT ids start at 1.
-- The ids in the comments below are the ones crud_operations.sql, check_tests.sql and
-- alter_table.sql rely on. password_hash values are fake placeholders, not real hashes.

USE media_tracker;

-- Users (user_id 1-3)
INSERT INTO users (username, email, password_hash) VALUES
    ('muskan', 'muskan@example.com', '$2b$12$placeholderhashmuskan0000'),   -- 1
    ('divina', 'divina@example.com', '$2b$12$placeholderhashdivina0000'),   -- 2
    ('grace',  'grace@example.com',  '$2b$12$placeholderhashgrace00000');   -- 3

-- Media (media_id 1-7)
INSERT INTO media (title, release_year, summary, media_type) VALUES
    ('The Secret History', 1992, 'Classics students and a murder.',                  'book'),      -- 1
    ('Twin Peaks',         1990, 'A strange small-town mystery.',                    'tv_show'),   -- 2
    ('Knives Out',         2019, 'A detective untangles a family.',                  'movie'),     -- 3
    ('Serial',             2014, 'Investigative true crime.',                        'podcast'),   -- 4
    ('Moonlight Sonata',   1801, 'Piano sonata, first movement.',                    'song'),      -- 5
    ('Dead Poets Society', 1989, 'An English teacher inspires a boarding school.',   'movie'),     -- 6
    ('Clair de Lune',      1905, 'Quiet, dreamy piano piece.',                       'song');      -- 7

-- One row in the matching child table for each media row
INSERT INTO books (media_id, author, isbn, page_count) VALUES
    (1, 'Donna Tartt', '9781400031702', 559);

INSERT INTO tv_shows (media_id, director, episode_count, season_count) VALUES
    (2, 'David Lynch', 48, 3);

INSERT INTO movies (media_id, director, duration_minutes) VALUES
    (3, 'Rian Johnson', 130),
    (6, 'Peter Weir',   128);

INSERT INTO podcasts (media_id, episode_count) VALUES
    (4, 40);

INSERT INTO songs (media_id, artist, duration_minutes) VALUES
    (5, 'Beethoven', 6.00),
    (7, 'Debussy',   5.00);

-- Tags (tag_id 1-4)
INSERT INTO tag (name) VALUES
    ('dark academia'),   -- 1
    ('mystery'),         -- 2
    ('cozy'),            -- 3
    ('melancholy');      -- 4

INSERT INTO has_tag (media_id, tag_id) VALUES
    (1, 1), (1, 2), (1, 4),     -- The Secret History: dark academia, mystery, melancholy
    (2, 2), (2, 4),             -- Twin Peaks: mystery, melancholy
    (3, 2), (3, 3),             -- Knives Out: mystery, cozy
    (4, 2),                     -- Serial: mystery
    (5, 4), (5, 1),             -- Moonlight Sonata: melancholy, dark academia
    (6, 1), (6, 4),             -- Dead Poets Society: dark academia, melancholy
    (7, 4), (7, 3);             -- Clair de Lune: melancholy, cozy

-- user_id, media_id, status
INSERT INTO tracks (user_id, media_id, media_status) VALUES
    (1, 1, 'finished'),
    (2, 3, 'in_progress'),
    (3, 2, 'want_to_consume');

INSERT INTO reviews (user_id, media_id, user_review) VALUES
    (1, 1, 'Obsessed. Reread every autumn.');

INSERT INTO review_tags (user_id, media_id, tag_id) VALUES
    (1, 1, 1),
    (1, 1, 4);

-- follower_id, followed_id
INSERT INTO friends (follower_id, followed_id) VALUES
    (1, 2),
    (2, 1),
    (3, 1);

-- Group 1 is created by grace (user 3)
INSERT INTO user_groups (group_name, creator_id) VALUES
    ('Spooky Season Club', 3);

INSERT INTO member_of (group_id, user_id) VALUES
    (1, 1),
    (1, 2),
    (1, 3);

INSERT INTO recommends (group_id, media_id) VALUES
    (1, 2),
    (1, 4);
