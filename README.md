# Media Tracker

A MySQL database that helps people find books, TV shows, movies, podcasts and songs based on a
"vibe" (tags) and what they have already consumed. Users can follow friends and join groups to get
recommendations from people they trust.

**Database:** MySQL 8.0.16 or newer (older versions silently ignore CHECK constraints).
Check yours with `SELECT VERSION();`

---

## Repo structure

```
media-tracker/
├── README.md
├── .gitignore
├── .github/
│   └── pull_request_template.md   <- checklist shown on every pull request
├── docs/
│   ├── erd/erd_full.png           <- the final ERD (core + ISA hierarchy)
│   └── normalisation.md           <- FDs, keys and BCNF check for all 16 tables
├── data/                          <- CSV files read by load_csv.sql
└── sql/
    ├── run_all.sql                <- rebuilds everything in the right order
    │
    │   ── LANE A: Schema ──────────────────────────────────────────
    ├── 00_setup.sql               <- CREATE DATABASE media_tracker
    ├── 00_drop_all.sql            <- drops all tables (clean slate)
    ├── 01_schema_users_groups.sql <- users, friends, user_groups, member_of
    ├── 02_schema_media.sql        <- media, books, tv_shows, movies, podcasts, songs, tag, has_tag
    ├── 03_schema_activity.sql     <- tracks, reviews, review_tags, recommends
    │
    │   ── LANE B: Rules & Operations ──────────────────────────────
    ├── 04_checks.sql              <- every CHECK constraint (17)
    ├── 06_crud_operations.sql     <- INSERT / UPDATE / DELETE on every table (rolls back)
    ├── 07_check_tests.sql         <- 22 tests proving the rules reject bad data
    │
    │   ── LANE C: Data & Queries ──────────────────────────────────
    ├── 05_seed_data.sql           <- sample users, media, tags, reviews, ...
    ├── 08_queries.sql             <- pick-a-vibe + recommendation queries
    ├── load_csv.sql               <- LOAD DATA LOCAL INFILE from ../data/*.csv
    └── alter_table.sql            <- ALTER TABLE demo: add a column, fill it, remove it
```

The number is the **run order**: tables must exist before checks are added, and checks must exist
before seed data goes in so the sample data is validated too.

---

## How to run it

**Option A: MySQL command line**
```bash
cd sql
mysql -u root -p
mysql> SOURCE run_all.sql;
```

**Option B: MySQL Workbench** (`SOURCE` is not supported there)
Open each file and run it (lightning bolt) in this order:
`00_setup` -> `00_drop_all` -> `01` -> `02` -> `03` -> `04` -> `05`,
then `06`, `07`, `08` whenever you want. Every script starts with `USE media_tracker;`.

`run_all.sql` can be re-run any time; it drops and rebuilds everything (so it **deletes data**).

| File | Safe to re-run on its own? |
|---|---|
| `00_setup`, `00_drop_all` | Yes (`00_drop_all` deletes data) |
| `01`, `02`, `03`, `04`, `05` | No. Run `00_drop_all` first |
| `06_crud_operations` | **Yes**, it rolls back and changes nothing |
| `07_check_tests` | **Yes**, it rolls back and changes nothing |
| `08_queries` | **Yes**, read-only |
| `alter_table` | **Yes**, it removes the column it adds |
| `load_csv` | **Yes**, rows already loaded are skipped. It **keeps** its data (media ids 101+) |

**Loading the CSV files.** `LOAD DATA LOCAL INFILE` is off by default at both ends:
```bash
cd sql
mysql --local-infile=1 -u root -p
mysql> SET GLOBAL local_infile = 1;
mysql> SOURCE load_csv.sql;
```
Run it after the seed data. Workbench instructions are at the top of `load_csv.sql`.

---

## Working together on GitHub (3 people)

Each person owns one **lane**, so you rarely edit the same file and rarely get merge conflicts.

