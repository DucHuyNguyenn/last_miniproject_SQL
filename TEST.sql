CREATE DATABASE SocialNetworkDB;
USE SocialNetworkDB;

-- USERS
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- POSTS
CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE
);

-- COMMENTS
CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (post_id)
    REFERENCES posts(post_id)
    ON DELETE CASCADE,

    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE
);

-- FRIENDS
CREATE TABLE friends (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    friend_id INT NOT NULL,

    status VARCHAR(20)
    CHECK(status IN ('pending','accepted')),

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE,

    FOREIGN KEY (friend_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE,

    CHECK(user_id != friend_id)
);

-- LIKES
CREATE TABLE likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE,

    FOREIGN KEY (post_id)
    REFERENCES posts(post_id)
    ON DELETE CASCADE,

    UNIQUE(user_id, post_id)
);

-- DATA
INSERT INTO users(username,password,email)
VALUES
('an_nguyen',SHA1('123'),'an@gmail.com'),
('binh_tran',SHA1('456'),'binh@gmail.com'),
('chi_le',SHA1('789'),'chi@gmail.com');

INSERT INTO posts(user_id,content,like_count,comment_count)
VALUES
(1,'Hello',2,1),
(2,'MySQL vui quá',1,1),
(3,'Code fullstack',0,0);

INSERT INTO comments(post_id,user_id,content)
VALUES
(1,2,'Hay'),
(2,1,'Đúng rồi');

INSERT INTO friends(user_id,friend_id,status)
VALUES
(1,2,'accepted'),
(1,3,'pending');

INSERT INTO likes(user_id,post_id)
VALUES
(2,1),
(1,2);

-- F01 CREATE ACCOUNT
DELIMITER $$

CREATE PROCEDURE create_account_social(
    p_username VARCHAR(50),
    p_password VARCHAR(255),
    p_email VARCHAR(100)
)
BEGIN

    IF EXISTS (
        SELECT 1
        FROM users
        WHERE email = p_email
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email đã tồn tại';

    END IF;

    INSERT INTO users(username,password,email)
    VALUES(
        p_username,
        SHA1(p_password),
        p_email
    );

END $$

DELIMITER ;

-- F02 CREATE POST
DELIMITER $$

CREATE PROCEDURE create_post(
    p_user_id INT,
    p_content TEXT
)
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';

    END IF;

    INSERT INTO posts(user_id,content)
    VALUES(p_user_id,p_content);

END $$

DELIMITER ;

-- F03 LIKE
DELIMITER $$

CREATE TRIGGER trg_after_like
AFTER INSERT
ON likes
FOR EACH ROW
BEGIN

    UPDATE posts
    SET like_count = like_count + 1
    WHERE post_id = NEW.post_id;

END $$

DELIMITER ;

-- F03 UNLIKE
DELIMITER $$

CREATE TRIGGER trg_after_unlike
AFTER DELETE
ON likes
FOR EACH ROW
BEGIN

    UPDATE posts
    SET like_count = like_count - 1
    WHERE post_id = OLD.post_id;

END $$

DELIMITER ;

-- F04 CHECK FRIEND
DELIMITER $$

CREATE TRIGGER trg_check_friend_request
BEFORE INSERT
ON friends
FOR EACH ROW
BEGIN

    IF EXISTS (
        SELECT 1
        FROM friends
        WHERE
        (user_id = NEW.user_id
         AND friend_id = NEW.friend_id)
        OR
        (user_id = NEW.friend_id
         AND friend_id = NEW.user_id)
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Đã tồn tại kết bạn';

    END IF;

END $$

DELIMITER ;

-- F05 MANAGE FRIEND
DELIMITER $$

CREATE PROCEDURE manage_friendship(
    p_user_id INT,
    p_friend_id INT,
    p_action VARCHAR(20)
)
BEGIN

    IF p_action = 'accepted' THEN

        UPDATE friends
        SET status = 'accepted'
        WHERE
        (
            user_id = p_user_id
            AND friend_id = p_friend_id
        )
        OR
        (
            user_id = p_friend_id
            AND friend_id = p_user_id
        );

    ELSEIF p_action = 'cancelled' THEN

        DELETE FROM friends
        WHERE
        (
            user_id = p_user_id
            AND friend_id = p_friend_id
        )
        OR
        (
            user_id = p_friend_id
            AND friend_id = p_user_id
        );

    END IF;

END $$

DELIMITER ;

-- F06 VIEW PROFILE
CREATE VIEW user_profile_view AS
SELECT
    u.user_id,
    u.username,
    COUNT(p.post_id) total_posts,
    COALESCE(SUM(p.like_count),0) total_likes
FROM users u
LEFT JOIN posts p
ON u.user_id = p.user_id
GROUP BY u.user_id,u.username;

-- F07 SEARCH POST
DELIMITER $$

CREATE PROCEDURE search_posts(
    p_keyword VARCHAR(100)
)
BEGIN

    SELECT *
    FROM posts
    WHERE content LIKE CONCAT('%',p_keyword,'%');

END $$

DELIMITER ;

-- F08 REPORT
DELIMITER $$

CREATE PROCEDURE report_user_activity(
    p_user_id INT
)
BEGIN

    SELECT
        COUNT(post_id) total_posts,
        SUM(like_count) total_likes,
        SUM(comment_count) total_comments
    FROM posts
    WHERE user_id = p_user_id;

END $$

DELIMITER ;

-- F09 SUGGEST FRIEND
DELIMITER $$

CREATE PROCEDURE sp_suggest_friends(
    p_user_id INT
)
BEGIN

    WITH my_friends AS (

        SELECT
        CASE
            WHEN user_id = p_user_id
            THEN friend_id
            ELSE user_id
        END AS friend_user_id

        FROM friends

        WHERE
        (
            user_id = p_user_id
            OR friend_id = p_user_id
        )
        AND status = 'accepted'
    )

    SELECT DISTINCT
        u.user_id,
        u.username

    FROM friends f

    JOIN my_friends mf
    ON f.user_id = mf.friend_user_id
    OR f.friend_id = mf.friend_user_id

    JOIN users u
    ON u.user_id =
    CASE
        WHEN f.user_id = mf.friend_user_id
        THEN f.friend_id
        ELSE f.user_id
    END

    WHERE u.user_id != p_user_id;

END $$

DELIMITER ;

-- F10 DELETE POST
DELIMITER $$

CREATE PROCEDURE DeletePost(
    p_post_id INT,
    p_user_id INT
)
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM posts
        WHERE post_id = p_post_id
        AND user_id = p_user_id
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không có quyền xóa';

    END IF;

    DELETE FROM posts
    WHERE post_id = p_post_id;

END $$

DELIMITER ;

-- F11 DELETE USER
DELIMITER $$

CREATE PROCEDURE delete_user(
    p_user_id INT
)
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';

    END IF;

    DELETE FROM users
    WHERE user_id = p_user_id;

END $$

DELIMITER ;