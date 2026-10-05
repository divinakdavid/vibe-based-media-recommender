-- run_all.sql
-- Rebuilds the whole database in the right order.
-- From a terminal, cd into the sql/ folder first (SOURCE paths are relative), then:
--     mysql -u root -p
--     mysql> SOURCE run_all.sql;
-- In MySQL Workbench, SOURCE is not supported: open and run each numbered file in order instead.

SOURCE 00_setup.sql;
SOURCE 00_drop_all.sql;
SOURCE 01_schema_users_groups.sql;
SOURCE 02_schema_media.sql;
SOURCE 03_schema_activity.sql;
SOURCE 04_checks.sql;
SOURCE 05_seed_data.sql;

-- Optional demos / tests (they do not change your data):
SOURCE 06_crud_operations.sql;
SOURCE 07_check_tests.sql;
SOURCE 08_queries.sql;
