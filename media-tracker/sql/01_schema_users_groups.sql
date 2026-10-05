-- 01_schema_users_groups.sql                                OWNER: Lane A (Schema)
-- Tables about PEOPLE: users, friends, user_groups, member_of.
-- (Constraints like NOT NULL / UNIQUE / PK / FK live here. CHECKs live in 04_checks.sql.)

USE media_tracker;

-- ---------------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        INT          AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL          -- store a bcrypt/argon2 hash, never the plain password
);

-- ---------------------------------------------------------------------
-- FRIENDS  (Users M:N Users: follower -> followed)
-- ---------------------------------------------------------------------
CREATE TABLE friends (
    follower_id  INT,
    followed_id  INT,
    PRIMARY KEY (follower_id, followed_id),
    FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (followed_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- GROUPS  (called user_groups because GROUPS is a reserved word in MySQL 8)
-- CREATES is many-to-one (each group has exactly one creator), so it is the
-- creator_id column instead of its own table.
-- ON DELETE RESTRICT: a user who still owns a group cannot be deleted.
-- Reassign the group (UPDATE creator_id) or delete the group first.
-- ---------------------------------------------------------------------
CREATE TABLE user_groups (
    group_id    INT          AUTO_INCREMENT PRIMARY KEY,
    group_name  VARCHAR(100) NOT NULL,
    creator_id  INT          NOT NULL,
    FOREIGN KEY (creator_id) REFERENCES users(user_id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- MEMBER OF  (Users M:N Groups)
-- ---------------------------------------------------------------------
CREATE TABLE member_of (
    group_id  INT,
    user_id   INT,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES user_groups(group_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users(user_id)        ON DELETE CASCADE
);
