-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (132, 4, 'Hearing loss');

INSERT IGNORE INTO panel (panel_id, name, is_visible) VALUES (13, "Hearing loss", 1);

ALTER TABLE user MODIFY COLUMN panel_attrib set('36','37','38','39','40','41','42','43','45','46','47','48','83','132') DEFAULT NULL;

UPDATE user SET panel_attrib = CONCAT(panel_attrib, ',132') WHERE FIND_IN_SET(38, panel_attrib) > 0 OR FIND_IN_SET(37, panel_attrib) > 0;

INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_112_113_b.sql|Adding hearing loss panel');

