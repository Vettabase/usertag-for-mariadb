/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3 of the License.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


CREATE USER IF NOT EXISTS vettabase@'127.0.0.1'
    ACCOUNT LOCK
;
GRANT ALL PRIVILEGES
    ON vettabase.*
    TO vettabase@'127.0.0.1'
;
GRANT SELECT
    ON mysql.user
    TO vettabase@'127.0.0.1'
;


CREATE DATABASE IF NOT EXISTS vettabase
    DEFAULT CHARACTER SET utf8mb4
;
USE vettabase;


CREATE TABLE IF NOT EXISTS usertag (
    username VARCHAR(64) NOT NULL,
    tag_type VARCHAR(20) NOT NULL,
    tag VARCHAR(64) NOT NULL,
    value TEXT NOT NULL,
    CONSTRAINT chk_username_not_empty
        CHECK (username > ''),
    CONSTRAINT chk_tag_not_empty
        CHECK (tag > ''),
    CONSTRAINT chk_tag_dot
        CHECK (tag NOT LIKE '.%' AND tag NOT LIKE '%.'),
    PRIMARY KEY (username, tag),
    INDEX idx_tag (tag)
)
    DEFAULT COLLATE ascii_bin,
    COMMENT 'Usertags are stored here, but this tables should not be used directly'
;

CREATE TABLE IF NOT EXISTS usertag_definition (
    tag VARCHAR(64) NOT NULL,
    definition TEXT NOT NULL,
    CONSTRAINT chk_tag
        CHECK (tag > ''),
    CONSTRAINT chk_definition
        CHECK (definition > ''),
    CONSTRAINT chk_tag_dot
        CHECK (tag NOT LIKE '.%' AND tag NOT LIKE '%.'),
    PRIMARY KEY (tag)
)
    DEFAULT COLLATE ascii_bin,
    COMMENT 'Usertags definitions, by where a definition applies to a tag and its children'
;

CREATE OR REPLACE
    DEFINER = vettabase@'127.0.0.1'
    SQL SECURITY DEFINER
    VIEW orphan_usertag AS
    SELECT DISTINCT t.username
        FROM usertag t
        LEFT JOIN mysql.user u
            ON t.username = u.user
        WHERE u.user IS NULL
        ORDER BY 1
;


DELIMITER ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE raise_exception(
        IN i_code SMALLINT UNSIGNED,
        IN i_message TEXT
    )
        SQL SECURITY DEFINER
        DETERMINISTIC
        CONTAINS SQL
        COMMENT 'SIGNAL a custom error with SQLSTATE ''45000'''
BEGIN
    SIGNAL SQLSTATE '45000' SET
        MYSQL_ERRNO = i_code,
        MESSAGE_TEXT = i_message;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    FUNCTION to_like_pattern(p_value TEXT)
    RETURNS TEXT
    SQL SECURITY DEFINER
    DETERMINISTIC
    CONTAINS SQL
    COMMENT 'Return ''%'' if the value is empty or NULL'
BEGIN
    RETURN IF(
            p_value = '',
            '%',
            IFNULL(p_value, '%')
        );
END ||


CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_get(
        IN i_username VARCHAR(64),
        IN i_tag VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get tags for the specified user. LIKE patterns are used for users and tags'
BEGIN
    SET i_username := to_like_pattern(i_username);
    SET i_tag := to_like_pattern(i_tag);

    SELECT username, tag, value
        FROM usertag
        WHERE
            username LIKE i_username
            AND tag LIKE i_tag
            AND tag_type = 'SCALAR'
        ORDER BY 1, 2
    ;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_get_all()
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get tags for the specified user. LIKE patterns are used for users and tags'
BEGIN
    CALL usertag_get('%', '%');
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_set(
        IN i_username VARCHAR(64),
        IN i_tag VARCHAR(64),
        IN i_value TEXT
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        MODIFIES SQL DATA
        COMMENT 'Set a value for a user/tag'
BEGIN
    IF i_username IS NULL OR i_username = '' THEN
        CALL raise_exception(31000, 'A tag cannot be associated to a zero-length or NULL username');
    END IF;
    IF i_tag IS NULL OR i_tag = '' THEN
        CALL raise_exception(31000, 'A tag cannot have an empty or NULL name');
    END IF;
    IF i_tag LIKE '.%' OR i_tag LIKE '%.' THEN
        CALL raise_exception(31000, 'A tag cannot start or end with a dot');
    END IF;
    IF i_value IS NULL THEN
        CALL raise_exception(31000, 'A tag cannot have a NULL value. If you want to delete it, use usertag_unset()');
    END IF;

    SET i_username := to_like_pattern(i_username);
    SET i_tag := to_like_pattern(i_tag);

    INSERT INTO usertag
        (username, tag_type, tag, value)
        VALUES (i_username, 'SCALAR', i_tag, i_value)
        ON DUPLICATE KEY UPDATE value = i_value
    ;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_unset(
        IN i_username VARCHAR(64),
        IN i_tag VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        MODIFIES SQL DATA
        COMMENT 'Destroy one or more tags by username and tag name. All children will also be destroyed. A child is written with this syntax: "parent.child". LIKE patterns can be used'
BEGIN
    IF i_username IS NULL THEN
        CALL raise_exception(31000, 'A tag cannot be associated to a NULL user. If you want to unset a tag for all users use "%"');
    END IF;
    IF i_username IS NULL THEN
        CALL i_tag(31000, 'A tag cannot be associated to a NULL user. If you want to unset all tags for a user use "%" or call usertag_unset_for_user()');
    END IF;
    DELETE FROM usertag
        WHERE
            username LIKE i_username
            AND (
                tag LIKE i_tag
                OR tag LIKE CONCAT(i_tag, '.%')
            )
            AND tag_type = 'SCALAR'
        /*M!100300 RETURNING username, tag */
    ;
    IF ROW_COUNT() = 0 THEN
        CALL raise_exception(31000, CONCAT_WS('', 'Tag ', i_tag, ' does not exist for user ', i_username));
    END IF;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_unset_for_user(
        IN i_username VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        MODIFIES SQL DATA
        COMMENT 'Destroy all tags for the specified user'
BEGIN
    DELETE FROM usertag
        WHERE username = i_username
    ;
    IF ROW_COUNT() = 0 THEN
        CALL raise_exception(31000, CONCAT_WS('', 'User ', i_username, ' does not exist or has no usertags'));
    END IF;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_rename_user(
        IN i_username_old VARCHAR(64),
        IN i_username_new VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        MODIFIES SQL DATA
        COMMENT 'Assign all tags previously assigned to username_old to username_new'
BEGIN
    UPDATE usertag
        SET username = i_username_new
        WHERE username = i_username_old
    ;
    IF ROW_COUNT() = 0 THEN
        CALL raise_exception(31000, CONCAT_WS('', 'User ', i_username_old, ' does not exist or has no usertags'));
    END IF;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE user_find_by_tag(
        IN i_tag VARCHAR(64),
        IN i_value TEXT
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get the user(s) with the specified tag/value pair. A LIKE pattern can be used for tags. Specified tag''s children are also searched. Use tag=NULL to search by value only, or value=NULL to search by tag only'
BEGIN
    IF i_tag IS NULL AND i_value IS NULL THEN
        CALL i_tag(31000, 'A tag cannot be associated to a NULL user. If you want to unset all tags for a user use "%" or call usertag_unset_for_user()');
    END IF;
    SELECT username
        FROM usertag
        WHERE
            (
                tag = i_tag
                OR tag LIKE CONCAT(i_tag, '.%')
                OR i_tag IS NULL
            )
            AND (
                tag_type = 'SCALAR'
                AND (value = i_value OR i_value IS NULL)
            )
        ORDER BY 1
    ;
END ||


-- DEFINITIONS
-- ===========


CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_definition_set(
        IN i_tag VARCHAR(64),
        IN i_definition TEXT
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        MODIFIES SQL DATA
        COMMENT 'Set the definition for the specified tag. It might also be returned for children that do not have a definition'
BEGIN
    IF i_tag IS NULL OR i_tag = '' THEN
        CALL raise_exception(31000, 'The tag name cannot be empty or NULL');
    END IF;
    IF i_tag LIKE '%.' THEN
        CALL raise_exception(31000, 'The tag name cannot end with a dot');
    END IF;

    IF i_tag IS NULL OR i_definition = '' THEN
        CALL raise_exception(31000, 'The definition cannot be empty or NULL');
    END IF;
    INSERT INTO usertag_definition
            (tag, definition)
        VALUES
            (i_tag, i_definition)
        ON DUPLICATE KEY UPDATE definition = i_definition
    ;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_definition_unset(
        IN i_tag VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        MODIFIES SQL DATA
        COMMENT 'Unset the definition for the specified tag'
BEGIN
    IF i_tag IS NULL OR i_tag = '' THEN
        CALL raise_exception(31000, 'The tag name cannot be empty or NULL');
    END IF;

    DELETE FROM usertag_definition
        WHERE tag = i_tag
    ;

    IF ROW_COUNT() = 0 THEN
        CALL raise_exception(31000, CONCAT_WS('', 'Tag definition for ', i_tag, ' does not exist'));
    END IF;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_definition_get(
        IN i_tag VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get the definition for the specified tag or the closest parent'
BEGIN
    DECLARE v_definition TEXT DEFAULT NULL;

    IF i_tag IS NULL OR i_tag = '' THEN
        CALL raise_exception(31000, 'The tag name cannot be empty or NULL');
    END IF;
    IF i_tag LIKE '%.' THEN
        CALL raise_exception(31000, 'The tag name cannot end with a dot');
    END IF;

    SET v_definition := (
        SELECT definition
            FROM usertag_definition
            WHERE tag = i_tag
    );
    IF v_definition IS NOT NULL THEN
        SELECT i_tag AS tag, v_definition AS definition;
    ELSE
        SELECT tag AS `closest_parent`, definition
            FROM usertag_definition
            WHERE i_tag LIKE CONCAT_WS('', tag, '.%')
            ORDER BY CHAR_LENGTH(tag) DESC
            LIMIT 1
        ;
    END IF;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_find_by_definition(
        IN i_pattern VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get the tags and their definitions based on specified LIKE pattern'
BEGIN
    IF i_pattern IS NULL OR i_pattern = '' THEN
        CALL raise_exception(31000, 'Pattern cannot be empty or NULL. To see all tags and definitions, specify \'%\'');
    END IF;
    SELECT tag, definition
        FROM usertag_definition
        WHERE definition LIKE i_pattern
    ;
END ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_definition_get_all()
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'List all tags and their definitions'
BEGIN
    SELECT tag, definition
        FROM usertag_definition
        ORDER BY tag
    ;
END ||

DELIMITER ;


CALL usertag_set('vettabase', 'comment', 'Locked user (cannot login) that is used as a DEFINER for routines and views in the vettabase database.');

CREATE ROLE IF NOT EXISTS usertag_admin;
GRANT SELECT ON vettabase.orphan_usertag
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_get
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_get_all
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_set
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_unset
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_unset_for_user
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_rename_user
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.user_find_by_tag
    TO usertag_admin;

GRANT EXECUTE ON PROCEDURE vettabase.usertag_definition_set
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_definition_unset
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_definition_get
    TO usertag_admin;
GRANT EXECUTE ON PROCEDURE vettabase.usertag_find_by_definition
    TO usertag_admin;

CALL usertag_definition_set('comment', 'Free-form notes about the user/role');
CALL usertag_set('usertag_admin', 'comment', 'Role that allow users to use the usertag library, by Vettabase.');
