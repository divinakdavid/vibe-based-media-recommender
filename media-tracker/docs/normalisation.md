# Normalisation

**Result:** all 18 tables are in **BCNF**, and therefore **3NF**, and in **4NF**.
Evidence: `sql/normalization_tests.sql` (8 tests, all `PASS`).

## 1. Functional dependencies and BCNF

A table is in BCNF when the left side of every non-trivial FD is a superkey.

| Table | Candidate key(s) | Non-trivial FDs | BCNF |
|---|---|---|---|
| `users` | `user_id`; `username`; `email` | each key → all other columns | yes |
| `friends` | `(follower_id, followed_id)` | none (all-key) | yes |
| `user_groups` | `group_id` | `group_id → group_name, creator_id` | yes |
| `member_of` | `(group_id, user_id)` | none (all-key) | yes |
| `media` | `media_id` | `media_id → title, release_year, summary` | yes |
| `books` | `media_id`; `isbn` | each key → all other columns | yes |
| `tv_shows` | `media_id` | `media_id → director` | yes |
| `movies` | `media_id` | `media_id → director, duration_minutes` | yes |
| `podcasts` | `media_id` | none (key only) | yes |
| `songs` | `media_id` | `media_id → artist, duration_minutes` | yes |
| `tv_episodes` | `(media_id, season_number, episode_number)` | key → `title, duration_minutes` | yes |
| `podcast_episodes` | `(media_id, episode_number)` | key → `title, duration_minutes` | yes |
| `tag` | `tag_id`; `name` | `tag_id → name`; `name → tag_id` | yes |
| `has_tag` | `(media_id, tag_id)` | none (all-key) | yes |
| `tracks` | `(user_id, media_id)` | `user_id, media_id → media_status` | yes |
| `reviews` | `(user_id, media_id)` | `user_id, media_id → user_review` | yes |
| `review_tags` | `(user_id, media_id, tag_id)` | none (all-key) | yes |
| `recommends` | `(group_id, media_id)` | none (all-key) | yes |

Every left side is a candidate key, so every table is in BCNF.

**Sprint 2 changes that removed redundancy:**
- `media.media_type` was removed. A media item's type is already given by which child table it
  is in, so storing it again could contradict that. The `media_with_type` view derives it.
- `episode_count` and `season_count` were removed. They are now `COUNT(*)` over the episode
  tables (weak entities), so they can never disagree with the episodes actually stored.

## 2. The one decomposition: `reviews` and `review_tags`

A review's tags are multivalued, so storing them with the review repeats the text once per tag:

```
review_flat (user_id, media_id, tag_id, user_review)    key: (user_id, media_id, tag_id)
```

`user_id, media_id → user_review` holds, but `(user_id, media_id)` is not a superkey, so this
breaks BCNF. Splitting on that FD gives:

```
reviews     (user_id, media_id, user_review)    key: (user_id, media_id)
review_tags (user_id, media_id, tag_id)         key: (user_id, media_id, tag_id)
```

The join is **lossless** (the shared columns are the key of `reviews`) and the FD is
**preserved** (it sits entirely in `reviews`).

## 3. 3NF and dependency preservation

BCNF is stricter than 3NF, so every table is also in 3NF. Every FD in section 1 has all its
columns in one table, so MySQL enforces it with that table's `PRIMARY KEY` or `UNIQUE`
constraint, with no join needed. No dependency was lost.

## 4. 4NF

A media item has many **tags** and many **reviewers**, and the two are independent:
`media_id ↠ tag_id` and `media_id ↠ user_id`.

Storing both in one table, `(media_id, tag_id, user_id)`, would pair every tag with every
reviewer: 3 tags × 3 reviewers = **9 rows** instead of 3 + 3 = **6**, with insertion, deletion
and update anomalies.

We keep each multivalued fact in its own table (`has_tag`, `reviews`, `review_tags`,
`friends`, `member_of`, `recommends`). In each one the MVD covers the whole table, so it is
trivial, and the schema is in 4NF.

## 5. Evidence

`sql/normalization_tests.sql` runs in a transaction and rolls back, so it leaves the data unchanged.

| Test | Shows |
|---|---|
| T1 | combined table = 9 rows, our tables = 6 (no redundancy) |
| T2 | adding a vibe = 1 row (no insertion anomaly) |
| T3 | deleting all reviews keeps the vibes (no deletion anomaly) |
| T4 | removing a vibe from one item keeps the tag for others |
| T5 | renaming a vibe changes 1 row (no update anomaly) |
| T6 | a multi-vibe search returns each item once |
| T7 | no rows break any FD in the data |
| T8 | MySQL rejects a duplicate email, so the FD is enforced |

**Known limitation:** the database does not yet stop one media item from appearing in two
child tables (e.g. both `books` and `movies`). That is a rule across two tables, not an FD,
so it does not affect the normal form. It is planned as a trigger next sprint.
