
-- Drops every table and view so the database can be rebuilt from scratch. Safe to re-run.
-- WARNING: this deletes all data in these tables.

USE media_tracker;

SET FOREIGN_KEY_CHECKS = 0;   -- lets us drop the tables in any order

DROP VIEW IF EXISTS media_with_type;

DROP TABLE IF EXISTS
    recommends, member_of, user_groups, friends, review_tags, reviews,
    tracks, has_tag, tag, tv_episodes, podcast_episodes,
    songs, podcasts, movies, tv_shows, books, media, users;

SET FOREIGN_KEY_CHECKS = 1;
