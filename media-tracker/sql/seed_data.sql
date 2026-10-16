
USE media_tracker;

-- Users (user_id 1-3)
INSERT INTO users (username, email, password_hash) VALUES
    ('muskan', 'muskan@example.com', '$2b$12$placeholderhashmuskan0000'),   -- 1
    ('divina', 'divina@example.com', '$2b$12$placeholderhashdivina0000'),   -- 2
    ('grace',  'grace@example.com',  '$2b$12$placeholderhashgrace00000');   -- 3

-- Media (media_id 1-7)
INSERT INTO media (title, release_year, summary) VALUES
    ('The Secret History', 1992, 'Classics students and a murder.'),                   -- 1 book
    ('Twin Peaks',         1990, 'A strange small-town mystery.'),                     -- 2 tv_show
    ('Knives Out',         2019, 'A detective untangles a family.'),                   -- 3 movie
    ('Serial',             2014, 'Investigative true crime.'),                         -- 4 podcast
    ('Moonlight Sonata',   1801, 'Piano sonata, first movement.'),                     -- 5 song
    ('Dead Poets Society', 1989, 'An English teacher inspires a boarding school.'),    -- 6 movie
    ('Clair de Lune',      1905, 'Quiet, dreamy piano piece.');                        -- 7 song

-- One row in the matching child table for each media row (this row is what makes it a book,
-- a movie, ...: there is no media_type column any more)
INSERT INTO books (media_id, author, isbn, page_count) VALUES
    (1, 'Donna Tartt', '9781400031702', 559);

INSERT INTO tv_shows (media_id, director) VALUES
    (2, 'David Lynch');

INSERT INTO movies (media_id, director, duration_minutes) VALUES
    (3, 'Rian Johnson', 130),
    (6, 'Peter Weir',   128);

INSERT INTO podcasts (media_id) VALUES
    (4);

INSERT INTO songs (media_id, artist, duration_minutes) VALUES
    (5, 'Beethoven', 6.00),
    (7, 'Debussy',   5.00);

-- Episodes (weak entities): identified by their show/podcast plus season and episode number
INSERT INTO tv_episodes (media_id, season_number, episode_number, title, duration_minutes) VALUES
    (2, 1, 1, 'Pilot',                      93.00),
    (2, 1, 2, 'Traces to Nowhere',          47.00),
    (2, 2, 1, 'May the Giant Be with You',  92.00);

INSERT INTO podcast_episodes (media_id, episode_number, title, duration_minutes) VALUES
    (4, 1, 'The Alibi',    53.00),
    (4, 2, 'The Breakup',  47.00);

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
