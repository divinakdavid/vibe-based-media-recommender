-- run_all.sql
-- Builds the whole database, then runs the demo scripts.
-- From the repository root:
--     cd media-tracker/sql
--     mysql -u root -p
--     mysql> SOURCE run_all.sql;
-- Running it again is safe: it drops and rebuilds everything first.
-- (MySQL Workbench does not support SOURCE: open and run the files below one by one, in order.)

-- ---------------- build ----------------
SOURCE setup.sql;
SOURCE drop_all.sql;
SOURCE schema_users_groups.sql;
SOURCE schema_media.sql;
SOURCE schema_activity.sql;
SOURCE checks.sql;
SOURCE seed_data.sql;

-- ---------------- demos (each leaves the data as it found it) ----------------
SOURCE crud_operations.sql;
SOURCE queries.sql;
SOURCE alter_table.sql;

-- Not run here because they need extra setup. See the README:
--   check_tests.sql      (statements that are meant to fail; needs mysql --force)
--   load_csv.sql         (needs local_infile switched on)
--   queries_stretch.sql  (optional advanced queries)
