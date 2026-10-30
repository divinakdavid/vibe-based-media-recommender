# Sprint 3 plan: advanced SQL and measurable goals

This is a **plan**. Files marked *(planned)* do not exist yet; everything else already runs
in the repository. Every goal below has an **objective measure**: a script that prints a
`PASS` / `FAIL` row (or a number) so anyone can check it without reading our code.

All planned checks live in one script, `sql/sprint3_tests.sql` *(planned)*, which prints one row
per check: `test | expected | actual | result`. **Success criterion for the sprint: every row is `PASS`
and `sql/integrity_audit.sql` still shows 24 rows of 0.**

## 1. Goals, competencies and how each is measured

| # | Goal | Competency it shows | Objective measure (pass criterion) | Evidence |
|---|---|---|---|---|
| G0 | The submitted code reproduces everything we present | Delivery | A fresh `git clone`, then `SOURCE run_all.sql;`, prints **0 `ERROR` lines**, and `git status` lists **no untracked file** in `media-tracker/sql` | the clone-and-run check |
| G1 | Aggregation with `GROUP BY` and `HAVING` | Aggregation | 3 queries return exactly the expected rows (section 2, A1 to A3) | `sprint3_tests.sql` *(planned)* |
| G2 | Nested subqueries: scalar, `IN` / `NOT IN`, correlated `EXISTS` | Nested subqueries | 3 queries return exactly the expected rows (N1 to N3) | `sprint3_tests.sql` |
| G3 | Data changes with complex predicates (compound `AND` / `OR` plus a subquery) | Complex-predicate DML | 2 statements change exactly the expected number of rows (D1, D2), checked with `ROW_COUNT()` inside a transaction that is rolled back, so the database ends unchanged | `sprint3_tests.sql` |
| G4 | Rewrite subqueries as joins, including `LEFT JOIN … IS NULL` | Subquery-to-join | For each of N1 and N2, the join version returns a result **identical** to the subquery version: 0 rows in either difference (J1, J2) | `sprint3_tests.sql` |
| G5 | Triggers that enforce "one child table per media item" | Procedural integrity | A row that puts a movie into `books` is refused with error 1644, **and** `integrity_audit.sql` still reports 0 for "media in two or more child tables"; a valid row is accepted | `sprint3_tests.sql`, `integrity_audit.sql` |
| G6 | Stored procedure `add_media()` that inserts a media row and its child row together | Procedures and DML | After `CALL add_media('podcast', …)`: `media_with_type` gains **exactly 1 row** of the right type, the audit stays 0; a call with an invalid type raises an error and the row counts do **not** change | `sprint3_tests.sql` |
| G7 | Indexes, measured with `EXPLAIN` | Performance | On a 20,000-row test load (below): the access `type` changes from `ALL` to `ref` or `range`, the estimated `rows` drops by **at least 90%**, and `EXPLAIN ANALYZE` actual time drops by **at least 50%** | `sprint3_explain.sql` *(planned)* |
| G8 | The documents match the DDL | Documentation | A check compares every table and primary key in `normalisation.md` with `information_schema`: **0 mismatches** over 18 tables | the doc-versus-DDL check |

## 2. Expected results (computed on the current sample data)

These are the real outputs of the queries on `seed_data.sql`, so each check is a fixed target.

| Check | Query idea | Expected result |
|---|---|---|
| A1 | tags used by at least 3 media items (`GROUP BY` tag, `HAVING COUNT(*) >= 3`) | `melancholy` 5, `mystery` 4, `dark academia` 3 (3 rows) |
| A2 | media items per type (`GROUP BY media_type` on `media_with_type`) | book 1, movie 2, podcast 1, song 2, tv_show 1 (5 rows) |
| A3 | groups with at least 3 members (`HAVING COUNT(*) >= 3`) | `Spooky Season Club`, 3 members (1 row) |
| N1 | media nobody tracks (`NOT IN (SELECT media_id FROM tracks)`) | media_id 4, 5, 6, 7 (4 rows) |
| N2 | users who review something they also track (correlated `EXISTS`) | `muskan` (1 row) |
| N3 | media released after the average year (scalar subquery) | media_id 1, 2, 3, 4, 6 (5 rows) |
| J1 | N1 rewritten as `LEFT JOIN … WHERE t.media_id IS NULL` | the same 4 rows as N1 |
| J2 | N2 rewritten with `JOIN` and `DISTINCT` | the same 1 row as N2 |
| L1 | media with no review (`LEFT JOIN … IS NULL`) | media_id 2, 3, 4, 5, 6, 7 (6 rows) |
| D1 | `UPDATE tracks SET media_status = 'dropped' WHERE media_status = 'want_to_consume' AND media_id IN (SELECT media_id FROM has_tag WHERE tag_id = 2)` | 1 row affected |
| D2 | `DELETE FROM has_tag WHERE media_id IN (SELECT media_id FROM books)` | 3 rows affected |

## 3. How the Sprint 3 features map onto the competencies

| Feature we plan to use | Competency | Where it is shown and checked |
|---|---|---|
| `GROUP BY`, `HAVING`, `COUNT`, `AVG` | Aggregation | A1, A2, A3 |
| subqueries in `WHERE` (`IN`, `NOT IN`, `EXISTS`, scalar) | Nested subqueries | N1, N2, N3 |
| `UPDATE` / `DELETE` with `AND`, `OR` and `IN (SELECT …)` | Complex-predicate DML | D1, D2 |
| `LEFT JOIN … IS NULL`, `JOIN` + `DISTINCT` | Subquery-to-join | J1, J2 (identical results to N1, N2), L1 |
| `BEFORE INSERT` triggers | Procedural integrity | G5 tests and the audit |
| `add_media()` | Stored procedure with DML | G6 tests |
| `CREATE INDEX` + `EXPLAIN` / `EXPLAIN ANALYZE` | Performance | G7 numbers |

## 4. How we will measure G7 (indexes)

A table with 3 rows shows nothing in `EXPLAIN`, so G7 uses a generated test load of **20,000
media rows** (a recursive query in `sprint3_explain.sql`, in a separate test database, so the
real data is untouched). For each target query we record `type`, `key` and `rows` from
`EXPLAIN`, and the actual time from `EXPLAIN ANALYZE`, **before and after** `CREATE INDEX`.

We tried this on a scratch table to confirm the thresholds are realistic. The query
`SELECT title FROM media_big WHERE release_year = 2019`:

| | `type` | `key` | estimated `rows` | actual time |
|---|---|---|---|---|
| before the index | `ALL` | none | 20,000 | 3.5 ms |
| after `CREATE INDEX` on `release_year` | `ref` | the new index | 158 | 0.25 ms |

That is a 99% drop in estimated rows and a 93% drop in time, comfortably past the 90% and 50%
thresholds. The same before-and-after table will be produced for the real target queries
(`has_tag.tag_id`, `tracks.media_status`, `media.release_year`).

## 5. Definition of done

1. `sprint3_tests.sql` prints only `PASS` rows (G1 to G6).
2. `sprint3_explain.sql` meets the G7 thresholds for every target query.
3. `integrity_audit.sql` still shows 24 rows of 0.
4. A fresh clone runs `run_all.sql` with no errors, and `git status` is clean (G0).
5. The doc-versus-DDL check reports 0 mismatches (G8).
