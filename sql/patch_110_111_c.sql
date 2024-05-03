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

#Patch added on 2024-05-03

ALTER TABLE genomic_feature_disease DROP INDEX genomic_feature_disease;
ALTER TABLE genomic_feature_disease ADD CONSTRAINT genomic_feature_disease UNIQUE KEY (genomic_feature_id, allelic_requirement_attrib, mutation_consequence_attrib, disease_id);

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_110_111_c.sql|Fix gfd unique constraint');
