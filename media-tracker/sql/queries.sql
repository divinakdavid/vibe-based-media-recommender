-- queries.sql
-- Basic retrieval queries: joins, WHERE and ORDER BY. Read-only, safe to re-run.
-- More advanced recommendation queries are in queries_stretch.sql.

USE media_tracker;

-- 1) PICK A VIBE: media of every type that has the chosen vibe.
--    Change 'melancholy' to 'cozy', 'mystery' or 'dark academia' to try another vibe.
SELECT t.name AS vibe, m.media_type, m.title
FROM tag t
JOIN has_tag ht        ON ht.tag_id = t.tag_id
JOIN media_with_type m ON m.media_id = ht.media_id
WHERE t.name = 'melancholy'
ORDER BY m.media_type, m.title;

-- 2) GROUP PICKS: what each group recommends, and who created the group.
SELECT g.group_name, creator.username AS created_by, m.title, m.media_type
FROM user_groups g
JOIN users creator     ON creator.user_id = g.creator_id
JOIN recommends r      ON r.group_id = g.group_id
JOIN media_with_type m ON m.media_id = r.media_id
ORDER BY g.group_name, m.title;

-- 3) EPISODES: the episodes of a TV show, in order. An episode is identified by its show plus
--    its season and episode number (a weak entity set). Change the title to try another show.
SELECT m.title AS show_title, e.season_number, e.episode_number, e.title AS episode_title
FROM media m
JOIN tv_episodes e ON e.media_id = m.media_id
WHERE m.title = 'Twin Peaks'
ORDER BY e.season_number, e.episode_number;