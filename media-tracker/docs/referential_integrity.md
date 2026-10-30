# Referential integrity

This document lists every foreign key in `media_tracker` as a relational algebra constraint,
says in plain English what it prevents, and records the `ON DELETE` / `ON UPDATE` policy chosen
for it and why. The DDL is in `sql/schema_users_groups.sql`, `sql/schema_media.sql` and
`sql/schema_activity.sql`.

## 1. Why referential integrity matters

A foreign key promises that every reference points at a row that exists. Without that promise,
deleting or changing one row leaves other rows pointing at nothing (**orphans**): a track list
entry for a deleted user, an episode of a show that is gone, a group whose creator no longer
exists. Orphans are silent. A join drops them, so counts, recommendations and reports become
wrong without any error. Referential integrity makes the database refuse such a change (or
repair it) at the moment it happens, instead of relying on every query and every person to be
careful.

## 2. Notation

| Symbol | Meaning |
|---|---|
| `π_{A}(R)` | projection: the values of column(s) `A` in relation `R` |
| `σ_{cond}(R)` | selection: the rows of `R` that satisfy `cond` |
| `⊆`, `∪`, `∩`, `−` | subset, union, intersection, difference |
| `∅` | the empty set |

A foreign key from `C.a` to `P.b` is the constraint `π_{a}(C) ⊆ π_{b}(P)`. It can also be written
as a difference that must be empty, `π_{a}(C) − π_{b}(P) = ∅`: no value of `a` is missing from `P`.

## 3. Every foreign key (22)

| # | Relational algebra | What it prevents | ON DELETE | ON UPDATE |
|---|---|---|---|---|
| 1 | `π_{media_id}(books) ⊆ π_{media_id}(media)` | Every book is a media item: no `books` row without a `media` row. | **CASCADE** | RESTRICT |
| 2 | `π_{followed_id}(friends) ⊆ π_{user_id}(users)` | Every followed user is a real user. | **CASCADE** | RESTRICT |
| 3 | `π_{follower_id}(friends) ⊆ π_{user_id}(users)` | Every follower is a real user. No follow can come from a user who does not exist. | **CASCADE** | RESTRICT |
| 4 | `π_{media_id}(has_tag) ⊆ π_{media_id}(media)` | Only real media items carry tags. | **CASCADE** | RESTRICT |
| 5 | `π_{tag_id}(has_tag) ⊆ π_{tag_id}(tag)` | Only real tags are attached to media. | **RESTRICT** | RESTRICT |
| 6 | `π_{group_id}(member_of) ⊆ π_{group_id}(user_groups)` | Memberships only exist in real groups. | **CASCADE** | RESTRICT |
| 7 | `π_{user_id}(member_of) ⊆ π_{user_id}(users)` | Only real users can be group members. | **CASCADE** | RESTRICT |
| 8 | `π_{media_id}(movies) ⊆ π_{media_id}(media)` | Every movie is a media item. | **CASCADE** | RESTRICT |
| 9 | `π_{media_id}(podcast_episodes) ⊆ π_{media_id}(podcasts)` | Every podcast episode belongs to a real podcast. | **CASCADE** | RESTRICT |
| 10 | `π_{media_id}(podcasts) ⊆ π_{media_id}(media)` | Every podcast is a media item. | **CASCADE** | RESTRICT |
| 11 | `π_{group_id}(recommends) ⊆ π_{group_id}(user_groups)` | Only real groups make recommendations. | **CASCADE** | RESTRICT |
| 12 | `π_{media_id}(recommends) ⊆ π_{media_id}(media)` | Only real media items are recommended. | **CASCADE** | RESTRICT |
| 13 | `π_{tag_id}(review_tags) ⊆ π_{tag_id}(tag)` | Only real tags are attached to reviews. | **RESTRICT** | RESTRICT |
| 14 | `π_{user_id, media_id}(review_tags) ⊆ π_{user_id, media_id}(reviews)` | A tag can only be attached to a review that exists (the same user and the same media item). | **CASCADE** | RESTRICT |
| 15 | `π_{media_id}(reviews) ⊆ π_{media_id}(media)` | Only real media items are reviewed. | **CASCADE** | RESTRICT |
| 16 | `π_{user_id}(reviews) ⊆ π_{user_id}(users)` | Only real users write reviews. | **CASCADE** | RESTRICT |
| 17 | `π_{media_id}(songs) ⊆ π_{media_id}(media)` | Every song is a media item. | **CASCADE** | RESTRICT |
| 18 | `π_{media_id}(tracks) ⊆ π_{media_id}(media)` | Only real media items are tracked. | **CASCADE** | RESTRICT |
| 19 | `π_{user_id}(tracks) ⊆ π_{user_id}(users)` | Only real users have track lists. | **CASCADE** | RESTRICT |
| 20 | `π_{media_id}(tv_episodes) ⊆ π_{media_id}(tv_shows)` | Every TV episode belongs to a real TV show (not to a movie or a book). | **CASCADE** | RESTRICT |
| 21 | `π_{media_id}(tv_shows) ⊆ π_{media_id}(media)` | Every TV show is a media item. | **CASCADE** | RESTRICT |
| 22 | `π_{creator_id}(user_groups) ⊆ π_{user_id}(users)` | Every group has a creator who is a real user. `creator_id` is also `NOT NULL`, so a group has exactly one creator. | **RESTRICT** | RESTRICT |

