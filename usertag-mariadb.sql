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

