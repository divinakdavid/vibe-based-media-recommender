# ERD design audit

This audit evaluates our **original Sprint 1 ERD** (`erd/erd_sprint1.png`) against the eight design
criteria from the lecture *Improving Conceptual Designs* (Batini et al., 1992, ch. 6): completeness,
correctness, minimality, expressiveness, readability, self-explanation, extensibility and
normality. The weaknesses it finds are the reasons for the changes in the final ERD
(`erd/erd_full.png`), which is described and re-scored in sections 3 and 4.

Scores are out of 5 and are our own judgment, not a course rubric.

## 1. Scorecard of the original ERD: 29 / 40

| Criterion | Score | What we found in the original ERD |
|---|---|---|
| **Completeness** | 5/5 | Every requirement is represented: finding media by vibe (`Tag`, `Has tag`), by history (`Tracks`, `Reviews`), following friends (`Friends`), groups that recommend media (`Groups`, `Member of`, `Creates`, `Recommends`) and the five media types (ISA). |
| **Correctness** | 3/5 | Two errors. (a) `review_tags` is drawn as an attribute of `Reviews`, but it holds a set of tags, which is a relationship to the `Tag` entity set: the "attribute instead of entity set" error. (b) `isbn` is underlined on `Books`, but a subset takes its identifier from its parent. |
| **Minimality** | 2/5 | Four attributes can be computed from other data (section 2), and `Media` is drawn twice (once with its attributes, once as the root of the ISA), so an element appears more than once. |
| **Expressiveness** | 4/5 | Episodes exist only as counts, so the diagram cannot say anything about an individual episode. `director` is repeated on `TV shows` and `Movies`. |
| **Readability** | 3/5 | `Media` is drawn twice, the ISA subsets sit beside their parent instead of beneath it, and the `Recommends` line wraps around the whole diagram. |
| **Self-explanation** | 3/5 | There is no legend, and the `review_tags` oval is ambiguous (is it a list? a relationship?). |
| **Extensibility** | 4/5 | A new media type is one new subset, but adding episode-level detail would need a redesign. |
| **Normality** | 5/5 | All 16 tables of the Sprint 1 schema are in BCNF. |

## 2. Redundant attributes in the original ERD

An attribute is redundant when its value can be **computed from other stored data**, or when **the
same fact is stored twice**. Four were found.

| Attribute | Why it is redundant | The information is still available as |
|---|---|---|
| `Media.media_type` | Every media item is in one child table, so its type is simply the table that holds its row. A stored copy can be changed without moving the row. | The view `media_with_type`, computed from the child tables. |
| `TV shows.episode_count` | The number of `TV Episodes` rows for the show. | `COUNT` over `tv_episodes` (`queries_stretch.sql`). |
| `TV shows.season_count` | The number of distinct seasons among the show's episodes. | `COUNT(DISTINCT season_number)` over `tv_episodes`. |
| `Podcasts.episode_count` | The number of `Podcast Episodes` rows. | `COUNT` over `podcast_episodes`. |

All other attributes were checked and none is derivable. Repeated attribute *names* are not
duplicated facts: `director` appears on `TV shows` and `Movies`, but each media item is in only
one child table, so no item is both a show and a movie; `duration_minutes` describes a film, a
track or an episode in different tables; an episode `title` is not the title of its show.

## 3. Changes made, and where they show up

| Weakness found | Change in the final ERD | Code and documents affected |
|---|---|---|
| Four derived attributes | Removed. The media type comes from the child table; counts come from the episodes. | `schema_media.sql` (no `media_type` column, view `media_with_type`), `queries*.sql`, `load_csv.sql`, `media.csv` |
| Episodes only as counts | `TV Episodes` and `Podcast Episodes` are weak entity sets, joined to their show by a double diamond. | tables `tv_episodes`, `podcast_episodes` in `schema_media.sql`; `normalisation.md` |
| `Podcasts` left with no attribute | Gains a `host` attribute. | `podcasts.host` in `schema_media.sql`, `seed_data.sql`, `crud_operations.sql` |
| `review_tags` oval | `Review` is a weak entity set (identified by its user and its media item), related to `Tag` by `Tagged with`. | Tables `reviews` and `review_tags` already matched; comments in `schema_activity.sql`; `normalisation.md` section 2 |
| `isbn` underlined on a subset | No longer underlined. It stays `UNIQUE` in the SQL. | none |
| `Media` drawn twice | Drawn once, in a single connected diagram. | `erd_full.png` |
| Subsets beside their parent | Subsets and episodes are drawn beneath their parent. | `erd_full.png` |
| Every foreign key had the default policy | (not an ERD change) explicit `ON DELETE` / `ON UPDATE` policies. | `docs/referential_integrity.md`, `schema_*.sql` |

## 4. Re-score of the final ERD: 36 / 40

| Criterion | Original | Final | Why |
|---|---|---|---|
| Completeness | 5 | 5 | Still complete, now with individual episodes. |
| Correctness | 3 | 5 | Tags are a relationship to `Tag`; subsets carry no identifier of their own; weak entity notation follows the course (double rectangle, double diamond, arrow at the supporting entity). |
| Minimality | 2 | 5 | No derived attributes remain (table below); `Media` appears once. |
| Expressiveness | 4 | 4 | Episodes and reviews are entities now, but `director` is still repeated across two subsets (see section 5). |
| Readability | 3 | 4 | One connected diagram, subsets beneath the parent, straight lines. It is still large. |
| Self-explanation | 3 | 4 | No ambiguous attribute remains; roles on `Friends` and arrows show multiplicity. |
| Extensibility | 4 | 4 | A new media type is still one new subset. |
| Normality | 5 | 5 | All 18 tables are in BCNF, 3NF and 4NF (`normalisation.md`). |

### Attribute audit of the final ERD: 0 redundant attributes

| Entity set | Attributes | Computable from other data? | Stored twice? |
|---|---|---|---|
| `Users` | `user_id`, `username`, `email`, `password_hash` | No | No |
| `Groups` | `group_id`, `group_name` | No | No |
| `Media` | `media_id`, `title`, `release_year`, `summary` | No | No |
| `Books` | `author`, `isbn`, `page_count` | No | No |
| `TV shows` | `director` | No | No |
| `Movies` | `director`, `duration_minutes` | No | No |
| `Podcasts` | `host` | No | No |
| `Songs` | `artist`, `duration_minutes` | No | No |
| `TV Episodes` | `season_number`, `episode_number` (identifier, with the show), `title`, `duration_minutes` | No | No |
| `Podcast Episodes` | `episode_number` (identifier, with the podcast), `title`, `duration_minutes` | No | No |
| `Review` | `user_review` | No | No |
| `Tag` | `tag_id`, `name` | No | No |
| `Tracks` (relationship) | `media_status` | No | No |

## 5. Deliberate deviations

These were considered and kept on purpose.

1. **`director` appears in two subsets.** Moving it up would force a `NULL` into every book,
   podcast and song, or add a one-attribute `Video` level to the hierarchy. A separate `Creator`
   entity set for authors, directors and artists would remove the repetition, and is the planned
   future extension.
2. **"One child table per media item" is not enforceable in MySQL.** Nothing stops a media item
   having no child row, or two. `sql/integrity_audit.sql` checks both
   (`referential_integrity.md` section 6).
3. **Many-to-many relationships carry no multiplicity labels.** We use the course notation:
   an arrow for many-to-one and a plain line for many-to-many.
