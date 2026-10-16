
USE media_tracker;

-- Helper for F6 (created before the transaction: creating a procedure ends any open transaction)
DROP PROCEDURE IF EXISTS try_delete_group_creator;
DELIMITER //
CREATE PROCEDURE try_delete_group_creator()
BEGIN
    DECLARE blocked INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR 1451 SET blocked = 1;
    DELETE FROM users WHERE user_id = 3;          -- grace still owns 'Spooky Season Club'
    SELECT 'F6 RESTRICT: group creator cannot be deleted' AS test,
           blocked AS delete_blocked,
           (SELECT COUNT(*) FROM users WHERE user_id = 3) AS grace_still_exists,
           IF(blocked = 1 AND (SELECT COUNT(*) FROM users WHERE user_id = 3) = 1,
              'PASS', 'FAIL') AS result;
END //
DELIMITER ;

START TRANSACTION;

-- F1: delete a TV show -> its child row, episodes, tags, tracks and recommendations go too
DELETE FROM media WHERE media_id = 2;                                  -- Twin Peaks
SELECT 'F1 CASCADE: delete TV show (media 2)' AS test,
       (SELECT COUNT(*) FROM tv_shows    WHERE media_id = 2)
     + (SELECT COUNT(*) FROM tv_episodes WHERE media_id = 2)
     + (SELECT COUNT(*) FROM has_tag     WHERE media_id = 2)
     + (SELECT COUNT(*) FROM tracks      WHERE media_id = 2)
     + (SELECT COUNT(*) FROM recommends  WHERE media_id = 2) AS rows_left,
       IF((SELECT COUNT(*) FROM tv_shows    WHERE media_id = 2)
        + (SELECT COUNT(*) FROM tv_episodes WHERE media_id = 2)
        + (SELECT COUNT(*) FROM has_tag     WHERE media_id = 2)
        + (SELECT COUNT(*) FROM tracks      WHERE media_id = 2)
        + (SELECT COUNT(*) FROM recommends  WHERE media_id = 2) = 0, 'PASS', 'FAIL') AS result;

-- F2: delete a book -> its review AND the review's tags go too (two levels of cascade)
DELETE FROM media WHERE media_id = 1;                                  -- The Secret History
SELECT 'F2 CASCADE: delete book (media 1), 2 levels' AS test,
       (SELECT COUNT(*) FROM books       WHERE media_id = 1)
     + (SELECT COUNT(*) FROM reviews     WHERE media_id = 1)
     + (SELECT COUNT(*) FROM review_tags WHERE media_id = 1)
     + (SELECT COUNT(*) FROM has_tag     WHERE media_id = 1)
     + (SELECT COUNT(*) FROM tracks      WHERE media_id = 1) AS rows_left,
       IF((SELECT COUNT(*) FROM books       WHERE media_id = 1)
        + (SELECT COUNT(*) FROM reviews     WHERE media_id = 1)
        + (SELECT COUNT(*) FROM review_tags WHERE media_id = 1)
        + (SELECT COUNT(*) FROM has_tag     WHERE media_id = 1)
        + (SELECT COUNT(*) FROM tracks      WHERE media_id = 1) = 0, 'PASS', 'FAIL') AS result;

-- F3: delete a podcast -> its weak-entity episodes go too
DELETE FROM media WHERE media_id = 4;                                  -- Serial
SELECT 'F3 CASCADE: delete podcast (media 4)' AS test,
       (SELECT COUNT(*) FROM podcasts         WHERE media_id = 4)
     + (SELECT COUNT(*) FROM podcast_episodes WHERE media_id = 4) AS rows_left,
       IF((SELECT COUNT(*) FROM podcasts         WHERE media_id = 4)
        + (SELECT COUNT(*) FROM podcast_episodes WHERE media_id = 4) = 0, 'PASS', 'FAIL') AS result;

-- F4: delete a tag -> it disappears from every media item, but the media items stay
DELETE FROM tag WHERE tag_id = 3;                                      -- cozy
SELECT 'F4 CASCADE: delete tag (cozy)' AS test,
       (SELECT COUNT(*) FROM has_tag WHERE tag_id = 3) AS links_left,
       (SELECT COUNT(*) FROM media WHERE media_id IN (3, 7)) AS media_kept,
       IF((SELECT COUNT(*) FROM has_tag WHERE tag_id = 3) = 0
          AND (SELECT COUNT(*) FROM media WHERE media_id IN (3, 7)) = 2, 'PASS', 'FAIL') AS result;

