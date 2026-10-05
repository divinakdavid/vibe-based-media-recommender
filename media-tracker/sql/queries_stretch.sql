-- queries_stretch.sql
-- STRETCH: recommendation queries that go beyond the course material so far.
-- They use GROUP BY, COUNT, NOT EXISTS and GROUP_CONCAT, which come later.
-- Read-only, safe to re-run. Change the usernames / titles to try other cases.

USE media_tracker;

-- 1) "BECAUSE YOU PICKED X": media of a DIFFERENT type that share the picked item's vibe
--    tags, ranked by how many tags they share.
SELECT m2.title, m2.media_type, COUNT(*) AS shared_tags
FROM media picked
JOIN has_tag a ON a.media_id = picked.media_id
JOIN has_tag b ON b.tag_id = a.tag_id AND b.media_id <> a.media_id
JOIN media m2  ON m2.media_id = b.media_id AND m2.media_type <> picked.media_type
WHERE picked.title = 'The Secret History'
GROUP BY m2.media_id, m2.title, m2.media_type
ORDER BY shared_tags DESC, m2.title;

-- 2) FROM VIEWING HISTORY: media the user has not tracked yet that matches the vibes of
--    everything they have finished.
SELECT m.title, m.media_type, COUNT(*) AS matching_tags
FROM users u
JOIN tracks t     ON t.user_id = u.user_id AND t.media_status = 'finished'
JOIN has_tag seen ON seen.media_id = t.media_id
JOIN has_tag cand ON cand.tag_id = seen.tag_id
JOIN media m      ON m.media_id = cand.media_id
WHERE u.username = 'muskan'
  AND NOT EXISTS (SELECT 1
                  FROM tracks x
                  WHERE x.user_id = u.user_id AND x.media_id = m.media_id)
GROUP BY m.media_id, m.title, m.media_type
ORDER BY matching_tags DESC, m.title
LIMIT 5;

-- 3) FROM FRIENDS: media that the people grace follows have finished and she has not tracked.
SELECT m.title, m.media_type, GROUP_CONCAT(DISTINCT fu.username) AS recommended_by
FROM users me
JOIN friends f ON f.follower_id = me.user_id
JOIN users fu  ON fu.user_id = f.followed_id
JOIN tracks t  ON t.user_id = f.followed_id AND t.media_status = 'finished'
JOIN media m   ON m.media_id = t.media_id
WHERE me.username = 'grace'
  AND NOT EXISTS (SELECT 1
                  FROM tracks mine
                  WHERE mine.user_id = me.user_id AND mine.media_id = m.media_id)
GROUP BY m.media_id, m.title, m.media_type
ORDER BY m.title;
