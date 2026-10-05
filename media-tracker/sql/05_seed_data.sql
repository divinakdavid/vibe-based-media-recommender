-- 05_seed_data.sql                                          OWNER: Lane C (Data & Queries)
-- Sample data so every table has rows to query.
-- IMPORTANT: ids come from AUTO_INCREMENT, and this script assumes a fresh schema
-- (00_drop_all -> 01 -> 02 -> 03 -> 04 first) so ids start at 1.
-- Do not list media_type when inserting into a child table (books, movies, ...).
-- password_hash values are fake placeholders, not real hashes.

USE media_tracker;

INSERT INTO users (username, email, password_hash) VALUES
  ('muskan', 'muskan@example.com', '$2b$12$placeholderhashmuskan0000'),   -- 1
  ('divina', 'divina@example.com', '$2b$12$placeholderhashdivina0000'),   -- 2
  ('grace',  'grace@example.com',  '$2b$12$placeholderhashgrace00000');   -- 3

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

INSERT INTO tag (name) VALUES ('dark academia'), ('mystery'), ('cozy'), ('melancholy');   -- 1..4

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
INSERT INTO friends VALUES (1, 2), (2, 1), (3, 1);        -- follower, followed

INSERT INTO user_groups (group_name, creator_id) VALUES ('Spooky Season Club', 3);   -- created by grace
INSERT INTO member_of  VALUES (1, 1), (1, 2), (1, 3);
INSERT INTO recommends VALUES (1, 2), (1, 4);
