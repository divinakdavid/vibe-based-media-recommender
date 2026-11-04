# Minimal basis

**Result:** the FDs of all 18 tables reduce to a minimal basis of **28 FDs**. Every left side in it is a
declared `PRIMARY KEY` or `UNIQUE`, and 3NF synthesis from the basis gives back the same 18 tables.
**Evidence:** `sql/minimal_basis_tests.sql` (23 checks, all `PASS`).

The FDs come from the table in section 1 of `normalisation.md`.

## 1. What a minimal basis is

A set of FDs `B` is a minimal basis for `F` when `B` implies exactly the same FDs as `F` and:

1. every right side is a single attribute;
2. no FD can be removed (otherwise it was implied by the others);
3. no attribute can be removed from a left side.

It is computed in three steps:

| Step | Do | Test for `X → A` |
|---|---|---|
| 1 | Split every right side into single attributes | — |
| 2 | Remove extra attributes from left sides | `B` in `X` is extra if `A ∈ (X − B)⁺` |
| 3 | Remove redundant FDs | `X → A` is redundant if `A ∈ X⁺` computed without `X → A` |

Step 2 comes before step 3. In the other order, shortening a left side in step 2 can make another FD
redundant after step 3 has already finished.

**One FD set per table.** Column names repeat across tables with different meanings (`director` is in
`tv_shows` and `movies`, `duration_minutes` is in four tables, `title` is in `media` and both episode
tables), so each table's FDs are minimized on their own.

## 2. Worked examples

### `users`: steps 1 and 3

`user_id`, `username` and `email` are all keys, so each one determines every other column:

```
F = { user_id  → username, email, password_hash
      username → user_id,  email, password_hash
      email    → user_id,  username, password_hash }
```

**Step 1** splits these into 9 FDs. **Step 2** has nothing to do, because every left side is one attribute.

**Step 3** removes the FDs that follow through `user_id`:

| FD | Still follows from the other FDs | Has the right side? | Action |
|---|---|---|---|
| `username → email` | `username → user_id → email` | yes | remove |
| `username → password_hash` | `username → user_id → password_hash` | yes | remove |
| `email → username` | `email → user_id → username` | yes | remove |
| `email → password_hash` | `email → user_id → password_hash` | yes | remove |

The 5 FDs that are left are all needed:

| FD | Closure of the left side without this FD | Has the right side? |
|---|---|---|
| `user_id → username` | `{user_id}⁺ = {user_id, email, password_hash}` | no, keep |
| `user_id → email` | `{user_id}⁺ = {user_id, username, password_hash}` | no, keep |
| `user_id → password_hash` | `{user_id}⁺ = {user_id, username, email}` | no, keep |
| `username → user_id` | `{username}⁺ = {username}` | no, keep |
| `email → user_id` | `{email}⁺ = {email}` | no, keep |

**A minimal basis is not unique.** Removing FDs in a different order can give the cycle

```
user_id → username,  username → email,  email → user_id,  user_id → password_hash
```

which is also a minimal basis, with only 4 FDs. Each key still reaches every column (for example
`username → email → user_id → password_hash`), and removing any one FD loses something. We keep the 5-FD
version, because its left sides are exactly the keys the schema declares (`PRIMARY KEY (user_id)`,
`UNIQUE (username)`, `UNIQUE (email)`), so each FD maps onto one constraint.

### `books`: step 3

```
F = { media_id → author, isbn, page_count
      isbn     → media_id, author, page_count }
```

Step 1 gives 6 FDs. In step 3, `isbn → author` and `isbn → page_count` are redundant, because
`isbn → media_id → author` and `isbn → media_id → page_count`. The other 4 are needed: `media_id → isbn`
is the only way to reach `isbn`, and without `isbn → media_id`, `{isbn}⁺ = {isbn}`.

`isbn` can be `NULL` (a book without an ISBN), and `UNIQUE` allows many `NULL`s, so `isbn → media_id`
holds for every book that has an ISBN.

### `tv_episodes`: step 2 finds nothing

```
F = { (media_id, season_number, episode_number) → title, duration_minutes }
```

Step 1 gives 2 FDs. Step 2 tries dropping each attribute of the left side. Neither `title` nor
`duration_minutes` appears on any left side, so each shorter left side's closure is just itself:

| Drop | Shorter left side | Its closure has `title`? | In words |
|---|---|---|---|
| `episode_number` | `(media_id, season_number)` | no | a season has many episodes |
| `season_number` | `(media_id, episode_number)` | no | every season has an episode 1 |
| `media_id` | `(season_number, episode_number)` | no | every show has a season 1, episode 1 |

