# Normalisation

**Result:** all 18 tables are in BCNF (so also 3NF) and 4NF.
**Evidence:** `sql/normalization_tests.sql` (8 tests, all `PASS`).

## 1. BCNF check

A table is in BCNF if, for every dependency `X → Y`, `X` is a key. Here, every dependency
starts from a key, so every table passes.

| Table | Key(s) | Dependencies |
|---|---|---|
| `users` | `user_id`, `username`, `email` | key → all other columns |
| `friends` | `(follower_id, followed_id)` | none |
| `user_groups` | `group_id` | `group_id → group_name, creator_id` |
| `member_of` | `(group_id, user_id)` | none |
| `media` | `media_id` | `media_id → title, release_year, summary` |
| `books` | `media_id`, `isbn` | key → all other columns |
| `tv_shows` | `media_id` | `media_id → director` |
| `movies` | `media_id` | `media_id → director, duration_minutes` |
| `podcasts` | `media_id` | `media_id → host` |
| `songs` | `media_id` | `media_id → artist, duration_minutes` |
| `tv_episodes` | `(media_id, season_number, episode_number)` | key → `title, duration_minutes` |
| `podcast_episodes` | `(media_id, episode_number)` | key → `title, duration_minutes` |
| `tag` | `tag_id`, `name` | `tag_id ↔ name` |
| `has_tag` | `(media_id, tag_id)` | none |
| `tracks` | `(user_id, media_id)` | `→ media_status` |
| `reviews` | `(user_id, media_id)` | `→ user_review` |
| `review_tags` | `(user_id, media_id, tag_id)` | none |
| `recommends` | `(group_id, media_id)` | none |

**Latest ERD change:** `podcasts` now has a `host` column (in `schema_media.sql`).
`media_id → host` starts from the key, so `podcasts` is still in BCNF.

## 2. Decomposition: `reviews` and `review_tags`

Storing a review's tags with its text repeats the text once per tag:

```
review_flat (user_id, media_id, tag_id, user_review)
```

`(user_id, media_id) → user_review` holds, but `(user_id, media_id)` is not a key here, so
this breaks BCNF. We split it:

```
reviews     (user_id, media_id, user_review)
review_tags (user_id, media_id, tag_id)
```

The split is lossless (the shared columns are the key of `reviews`) and no dependency is lost.

## 3. 3NF

BCNF implies 3NF. Every dependency lives inside one table, so a `PRIMARY KEY` or `UNIQUE`
constraint enforces it without a join.

## 4. 4NF

A media item has many tags and many reviewers, and the two are independent. Putting both in
one table would pair every tag with every reviewer (3 tags × 3 reviewers = 9 rows instead of
3 + 3 = 6). We keep them in separate tables (`has_tag`, `reviews`, `review_tags`), so there
is no such redundancy.

In dependency notation (`↠` is a multivalued dependency, `→` a functional one), a table is in
4NF when every non-trivial `X ↠ Y` has a key on the left. Here every multivalued fact has its
own table:

| MVD | Stored in | Why it is 4NF |
|---|---|---|
| `media_id ↠ tag_id` | `has_tag` | covers the whole table, so it is trivial |
| `(user_id, media_id) ↠ tag_id` | `review_tags` | covers the whole table, so it is trivial |
| `group_id ↠ user_id` and `group_id ↠ media_id` | `member_of` and `recommends`, kept apart | two columns each, so trivial |
| `follower_id ↠ followed_id` | `friends` | two columns, so trivial |
| none | every other table | a key determines every column and only single-valued facts are stored, so no non-trivial MVD has a non-key on its left |

If `has_tag` and the reviews were merged into one table `(media_id, tag_id, user_id)`, both
`media_id ↠ tag_id` and `media_id ↠ user_id` would hold with `media_id` not a key. That is the
cross product that Test 1 builds for comparison.

## 5. Tests

`sql/normalization_tests.sql` runs in a transaction and rolls back, so the data is unchanged.

| Test | Shows |
|---|---|
| T1 | combined table = 9 rows, ours = 6 |
| T2 | adding a vibe = 1 row |
| T3 | deleting reviews keeps the vibes |
| T4 | removing a vibe from one item keeps the tag |
| T5 | renaming a vibe changes 1 row |
| T6 | multi-vibe search has no duplicates |
| T7 | no data breaks a dependency |
| T8 | duplicate email is rejected |

The other test scripts check the DDL itself:

| Script | Shows | Expected result |
|---|---|---|
| `sql/check_tests.sql` | each CHECK constraint rejects bad data | 24 expected errors (22 × 3819, 1451, 1452) |
| `sql/fk_tests.sql` | every `ON DELETE` / `ON UPDATE` policy | 7 expected errors, then 19 counts equal to 0 |
| `sql/integrity_audit.sql` | no orphaned rows; each media item is in one child table | 24 rows, every `violations` is 0 |

## Known limitation

The database does not yet stop one media item from being in two child tables (e.g. `books`
and `movies`). This is not a normalisation issue, and `sql/integrity_audit.sql` reports such rows.
A trigger that refuses them is planned for next sprint.