## 4. Policies and why

| Policy | Foreign keys | Reason |
|---|---|---|
| `ON DELETE CASCADE` | 19 (everything not listed below) | The child row is meaningless without its parent: a track list entry without its user, an episode without its show, a book row without its media row. Deleting the parent removes the child, so no orphan can exist. Cascades chain: deleting a TV show media item removes its `tv_shows` row and then its `tv_episodes`. |
| `ON DELETE RESTRICT` | `user_groups.creator_id` (#22) | A group must always have a creator. Deleting the creator would either orphan the group or silently delete a group other people belong to. The user must reassign the group (`UPDATE user_groups SET creator_id = ...`) or delete it first. Ownership is never transferred automatically. |
| `ON DELETE RESTRICT` | `has_tag.tag_id`, `review_tags.tag_id` | Tags are a shared vocabulary. Deleting a tag that is in use would silently strip that vibe from every media item and review, so it is refused until nothing uses the tag. |
| `ON UPDATE RESTRICT` | all 22 | Every referenced key is an `AUTO_INCREMENT` surrogate id that never changes, so `ON UPDATE CASCADE` would never be needed. `RESTRICT` makes an accidental change of a referenced id fail loudly. If a table ever referenced a natural key (for example a username), `ON UPDATE CASCADE` would be the right choice there. |

Two MySQL facts shaped these choices:

- `ON DELETE SET NULL` cannot be used here. Every foreign key column is part of a primary key or
  is `NOT NULL`, and MySQL refuses it (error 1830).
- MySQL does not allow a `CHECK` on a column whose foreign key uses `ON UPDATE CASCADE` (error
  3823). `friends` has `chk_no_self_follow` on its foreign key columns, so `ON UPDATE RESTRICT`
  keeps all 22 foreign keys consistent and compatible with the `CHECK`.

## 5. From relational algebra to SQL

The constraint `π_{creator_id}(user_groups) − π_{user_id}(users) = ∅` says that no group
has a creator who is missing from `users`. As a query, it finds the child rows that have no
parent, by joining each `user_groups` row to its creator and keeping the ones that found none:

```sql
SELECT g.creator_id
FROM user_groups g
LEFT JOIN users u ON u.user_id = g.creator_id
WHERE u.user_id IS NULL;      -- the constraint holds when this returns no rows
```

`sql/integrity_audit.sql` runs this pattern for all 22 foreign keys, and counts the rows each
time. Every count must be 0.

## 6. Other constraints in relational algebra

| Relational algebra | Plain English | Enforced by |
|---|---|---|
| `σ_{follower_id = followed_id}(friends) = ∅` | Nobody follows themselves. | `CHECK` `chk_no_self_follow` |
| `σ_{page_count ≤ 0}(books) = ∅` | No book has zero or negative pages. A `NULL` page count is unknown, not a violation. | `CHECK` `chk_page_count` |
| `σ_{media_status ∉ {'want_to_consume','in_progress','finished','dropped'}}(tracks) = ∅` | A track entry only has one of the four allowed statuses. | `CHECK` `chk_media_status` |
| `π_{media_id}(media) ⊆ π_{media_id}(books) ∪ π_{media_id}(tv_shows) ∪ π_{media_id}(movies) ∪ π_{media_id}(podcasts) ∪ π_{media_id}(songs)` | Every media item is in some child table. | `integrity_audit.sql` only |
| `π_{media_id}(books) ∩ π_{media_id}(movies) = ∅`, and the same for the other nine pairs of child tables | No media item is in two child tables. | `integrity_audit.sql` only |

The last two cannot be declared in MySQL: a `CHECK` cannot compare two tables, and a foreign
key only points from a child to its parent. They are rules for whoever enters data, and the
audit proves they hold.

## 7. How to verify

From `media-tracker/sql`, after `seed_data.sql` (or `run_all.sql`):

| Script | What you should see |
|---|---|
| `integrity_audit.sql` | 24 rows (22 foreign keys plus two checks on the media child tables), every `violations` value `0`. |
| `fk_tests.sql` (run with `mysql --force`) | 7 expected errors (four `1451` refusals: RESTRICT deletes and ON UPDATE RESTRICT; three `1452` rejected references), then 19 count rows where `rows_left` equals `expected` (`0`). |

Run `integrity_audit.sql` again after `fk_tests.sql`: it must still be all zeros, which shows the
tests left no orphaned rows behind.
