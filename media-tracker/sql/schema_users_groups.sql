
USE media_tracker;

-- ---------------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        INT           AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(50)   NOT NULL UNIQUE,
    email          VARCHAR(255)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255)  NOT NULL        -- a bcrypt/argon2 hash, never the plain password
);

-- ---------------------------------------------------------------------
-- FRIENDS  (Users M:N Users: follower follows followed)
-- Deleting a user removes their follows in both directions.
-- ---------------------------------------------------------------------
CREATE TABLE friends (
    follower_id  INT,
    followed_id  INT,
    PRIMARY KEY (follower_id, followed_id),
    FOREIGN KEY (follower_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (followed_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- USER_GROUPS  (named user_groups because GROUPS is a reserved word in MySQL 8)
-- CREATES is many-to-one: each group has exactly one creator, so it is the creator_id column.
-- RESTRICT: a user who still owns a group cannot be deleted. Reassign or delete the group first,
-- so a group is never left without a creator.
-- ---------------------------------------------------------------------
CREATE TABLE user_groups (
    group_id    INT           AUTO_INCREMENT PRIMARY KEY,
    group_name  VARCHAR(100)  NOT NULL,
    creator_id  INT           NOT NULL,
    FOREIGN KEY (creator_id) REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- MEMBER_OF  (Users M:N Groups)
-- ---------------------------------------------------------------------
CREATE TABLE member_of (
    group_id  INT,
    user_id   INT,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES user_groups (group_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users (user_id)        ON DELETE CASCADE ON UPDATE CASCADE
);
