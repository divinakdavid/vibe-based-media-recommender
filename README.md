# Media Tracker: a vibe-based media recommender database

A MySQL database for finding books, TV shows, movies, podcasts and songs by **vibe**. Users tag media
with vibes such as *cozy* or *melancholy*, track and review what they consume, follow friends and
join groups that recommend media. Picking one item can suggest items of other types that share its vibes.

This repository contains the conceptual design (ERD and a design audit), the normalisation and
referential-integrity write-ups, and the relational implementation as SQL (DDL, constraints, sample data,
data loading, queries, tests).

<img width="612" height="352" alt="image" src="https://github.com/user-attachments/assets/effdb0a0-a816-4bae-944c-81c6aaf3e5ea" />


## Requirements

- **MySQL 8.0.16 or newer.** Older versions accept `CHECK` constraints but silently ignore them.
  Check with `SELECT VERSION();`
- The `mysql` command-line client **or** MySQL Workbench. No other software is needed.

## Repository structure

```
.
├── README.md
├── .gitattributes                    keeps the CSV files on Unix line endings
├── .gitignore
└── media-tracker/
    ├── data/                         CSV files read by load_csv.sql
    │   ├── media.csv, books.csv, movies.csv, songs.csv, has_tag.csv
    └── sql/
        ├── run_all.sql               builds the database, then runs the safe demos and the integrity audit
        │
        ├── setup.sql                 creates the media_tracker database
        ├── drop_all.sql              drops all tables (clean slate)
        ├── schema_users_groups.sql   users, friends, user_groups, member_of
        ├── schema_media.sql          media, books, tv_shows, movies, podcasts, songs, tv_episodes,
        │                             podcast_episodes, tag, has_tag, and the view media_with_type
        ├── schema_activity.sql       tracks, reviews, review_tags, recommends
        ├── checks.sql                20 CHECK constraints
        ├── seed_data.sql             sample data for every table
        │
        ├── crud_operations.sql       INSERT / UPDATE / DELETE on every table
        ├── queries.sql               basic joins, filtering and sorting
        ├── alter_table.sql           ALTER TABLE demo: add a column, fill it, remove it
        ├── normalisation.md          Results of BCNF calculation
        ├── normalisation_tests.sql   BCNF check for all 18 tables
        ├── fk_tests.sql              tests every ON DELETE / ON UPDATE policy (RESTRICT refusals and CASCADEs)
        ├── load_csv.sql              loads new rows from ../data/*.csv
        └── queries_stretch.sql       optional recommendation queries (GROUP BY, COUNT, NOT EXISTS)
```

## Quick start (about one minute)

From the repository root:

```bash
cd media-tracker/sql
mysql -u root -p
```
```sql
SOURCE run_all.sql;
```

This creates the `media_tracker` database, builds the 18 tables and one view, adds the constraints and
sample data, then runs the CRUD, query and ALTER TABLE demos and the integrity audit. It prints their results
and finishes with no errors. The last table it prints is the audit: every `violations` value must be `0`.
It is safe to run again: it drops and rebuilds everything first (so it deletes the data in these tables).

**Check that it worked:**
```sql
USE media_tracker;
SHOW TABLES;                                   -- 18 tables and the view media_with_type
SELECT username FROM users;                    -- muskan, divina, grace
SELECT CONSTRAINT_NAME FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'media_tracker';     -- 20 rows
```

**MySQL Workbench:** `SOURCE` is not supported there. Open each file and run it (lightning-bolt button)
in this order: `setup` → `drop_all` → `schema_users_groups` → `schema_media` → `schema_activity` →
`checks` → `seed_data`. After that, `crud_operations`, `queries`, `alter_table` and `integrity_audit` can be run
in any order.

## Design overview

- **18 tables in BCNF.** People: `users`, `friends`, `user_groups`, `member_of`. Media: `media`, five child
  tables, two episode tables, `tag`, `has_tag`. Activity: `tracks`, `reviews`, `review_tags`, `recommends`.
  The full working (keys, functional dependencies, BCNF check per table) is in `media-tracker/docs/normalisation.md`.
- **Inheritance (ISA).** `media` holds what every item has (title, year, summary). `books`,
  `tv_shows`, `movies`, `podcasts` and `songs` each hold only their own attributes and share `media_id` as primary
  key and foreign key to `media`. This avoids one wide table that is mostly NULL. Every media item is in exactly
  one child table, so its type is *derived*, not stored: the view `media_with_type` computes it.
- **Weak entity sets.** TV and podcast episodes cannot be identified without their show, so `tv_episodes` has the
  primary key `(media_id, season_number, episode_number)` and `podcast_episodes` has `(media_id, episode_number)`,
  each with `media_id` as a foreign key to its show. Season and episode counts are counted from these rows.
- **Relationships.** Many-to-many relationships (`friends`, `member_of`, `has_tag`, `tracks`, `reviews`,
  `recommends`) are link tables with composite primary keys. `friends` is a recursive relationship on `users`
  (follower and followed). *Creates* is many-to-one, so it is the column `user_groups.creator_id`.
- **BCNF decomposition.** A review's tags are multi-valued, so they live in `review_tags` instead of repeating
  the review text once per tag. `normalisation.md` section 3 shows the anomalies this removes.
- **Foreign keys** all state their policy explicitly. Rows that only make sense with their parent (track lists,
  memberships, reviews, children of a media item, episodes) are `ON DELETE CASCADE`. A group's creator and a tag
  that is in use are `ON DELETE RESTRICT`, so a user who still owns a group cannot be deleted until the group is
  reassigned or removed. Every key is `ON UPDATE RESTRICT`, because ids never change. The reasoning is in
  `media-tracker/docs/referential_integrity.md`.
- **Data types.** `INT` ids with `AUTO_INCREMENT`, `VARCHAR` for names, `TEXT` for summaries and reviews, and
  `DECIMAL(5,2)` for durations in decimal minutes (`3.50` means 3 min 30 s, not 3:50). A `NULL` means "unknown"
  (for example a book without an ISBN).
- **Constraints.** `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE` and `NOT NULL` in the schema files, plus 20 named
  `CHECK` constraints in `checks.sql` (value lists, positive numbers and durations, valid years, simple email and
  ISBN-length rules, no self-follows, no blank text).
- **Design quality.** `media-tracker/docs/erd_audit.md` audits the ERD against the standard design criteria and
  shows that no attribute is redundant (the media type and the season and episode counts were removed because
  they can be derived).
- **Naming.** The table is `user_groups` because `GROUPS` is a reserved word in MySQL 8. `password_hash` stores
  a hash, never a plain password; the values in the sample data are fake placeholders.