-- F5: delete a user -> follows (both directions), memberships and tracks go too
DELETE FROM users WHERE user_id = 2;                                   -- divina
SELECT 'F5 CASCADE: delete user (divina)' AS test,
       (SELECT COUNT(*) FROM friends   WHERE follower_id = 2 OR followed_id = 2)
     + (SELECT COUNT(*) FROM member_of WHERE user_id = 2)
     + (SELECT COUNT(*) FROM tracks    WHERE user_id = 2) AS rows_left,
       IF((SELECT COUNT(*) FROM friends   WHERE follower_id = 2 OR followed_id = 2)
        + (SELECT COUNT(*) FROM member_of WHERE user_id = 2)
        + (SELECT COUNT(*) FROM tracks    WHERE user_id = 2) = 0, 'PASS', 'FAIL') AS result;

-- F6: RESTRICT
CALL try_delete_group_creator();

-- F7: delete a group -> memberships and recommendations go, the users stay
DELETE FROM user_groups WHERE group_id = 1;
SELECT 'F7 CASCADE: delete group' AS test,
       (SELECT COUNT(*) FROM member_of  WHERE group_id = 1)
     + (SELECT COUNT(*) FROM recommends WHERE group_id = 1) AS rows_left,
       IF((SELECT COUNT(*) FROM member_of  WHERE group_id = 1)
        + (SELECT COUNT(*) FROM recommends WHERE group_id = 1) = 0, 'PASS', 'FAIL') AS result;

-- F8: after all of that, no row anywhere points to a parent that does not exist
SET @orphans =
    (SELECT COUNT(*) FROM books b            LEFT JOIN media m ON m.media_id = b.media_id WHERE m.media_id IS NULL)
  + (SELECT COUNT(*) FROM tv_shows c         LEFT JOIN media m ON m.media_id = c.media_id WHERE m.media_id IS NULL)
  + (SELECT COUNT(*) FROM movies c           LEFT JOIN media m ON m.media_id = c.media_id WHERE m.media_id IS NULL)
  + (SELECT COUNT(*) FROM podcasts c         LEFT JOIN media m ON m.media_id = c.media_id WHERE m.media_id IS NULL)
  + (SELECT COUNT(*) FROM songs c            LEFT JOIN media m ON m.media_id = c.media_id WHERE m.media_id IS NULL)
  + (SELECT COUNT(*) FROM tv_episodes e      LEFT JOIN tv_shows s ON s.media_id = e.media_id WHERE s.media_id IS NULL)
  + (SELECT COUNT(*) FROM podcast_episodes e LEFT JOIN podcasts p ON p.media_id = e.media_id WHERE p.media_id IS NULL)
  + (SELECT COUNT(*) FROM has_tag h LEFT JOIN media m ON m.media_id = h.media_id LEFT JOIN tag t ON t.tag_id = h.tag_id
         WHERE m.media_id IS NULL OR t.tag_id IS NULL)
  + (SELECT COUNT(*) FROM tracks x  LEFT JOIN users u ON u.user_id = x.user_id LEFT JOIN media m ON m.media_id = x.media_id
         WHERE u.user_id IS NULL OR m.media_id IS NULL)
  + (SELECT COUNT(*) FROM reviews x LEFT JOIN users u ON u.user_id = x.user_id LEFT JOIN media m ON m.media_id = x.media_id
         WHERE u.user_id IS NULL OR m.media_id IS NULL)
  + (SELECT COUNT(*) FROM review_tags x LEFT JOIN reviews r ON r.user_id = x.user_id AND r.media_id = x.media_id
         WHERE r.user_id IS NULL)
  + (SELECT COUNT(*) FROM friends f LEFT JOIN users a ON a.user_id = f.follower_id LEFT JOIN users b ON b.user_id = f.followed_id
         WHERE a.user_id IS NULL OR b.user_id IS NULL)
  + (SELECT COUNT(*) FROM member_of x LEFT JOIN user_groups g ON g.group_id = x.group_id LEFT JOIN users u ON u.user_id = x.user_id
         WHERE g.group_id IS NULL OR u.user_id IS NULL)
  + (SELECT COUNT(*) FROM recommends x LEFT JOIN user_groups g ON g.group_id = x.group_id LEFT JOIN media m ON m.media_id = x.media_id
         WHERE g.group_id IS NULL OR m.media_id IS NULL);
SELECT 'F8 zero orphan rows in all 14 child tables' AS test,
       @orphans AS orphan_rows,
       IF(@orphans = 0, 'PASS', 'FAIL') AS result;

-- Put everything back the way it was.
ROLLBACK;
DROP PROCEDURE IF EXISTS try_delete_group_creator;