The same holds for `duration_minutes`, so all three attributes stay. Step 3 removes nothing, since these
are the only FDs that reach `title` and `duration_minutes`. `podcast_episodes`, `tracks` and `reviews`
work the same way: no part of their composite key can be dropped.

### `review_flat`: step 2 removes an attribute

Section 2 of `normalisation.md` starts from one flat table:

```
review_flat (user_id, media_id, tag_id, user_review)       key: (user_id, media_id, tag_id)
```

Listing FDs from the key gives

```
F = { (user_id, media_id, tag_id) → user_review
      (user_id, media_id)         → user_review }
```

Step 2 on the first FD: `{user_id, media_id}⁺` already contains `user_review`, so `tag_id` is extra. The
first FD becomes a copy of the second, and step 3 removes the copy. The minimal basis is
`{ (user_id, media_id) → user_review }`. Its left side is not a key of `review_flat`, which is the BCNF
violation that led us to split it into `reviews` and `review_tags`. After the split, that left side is the
key of `reviews`.

## 3. The minimal basis for all 18 tables

| Table | Minimal basis | FDs |
|---|---|---|
| `users` | `user_id → username`, `user_id → email`, `user_id → password_hash`, `username → user_id`, `email → user_id` | 5 |
| `friends` | none (the whole table is the key) | 0 |
| `user_groups` | `group_id → group_name`, `group_id → creator_id` | 2 |
| `member_of` | none | 0 |
| `media` | `media_id → title`, `media_id → release_year`, `media_id → summary` | 3 |
| `books` | `media_id → author`, `media_id → isbn`, `media_id → page_count`, `isbn → media_id` | 4 |
| `tv_shows` | `media_id → director` | 1 |
| `movies` | `media_id → director`, `media_id → duration_minutes` | 2 |
| `podcasts` | `media_id → host` | 1 |
| `songs` | `media_id → artist`, `media_id → duration_minutes` | 2 |
| `tv_episodes` | `(media_id, season_number, episode_number) → title`, `… → duration_minutes` | 2 |
| `podcast_episodes` | `(media_id, episode_number) → title`, `… → duration_minutes` | 2 |
| `tag` | `tag_id → name`, `name → tag_id` | 2 |
| `has_tag` | none | 0 |
| `tracks` | `(user_id, media_id) → media_status` | 1 |
| `reviews` | `(user_id, media_id) → user_review` | 1 |
| `review_tags` | none | 0 |
| `recommends` | none | 0 |
| **Total** | | **28** |

The basis has 17 different left sides, and every one is a `PRIMARY KEY` or `UNIQUE` (test T2a), so MySQL
enforces every FD in it.

**Not in the basis: `title → media_id`.** A novel and its film adaptation can share a title, and this
database stores both, so a title does not identify one media item. The schema does not declare `title`
unique (test T2b). Query 4 in `sfw_queries.sql` still checks the current data for duplicate titles.

## 4. 3NF synthesis gives back the same tables

The 3NF synthesis algorithm builds one table per left side `X` in the minimal basis, holding `X` and
everything `X` determines. It then drops any table contained in another, and adds a key table if no table
contains a key.

- `users`: `(user_id, username, email, password_hash)`, `(username, user_id)` and `(email, user_id)`. The
  last two are inside the first, so the result is `users`.
- `books`: `(media_id, author, isbn, page_count)` and `(isbn, media_id)`. The second is inside the first.
- `tag`: `(tag_id, name)` and `(name, tag_id)` are the same table.
- Tables with one left side give exactly one table: themselves.
- The five tables with an empty basis get the key table, which is the whole table.

The result is the same 18 tables, so no table needs to be split. This matches the BCNF result in
`normalisation.md`.

## 5. Tests

`sql/minimal_basis_tests.sql` runs in a transaction and rolls back, so the data is unchanged. From the
`sql` folder:

```bash
mysql -t -u root -p < minimal_basis_tests.sql
```

| Test | Shows | Expected |
|---|---|---|
| T1 (13 rows) | every FD in the basis holds in the data, one row per table with FDs | 0 violations each |
| T2a | each of the 17 left sides is a `PRIMARY KEY` or `UNIQUE` index (read from `information_schema`) | 17 of 17 |
| T2b | `title` is not declared unique | 0 |
| T3a–T3d | after adding rows the schema accepts, every shorter left side is broken but the full FD still holds (14 shorter FDs) | all broken, full FD 0 |
| T4a–T4c | MySQL rejects rows that would break `isbn → media_id`, `name → tag_id` and `(user_id, media_id) → media_status` | 0 rows, error 1062 |
| T5 | nothing is left behind after `ROLLBACK` | 0 |
