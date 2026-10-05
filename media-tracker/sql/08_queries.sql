-- 08_queries.sql                                            OWNER: Lane C (Data & Queries)
-- The queries the app is built around. Read-only, safe to re-run.
-- Change the usernames / titles / vibes in the WHERE clauses to try different cases.

USE media_tracker;

-- 1) PICK A VIBE: the user picks a vibe and gets media of every type that has it.
SELECT t.name AS vibe, m.media_type, m.title
FROM tag t
JOIN has_tag ht ON ht.tag_id = t.tag_id
JOIN media m    ON m.media_id = ht.media_id
WHERE t.name = 'melancholy'
ORDER BY m.media_type, m.title;

-- 2) "BECAUSE YOU PICKED X": media of a DIFFERENT type that share its vibe tags,
--    ranked by how many tags they share.
SELECT m2.title, m2.media_type, COUNT(*) AS shared_tags
FROM media picked
JOIN has_tag a ON a.media_id = picked.media_id
JOIN has_tag b ON b.tag_id   = a.tag_id AND b.media_id <> a.media_id
JOIN media m2  ON m2.media_id = b.media_id AND m2.media_type <> picked.media_type
WHERE picked.title = 'The Secret History'
GROUP BY m2.media_id, m2.title, m2.media_type
ORDER BY shared_tags DESC, m2.title;

-- 3) FROM VIEWING HISTORY: untracked media that matches the vibes of everything
--    the user has already finished.
SELECT m.title, m.media_type, COUNT(*) AS matching_tags
FROM users u
JOIN tracks t   ON t.user_id = u.user_id AND t.media_status = 'finished'
JOIN has_tag seen ON seen.media_id = t.media_id
JOIN has_tag cand ON cand.tag_id = seen.tag_id
JOIN media m      ON m.media_id = cand.media_id
WHERE u.username = 'muskan'
  AND NOT EXISTS (SELECT 1 FROM tracks x
                  WHERE x.user_id = u.user_id AND x.media_id = m.media_id)
GROUP BY m.media_id, m.title, m.media_type
ORDER BY matching_tags DESC, m.title
LIMIT 5;

-- 4) FROM FRIENDS: media that people grace follows have finished and she hasn't tracked yet.
SELECT m.title, m.media_type, GROUP_CONCAT(DISTINCT fu.username) AS recommended_by
FROM users me
JOIN friends f   ON f.follower_id = me.user_id
JOIN users fu    ON fu.user_id = f.followed_id
JOIN tracks t    ON t.user_id = f.followed_id AND t.media_status = 'finished'
JOIN media m     ON m.media_id = t.media_id
WHERE me.username = 'grace'
  AND NOT EXISTS (SELECT 1 FROM tracks mine
                  WHERE mine.user_id = me.user_id AND mine.media_id = m.media_id)
GROUP BY m.media_id, m.title, m.media_type
ORDER BY m.title;

-- 5) GROUP PICKS: what each group recommends, with the creator's name.
SELECT g.group_name, creator.username AS created_by, m.title, m.media_type
FROM user_groups g
JOIN users creator ON creator.user_id = g.creator_id
JOIN recommends r  ON r.group_id = g.group_id
JOIN media m       ON m.media_id = r.media_id
ORDER BY g.group_name, m.title;
