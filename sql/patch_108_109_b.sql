-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2023] EMBL-European Bioinformatics Institute
-- 
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

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (87, 12, 'incomplete penetrance');

ALTER TABLE genomic_feature_disease MODIFY COLUMN cross_cutting_modifier_attrib set('54','55','56','57','58','70','82','87') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_deleted MODIFY COLUMN cross_cutting_modifier_attrib set('54','55','56','57','58','70','82','87') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_log MODIFY COLUMN cross_cutting_modifier_attrib set('54','55','56','57','58','70','82','87') DEFAULT NULL;

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_108_109_b.sql|inserting new cross cutting modifier');