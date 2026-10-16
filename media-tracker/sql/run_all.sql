
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
--   fk_tests.sql         (PASS/FAIL tests for the ON DELETE policies; rolls itself back)
--   normalization_tests.sql (PASS/FAIL tests for 3NF/4NF; rolls itself back)
--   load_csv.sql         (needs local_infile switched on)
--   queries_stretch.sql  (optional advanced queries)
