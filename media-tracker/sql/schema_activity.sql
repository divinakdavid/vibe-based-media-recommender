
USE media_tracker;

-- ---------------------------------------------------------------------
-- TRACKS  (Users M:N Media, with media_status)
-- ---------------------------------------------------------------------
CREATE TABLE tracks (
    user_id       INT,
    media_id      INT,
    media_status  VARCHAR(15)  NOT NULL,         -- want_to_consume | in_progress | finished | dropped
    PRIMARY KEY (user_id, media_id),
    FOREIGN KEY (user_id)  REFERENCES users (user_id)  ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- REVIEWS  (Users M:N Media, with user_review)
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    user_id      INT,
    media_id     INT,
    user_review  TEXT  NOT NULL,
    PRIMARY KEY (user_id, media_id),
    FOREIGN KEY (user_id)  REFERENCES users (user_id)  ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media (media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- REVIEW_TAGS: a review's tags are multi-valued, so they get their own table.
-- This is the BCNF decomposition in docs/normalisation.md.
-- ---------------------------------------------------------------------
CREATE TABLE review_tags (
    user_id   INT,
    media_id  INT,
    tag_id    INT,
    PRIMARY KEY (user_id, media_id, tag_id),
    FOREIGN KEY (user_id, media_id) REFERENCES reviews (user_id, media_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tag (tag_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- RECOMMENDS  (Groups M:N Media)
-- ---------------------------------------------------------------------
CREATE TABLE recommends (
    group_id  INT,
    media_id  INT,
    PRIMARY KEY (group_id, media_id),
    FOREIGN KEY (group_id) REFERENCES user_groups (group_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (media_id) REFERENCES media (media_id)       ON DELETE CASCADE ON UPDATE CASCADE
);
