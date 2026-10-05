-- run_all.sql
-- Rebuilds the whole database in the right order.
-- From a terminal, cd into the sql/ folder first (SOURCE paths are relative), then:
--     mysql -u root -p
--     mysql> SOURCE run_all.sql;
-- For MySQL Workbench, SOURCE is not supported so must run individually.

SOURCE setup.sql;
SOURCE drop_all.sql;
SOURCE schema_users_groups.sql;
SOURCE schema_media.sql;
SOURCE schema_activity.sql;
SOURCE checks.sql;
SOURCE seed_data.sql;

-- -- Optional (uncommment to run)
-- SOURCE crud_operations.sql;
-- SOURCE check_tests.sql;
-- SOURCE queries.sql;