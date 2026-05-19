CREATE DATABASE SocialNetworkDB;
USE SocialNetworkDB;

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE friends (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    status VARCHAR(20) CHECK (status IN ('pending', 'accepted')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (friend_id) REFERENCES users(user_id),
    CHECK (user_id != friend_id),
    UNIQUE (
        (LEAST(user_id, friend_id)),
        (GREATEST(user_id, friend_id))
    )
);

CREATE TABLE likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    UNIQUE (user_id, post_id)
);

USE SocialNetworkDB;
select * FROM users;
INSERT INTO users (username, password, email) VALUES
('an_nguyen', 'matkhau123', 'an@gmail.com'),
('binh_tran', 'binh456', 'binh@gmail.com'),
('chi_le', 'chi789', 'chi@gmail.com'),
('duy_pham', 'duy321', 'duy@gmail.com'),
('hoa_vo', 'hoa654', 'hoa@gmail.com');

INSERT INTO posts (user_id, content, like_count, comment_count) VALUES
(1, 'Hôm nay trời đẹp quá, đi cà phê thôi!', 2, 2),
(2, 'Đang học thiết kế cơ sở dữ liệu MySQL.', 3, 1),
(3, 'Code frontend xong muốn đi ngủ luôn.', 1, 1),
(4, 'Vừa hoàn thành project backend đầu tiên.', 2, 0),
(5, 'Cố gắng học fullstack mỗi ngày.', 1, 1);
SELECT * FROM posts; 
-- COMMENTS
INSERT INTO comments (post_id, user_id, content) VALUES
(1, 2, 'Đi cà phê nhớ rủ nha.'),
(1, 3, 'Thời tiết hôm nay đúng chill thật.'),
(2, 1, 'MySQL học càng nhiều càng lú.'),
(3, 5, 'Frontend nhiều lỗi vặt khó chịu thật.'),
(5, 4, 'Cố lên rồi sẽ thành công.');

-- FRIENDS
INSERT INTO friends (user_id, friend_id, status) VALUES
(1, 2, 'accepted'),
(1, 3, 'accepted'),
(2, 4, 'pending'),
(3, 5, 'accepted'),
(4, 5, 'accepted');

-- LIKES
INSERT INTO likes (user_id, post_id) VALUES
(2, 1),
(3, 1),
(1, 2),
(4, 2),
(5, 2);

-- F01
DROP PROCEDURE IF EXISTS create_account_social;
DELIMITER //
CREATE PROCEDURE create_account_social (p_username VARCHAR(50), p_password VARCHAR(255), p_email VARCHAR(100))
BEGIN
	DECLARE email_same VARCHAR(100);
    DECLARE password VARCHAR(255);
    SELECT email INTO email_same FROM users WHERE email = p_email;
	IF email_same IS NOT NULL THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Email đã được sử dụng';
	ELSE INSERT INTO users (username, password, email) VALUES (p_username, SHA1(p_password), p_email);
	END IF;
    SELECT 'Đã tạo tài khoản thành công' AS message;
END //
DELIMITER ;
CALL create_account_social ('Nguyễn Minh Trung', '090202r', 'nmt@gmail.com');
-- F02

DELIMITER //
CREATE PROCEDURE create_post (p_user_id INT, p_content TEXT)
BEGIN
	IF (SELECT 1 FROM users WHERE user_id = p_user_id) IS NULL THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User không tồn tại';
	END IF;
    IF p_content IS NULL OR trim(p_content) = '' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nội dung không được rỗng';
	END IF;
	INSERT INTO posts (user_id, content) VALUES (p_user_id, p_content);
    SELECT 'Thêm bài viết thành công' AS message;
END //
DELIMITER ;
CALL create_post (1, 'Hello World');

-- F03 - THÍCH / HỦY THÍCH BÀI VIẾT


-- Trigger tăng like_count khi like
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

-- Trigger giảm like_count khi hủy like
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

-- Like bài viết
INSERT INTO likes(user_id, post_id)
VALUES (1,3);
SELECT * FROM likes;

-- Hủy like
DELETE FROM likes
WHERE user_id = 1 AND post_id = 3;

-- F04 - GỬI LỜI MỜI KẾT BẠN


-- Trigger chặn gửi lời mời đảo chiều/trùng lặp
DELIMITER $$

CREATE TRIGGER trg_check_friend_request
BEFORE INSERT
ON friends
FOR EACH ROW
BEGIN
    DECLARE existing_count INT;

    SELECT COUNT(*)
    INTO existing_count
    FROM friends
    WHERE 
        (user_id = NEW.user_id AND friend_id = NEW.friend_id)
        OR
        (user_id = NEW.friend_id AND friend_id = NEW.user_id);

    IF existing_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Da ton tai loi moi ket ban';
    END IF;
END $$

DELIMITER ;

-- Gửi lời mời kết bạn
INSERT INTO friends(user_id, friend_id, status)
VALUES (2,5,'pending');

-- Test gửi trùng/ngược chiều (sẽ lỗi)
INSERT INTO friends(user_id, friend_id, status)
VALUES (5,2,'pending');

-- F05
DROP PROCEDURE IF EXISTS manage_friendship;

DELIMITER $$

CREATE PROCEDURE manage_friendship(
    IN p_user_id INT,
    IN p_friend_id INT,
    IN p_action VARCHAR(20)
)
BEGIN
    IF p_action = 'accepted' THEN

        UPDATE friends
        SET status = 'accepted'
        WHERE 
            (
                user_id = p_user_id 
                AND friend_id = p_friend_id
                AND status = 'pending'
            )
            OR
            (
                user_id = p_friend_id 
                AND friend_id = p_user_id
                AND status = 'pending'
            );

    ELSEIF p_action = 'cancelled' THEN

        DELETE FROM friends
        WHERE 
            (user_id = p_user_id AND friend_id = p_friend_id)
            OR
            (user_id = p_friend_id AND friend_id = p_user_id);

    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Hành động không hợp lệ';
    END IF;
