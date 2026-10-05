# Normalisation

This document lists the functional dependencies (FDs) and candidate keys of every table in
`media_tracker` and checks each table against Boyce-Codd Normal Form (BCNF).

**Result:** all 16 tables are in BCNF. One table, `review_tags`, exists because of a BCNF
decomposition, shown in [section 3](#3-the-decomposition-reviews-and-review_tags). The five
ISA child tables carry one generated column that needs a short explanation, given in
[section 4](#4-the-generated-media_type-column).

## 1. Method

A table is in BCNF when, for every non-trivial FD `X → Y` that holds on it, `X` is a superkey.

For each table we:

1. list the candidate keys, taken from the `PRIMARY KEY` and `NOT NULL UNIQUE` declarations in
   the schema files;
2. list every non-trivial FD that the business rules imply, including FDs that are *not*
   enforced by a key, since those are the ones that would break BCNF;
3. check that every determinant is a superkey.

Two points apply to every table:

- **1NF.** Every column holds a single atomic value. The only multi-valued attribute on the
  ERD, a review's tags, was moved to its own table (section 3).
- **CHECK constraints are not FDs.** A rule such as `episode_count >= season_count` limits
  which values may appear together, but knowing one value does not determine the other, so
  it has no effect on the normal form.

Notation: `A, B → C` means the pair (A, B) determines C. In the attribute lists,
primary-key columns are in **bold** and generated columns are in *italics*.

## 2. Table-by-table check

### 2.1 People

#### `users` (**user_id**, username, email, password_hash)

| | |
|---|---|
| Candidate keys | `{user_id}`, `{username}`, `{email}` |
| FDs | `user_id → username, email, password_hash` |
| | `username → user_id, email, password_hash` |
| | `email → user_id, username, password_hash` |
| BCNF | Yes. All three determinants are candidate keys. |

`password_hash` determines nothing: two users may by chance share a hash, and nothing in the
design relies on hashes being distinct.

#### `friends` (**follower_id**, **followed_id**)

| | |
|---|---|
| Candidate keys | `{follower_id, followed_id}` |
| FDs | None that are non-trivial. A follower can follow many users and a user can have many followers, so neither column determines the other. |
| BCNF | Yes. An all-key table has no non-trivial FDs to violate it. |

#### `user_groups` (**group_id**, group_name, creator_id)

| | |
|---|---|
| Candidate keys | `{group_id}` |
| FDs | `group_id → group_name, creator_id` |
| BCNF | Yes. |

FDs that do **not** hold: `group_name → group_id` (two groups may share a name) and
`creator_id → group_id` (a user may create many groups).

#### `member_of` (**group_id**, **user_id**)

| | |
|---|---|
| Candidate keys | `{group_id, user_id}` |
| FDs | None that are non-trivial. |
| BCNF | Yes, all-key. |

### 2.2 Media

#### `media` (**media_id**, title, release_year, summary, media_type)

| | |
|---|---|
| Candidate keys | `{media_id}` |
| FDs | `media_id → title, release_year, summary, media_type` |
| BCNF | Yes. |

`UNIQUE (media_id, media_type)` is a superkey, not a second candidate key: it contains
`media_id`, so it is not minimal. It is declared only so the child tables can reference it.

FDs that do **not** hold: `title → ...` (remakes and unrelated works share titles, and the same
title can exist as a book and a movie) and `title, release_year → ...` (nothing stops two
different works sharing both).

#### `books` (**media_id**, author, isbn, page_count, *media_type*)

| | |
|---|---|
| Candidate keys | `{media_id}`; `{isbn}` wherever an ISBN is recorded |
| FDs | `media_id → author, isbn, page_count` |
| | `isbn → media_id, author, page_count` |
| BCNF | Yes. Both determinants are unique in the table. |

`isbn` is `UNIQUE` but nullable, because some books have no ISBN. It therefore cannot be the
primary key, but among the rows that have one it identifies exactly one row, so the FD it
heads does not break BCNF. `author` determines nothing: one author writes many books.

*media_type* is discussed in section 4, and the same applies to the next four tables.

#### `tv_shows` (**media_id**, director, episode_count, season_count, *media_type*)

| | |
|---|---|
| Candidate keys | `{media_id}` |
| FDs | `media_id → director, episode_count, season_count` |
| BCNF | Yes. |

`season_count` does not determine `episode_count` or the reverse.

#### `movies` (**media_id**, director, duration_minutes, *media_type*)

| | |
|---|---|
| Candidate keys | `{media_id}` |
| FDs | `media_id → director, duration_minutes` |
| BCNF | Yes. |

#### `podcasts` (**media_id**, episode_count, *media_type*)

| | |
|---|---|
| Candidate keys | `{media_id}` |
| FDs | `media_id → episode_count` |
| BCNF | Yes. |

#### `songs` (**media_id**, artist, duration_minutes, *media_type*)

| | |
|---|---|
| Candidate keys | `{media_id}` |
| FDs | `media_id → artist, duration_minutes` |
| BCNF | Yes. |

#### `tag` (**tag_id**, name)

| | |
|---|---|
| Candidate keys | `{tag_id}`, `{name}` |
| FDs | `tag_id → name` and `name → tag_id` |
| BCNF | Yes. Both determinants are candidate keys. |

#### `has_tag` (**media_id**, **tag_id**)

| | |
|---|---|
| Candidate keys | `{media_id, tag_id}` |
| FDs | None that are non-trivial. |
| BCNF | Yes, all-key. |

### 2.3 Activity

#### `tracks` (**user_id**, **media_id**, media_status)

| | |
|---|---|
| Candidate keys | `{user_id, media_id}` |
| FDs | `user_id, media_id → media_status` |
| BCNF | Yes. |

There is no partial dependency. The status belongs to the pair: the same user has different
statuses for different media (`user_id ↛ media_status`), and the same media item has different
statuses for different users (`media_id ↛ media_status`).

#### `reviews` (**user_id**, **media_id**, user_review)

| | |
|---|---|
| Candidate keys | `{user_id, media_id}` |
| FDs | `user_id, media_id → user_review` |
| BCNF | Yes, by the same argument as `tracks`. |

#### `review_tags` (**user_id**, **media_id**, **tag_id**)

| | |
|---|---|
| Candidate keys | `{user_id, media_id, tag_id}` |
| FDs | None that are non-trivial. |
| BCNF | Yes, all-key. |

#### `recommends` (**group_id**, **media_id**)

| | |
|---|---|
| Candidate keys | `{group_id, media_id}` |
| FDs | None that are non-trivial. |
| BCNF | Yes, all-key. |

### 2.4 Summary

| Table | Candidate key(s) | Non-trivial FDs | Normal form |
|---|---|---|---|
| `users` | `user_id`; `username`; `email` | each key → all other columns | BCNF |
| `friends` | `(follower_id, followed_id)` | none | BCNF |
| `user_groups` | `group_id` | `group_id → group_name, creator_id` | BCNF |
| `member_of` | `(group_id, user_id)` | none | BCNF |
| `media` | `media_id` | `media_id → title, release_year, summary, media_type` | BCNF |
| `books` | `media_id`; `isbn` | each key → all other columns | BCNF |
| `tv_shows` | `media_id` | `media_id → director, episode_count, season_count` | BCNF |
| `movies` | `media_id` | `media_id → director, duration_minutes` | BCNF |
| `podcasts` | `media_id` | `media_id → episode_count` | BCNF |
| `songs` | `media_id` | `media_id → artist, duration_minutes` | BCNF |
| `tag` | `tag_id`; `name` | `tag_id → name`; `name → tag_id` | BCNF |
| `has_tag` | `(media_id, tag_id)` | none | BCNF |
| `tracks` | `(user_id, media_id)` | `user_id, media_id → media_status` | BCNF |
| `reviews` | `(user_id, media_id)` | `user_id, media_id → user_review` | BCNF |
| `review_tags` | `(user_id, media_id, tag_id)` | none | BCNF |
| `recommends` | `(group_id, media_id)` | none | BCNF |

## 3. The decomposition: `reviews` and `review_tags`

On the ERD, the *Reviews* relationship between Users and Media has two attributes: the review
text, and a **multi-valued** set of tags the reviewer attached.

**Step 1: flatten to 1NF.** A multi-valued attribute cannot be stored in one column, so the
direct translation repeats the review once per tag:

```
review_flat (user_id, media_id, tag_id, user_review)
key: (user_id, media_id, tag_id)
```

| user_id | media_id | tag_id | user_review |
|---|---|---|---|
| 1 | 1 | 1 (dark academia) | Obsessed. Reread every autumn. |
| 1 | 1 | 4 (melancholy) | Obsessed. Reread every autumn. |

**Step 2: find the violation.** Two dependencies hold on `review_flat`:

- `user_id, media_id, tag_id → user_review` (the key)
- `user_id, media_id → user_review` (a user writes one review per media item)

The second determinant, `(user_id, media_id)`, is not a superkey: it does not determine
`tag_id`. That violates BCNF. Because the determinant is a proper subset of the key, it is a
partial dependency, so the table is not even in 2NF.

The anomalies are visible in the two rows above:

- **Update:** editing the review means changing every copy. Miss one and the same review has
  two different texts.
- **Insert:** a review with no tags cannot be stored, because `tag_id` is part of the primary
  key and cannot be NULL.
- **Delete:** removing the last tag from a review deletes the review text with it.

**Step 3: decompose on the violating FD.** Splitting on `user_id, media_id → user_review` gives:

```
reviews     (user_id, media_id, user_review)      key: (user_id, media_id)
review_tags (user_id, media_id, tag_id)           key: (user_id, media_id, tag_id)
```

These are the two tables in `schema_activity.sql`.

**Step 4: check the decomposition.**

- **Both tables are in BCNF** (section 2.3).
- **Lossless join.** The shared columns are `(user_id, media_id)`, which is the key of
  `reviews`. Joining the two tables on those columns returns exactly the rows of `review_flat`
  and no extra ones.
- **Dependency preserving.** The only non-trivial FD, `user_id, media_id → user_review`, sits
  entirely inside `reviews` and is enforced by its primary key.
- **Anomalies gone.** The review text is stored once, a review can exist with zero tags, and
  deleting tags never deletes the review.

The foreign key `review_tags (user_id, media_id) → reviews (user_id, media_id)` keeps the two
halves consistent: a tag cannot be attached to a review that does not exist, and
`ON DELETE CASCADE` removes a review's tags with the review.

## 4. The generated `media_type` column

Each ISA child table (`books`, `tv_shows`, `movies`, `podcasts`, `songs`) has a `media_type`
column that always holds the same value, for example `'book'` in every row of `books`.

Read strictly, a column that is constant satisfies the FD `∅ → media_type`, and the empty set
is not a superkey. We do not count this as a BCNF violation, for two reasons:

- **It is not stored data.** The column is declared `AS ('book') STORED`. MySQL computes it,
  and it cannot be inserted or updated. Normal forms exist to prevent update anomalies in data
  that users maintain, and this column cannot be made inconsistent.
- **It is there to enforce a constraint.** The composite foreign key
  `(media_id, media_type) → media (media_id, media_type)` is what stops a movie being inserted
  into `books`. Removing the column would keep the tables in BCNF but lose that guarantee.

Leaving the generated column aside, every child table is `media_id →` its own attributes, which
is BCNF.

## 5. Design choices that keep the schema normalised

- **Many-to-many relationships are link tables** (`friends`, `member_of`, `has_tag`,
  `recommends`, `tracks`, `reviews`) keyed on the pair of ids, so no entity table repeats rows.
- **The many-to-one *Creates* relationship is a single column**, `user_groups.creator_id`.
  It depends on the whole key `group_id`, so it adds no new FD.
- **Type-specific attributes live in the ISA child tables.** A single wide `media` table would
  still be in BCNF, but most columns would be NULL in most rows (`isbn` for a song,
  `season_count` for a book).
- **`has_tag` and `review_tags` are independent facts.** `has_tag` records the tags on a media
  item. `review_tags` records the tags one reviewer chose for it. A reviewer may use a tag the
  media item does not carry, so neither table can be derived from the other and there is no
  redundancy between them.
- **Nothing derived is stored.** Counts such as "number of shared tags" are computed in
  `queries.sql`, not kept in a column.
