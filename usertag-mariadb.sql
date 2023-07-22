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

-- usertag features that work on all supported MariaDB versions,
-- but not on Percona Server or MySQL.


USE usertag;


-- Make all usertag tables system-versioned

ALTER TABLE usertag
      ADD COLUMN valid_since TIMESTAMP(6) GENERATED ALWAYS AS ROW START INVISIBLE
    , ADD COLUMN valid_until TIMESTAMP(6) GENERATED ALWAYS AS ROW END INVISIBLE
    , ADD PERIOD FOR SYSTEM_TIME(valid_since, valid_until)
    , ADD SYSTEM VERSIONING
;

ALTER TABLE usertag
    PARTITION BY SYSTEM_TIME (
            PARTITION p_history HISTORY
          , PARTITION p_current CURRENT
    )
;


ALTER TABLE usertag_definition
      ADD COLUMN valid_since TIMESTAMP(6) GENERATED ALWAYS AS ROW START INVISIBLE
    , ADD COLUMN valid_until TIMESTAMP(6) GENERATED ALWAYS AS ROW END INVISIBLE
    , ADD PERIOD FOR SYSTEM_TIME(valid_since, valid_until)
    , ADD SYSTEM VERSIONING
;

ALTER TABLE usertag_definition
    PARTITION BY SYSTEM_TIME (
            PARTITION p_history HISTORY
          , PARTITION p_current CURRENT
    )
;


DELIMITER ||

CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_hist_get(
        IN i_username VARCHAR(64),
        IN i_tag VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get tags for the specified user and their history. LIKE patterns are used for users and tags'
BEGIN
    SET i_username := to_like_pattern(i_username);
    SET i_tag := to_like_pattern(i_tag);

    SELECT username, tag, value, valid_since, valid_until
        FROM usertag FOR SYSTEM_TIME ALL
        WHERE
            username LIKE i_username
            AND tag LIKE i_tag
            AND tag_type = 'SCALAR'
        ORDER BY 1, 2, 4
    ;
END ||


CREATE
    DEFINER = vettabase@'127.0.0.1'
    PROCEDURE usertag_hist_definition_get(
        IN i_tag VARCHAR(64)
    )
        SQL SECURITY DEFINER
        NOT DETERMINISTIC
        READS SQL DATA
        COMMENT 'Get the definition history for the specified tag'
BEGIN
    DECLARE v_definition TEXT DEFAULT NULL;

    IF i_tag IS NULL OR i_tag = '' THEN
        CALL raise_exception(31000, 'The tag name cannot be empty or NULL');
    END IF;
    IF i_tag LIKE '%.' THEN
        CALL raise_exception(31000, 'The tag name cannot end with a dot');
    END IF;

    SELECT i_tag AS tag, definition, valid_since, valid_until
        FROM usertag_definition FOR SYSTEM_TIME ALL
        WHERE tag = i_tag
        ORDER BY valid_since
    ;
END ||

DELIMITER ;