END $$

DELIMITER ;

SELECT * FROM friends;

CALL manage_friendship(2, 5, 'accepted');

SELECT * FROM friends;

CALL manage_friendship(2, 5, 'cancelled');

SELECT * FROM friends;
-- F06
CREATE VIEW user_profile_view AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.created_at,
    COUNT(p.post_id) AS total_posts,
    SUM(p.like_count) AS total_likes_received,
    SUM(p.comment_count) AS total_comments_received
FROM users u
LEFT JOIN posts p 
    ON u.user_id = p.user_id
GROUP BY 
    u.user_id,
    u.username,
    u.email,
    u.created_at;
    
SELECT * FROM user_profile_view;
-- F07
DELIMITER $$

CREATE PROCEDURE search_posts(
    IN p_keyword VARCHAR(100)
)
BEGIN
    SELECT *
    FROM posts
    WHERE content LIKE CONCAT('%', p_keyword, '%');
END $$

DELIMITER ;
CALL search_posts ('fullstack');

-- F08
DELIMITER $$

CREATE PROCEDURE report_user_activity(
    IN p_user_id INT
)
BEGIN
    SELECT
        COUNT(post_id) AS total_posts,
        SUM(like_count) AS total_likes,
        SUM(comment_count) AS total_comments
    FROM posts
    WHERE user_id = p_user_id;
END $$

DELIMITER ;
CALL report_user_activity (2);
-- F09: Friend suggestion using CTE
DELIMITER //
CREATE PROCEDURE sp_suggest_friends(
    IN p_user_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;

    WITH my_friends AS (
        SELECT
            CASE
                WHEN user_id = p_user_id THEN friend_id
                ELSE user_id
            END AS friend_user_id
        FROM friends
        WHERE (user_id = p_user_id OR friend_id = p_user_id)
          AND status = 'accepted'
    ),
    friends_of_friends AS (
        SELECT
            CASE
                WHEN f.user_id = mf.friend_user_id THEN f.friend_id
                ELSE f.user_id
            END AS suggested_user_id,
            mf.friend_user_id AS mutual_friend_id
        FROM friends f
        JOIN my_friends mf
          ON f.user_id = mf.friend_user_id
          OR f.friend_id = mf.friend_user_id
        WHERE f.status = 'accepted'
    )
    SELECT
        u.user_id,
        u.username,
        COUNT(DISTINCT fof.mutual_friend_id) AS mutual_friend_count
    FROM friends_of_friends fof
    JOIN users u ON u.user_id = fof.suggested_user_id
    WHERE fof.suggested_user_id <> p_user_id
      AND fof.suggested_user_id NOT IN (SELECT friend_user_id FROM my_friends)
    GROUP BY u.user_id, u.username
    ORDER BY mutual_friend_count DESC, u.username ASC;
END //
DELIMITER ;

CALL sp_suggest_friends (2);
-- F10:
DELIMITER // 

CREATE PROCEDURE DeletePost(
    IN p_post_id INT,
    IN p_user_id INT
)
BEGIN

    DECLARE v_owner_id INT;

    START TRANSACTION;

    -- Kiểm tra bài viết tồn tại
    SELECT user_id
    INTO v_owner_id
    FROM posts
    WHERE post_id = p_post_id;

    IF v_owner_id IS NULL THEN

        ROLLBACK;

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bài viết không tồn tại';

    END IF;

    -- Chỉ chủ bài viết mới được xóa
    IF v_owner_id != p_user_id THEN

        ROLLBACK;

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bạn không có quyền xóa bài viết này';

    END IF;

    -- Xóa bài viết
    DELETE FROM posts
    WHERE post_id = p_post_id;

    COMMIT;

END// 

DELIMITER ;
INSERT INTO posts (user_id, content, like_count, comment_count) VALUES
(2, 'Bau troi moi', 6, 3);
CALL DeletePost (8, 3); -- Bai viet khong tồn tại
CALL DeletePost (6, 3); -- Không có quyền xóa bài viết
CALL DeletePost (6, 2); -- Xóa hợp lệ
SELECT * FROM posts;

-- F11
DROP PROCEDURE IF EXISTS delete_user;

DELIMITER //

CREATE PROCEDURE delete_user(IN p_user_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        DROP TEMPORARY TABLE IF EXISTS temp_user_posts;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS temp_user_posts;

    CREATE TEMPORARY TABLE temp_user_posts (
        post_id INT PRIMARY KEY
    );

    INSERT INTO temp_user_posts(post_id)
    SELECT post_id
    FROM posts
    WHERE user_id = p_user_id;

    DELETE FROM friends
    WHERE user_id = p_user_id OR friend_id = p_user_id;

    DELETE FROM likes
    WHERE user_id = p_user_id;

    DELETE FROM comments
    WHERE user_id = p_user_id;

    DELETE FROM likes
    WHERE post_id IN (
        SELECT post_id FROM temp_user_posts
    );

    DELETE FROM comments
    WHERE post_id IN (
        SELECT post_id FROM temp_user_posts
    );

    DELETE FROM posts
    WHERE user_id = p_user_id;

    DELETE FROM users
    WHERE user_id = p_user_id;

    DROP TEMPORARY TABLE IF EXISTS temp_user_posts;

    COMMIT;

    SELECT 'Xóa người dùng thành công' AS message;
END //

DELIMITER ;
CALL delete_user(2);