| Lane | Owns | Job |
|---|---|---|
| **A: Schema** | `00_*`, `01`, `02`, `03` | Tables, keys, NOT NULL, UNIQUE. Changes here affect everyone, so tell the others. |
| **B: Rules & Operations** | `04_checks`, `06_crud_operations`, `07_check_tests` | The CHECK constraints plus insert/update/delete for every table. **Every CHECK you add gets a test.** |
| **C: Data & Queries** | `05_seed_data`, `08_queries`, `README`, `docs/` | Sample data, the recommendation queries, keeping the ERD image current. |

**Schema change checklist** (whoever changes a table or column):
a new column needs a CHECK if it has rules (04), a seed value (05), a CRUD example (06), a test (07), and
possibly a query (08). Open the pull request and tag the lane owners. The PR template walks you through it.

**Workflow**
1. `main` always runs cleanly with `run_all.sql`. Nobody pushes straight to it.
2. One branch per task: `schema/add-ratings`, `checks/review-length`, `data/more-podcasts`.
3. Open a pull request. A teammate pulls the branch and runs `SOURCE run_all.sql;` on a **fresh** database before approving.
4. Don't write patch/ALTER scripts for schema changes. Edit the `CREATE TABLE` in `01`-`03` and rebuild. (`alter_table.sql` is a demo that undoes itself, not a patch.)
5. Commit messages: short and specific, e.g. `Add CHECK: release_year between 1400 and 2100`.

**Conventions**
- `snake_case` names. Table names follow the ERD relationships (`has_tag`, `tracks`, `member_of`, `recommends`).
- CHECK names are `chk_<rule>` and must be unique across the whole database (MySQL rule).
- `05_seed_data.sql` assumes ids start at 1 on a fresh schema, so don't reorder its inserts casually.

---

## Design notes

- **Many-to-many** relationships (friends, member_of, has_tag, tracks, reviews, recommends) are link tables with composite primary keys.
- **Creates (many-to-one)** is the `user_groups.creator_id` column. It is `ON DELETE RESTRICT`: a user who still owns a group can't be deleted. Reassign the group first (`UPDATE user_groups SET creator_id = ...`) or delete the group. Ownership is never transferred automatically.
- **ISA hierarchy:** each child (`books`, `movies`, ...) uses `media_id` as PK and FK to `media`. Its generated `media_type` column plus a composite foreign key means a movie can't be inserted into `books`. **Never insert `media_type` into a child table.**
- **`review_tags`** is its own table because a review can have many tags. This is a BCNF decomposition; the full working is in `docs/normalisation.md`.
- **`password_hash`** holds a bcrypt/argon2 hash, never the plain password (seed values are fake placeholders).
- **`user_groups`** instead of `groups`, because `GROUPS` is a reserved word in MySQL 8.
- **Song length** is decimal minutes: `3.50` means 3 min 30 sec, not 3:50.
- **NULLs:** `release_year`, `director`, `page_count` etc. may be NULL (unknown). A NULL passes a CHECK; make the column `NOT NULL` if it must always be filled in.

## What changed from the first single-file version

| # | Problem | Fix |
|---|---|---|
| 1 | A movie could be inserted into `books` | Generated `media_type` + composite foreign key on every child table |
| 2 | Comment said CHECK can't be used with `ON DELETE CASCADE` (it can); triggers used instead | Replaced the two triggers with one `chk_no_self_follow` CHECK; comment corrected |
| 3 | Email check accepted `a@@b.c` and `a b@c.com` | Regex check |
| 4 | Deleting a user wiped their groups, members and recommendations | `creator_id` is `ON DELETE RESTRICT` |
| 5 | Sample hashes (`hash1`) too short for the hash-length rule | Longer placeholder hashes |
| 6 | Missing rules | Added username length, hash length, blank title / group name / review, lowercase tags, ISBN format |
| 7 | One big file, so merge conflicts | Split into lanes (this layout) |

## Known limits
- CHECK constraints can't compare across tables. Rules like "the group creator must be a member" need a trigger.
- Don't add `ON UPDATE CASCADE` to `friends`: MySQL won't allow a CHECK on a column whose foreign key uses it.
