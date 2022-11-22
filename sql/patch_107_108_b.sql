-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

# Adding new mutation consequence flags
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (85, 14, 'activating');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (86, 14, 'dominant negative');

# Adding both LOF & GOF variant consequence terms 
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (126, 16, 'gain_of_function_variant');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (127, 16, 'loss_of_function_variant');

ALTER TABLE genomic_feature_disease MODIFY COLUMN mutation_consequence_flag_attrib set('71','72','73','74','85','86') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_deleted MODIFY COLUMN mutation_consequence_flag_attrib set('71','72','73','74','85','86') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_log MODIFY COLUMN mutation_consequence_flag_attrib set('71','72','73','74','85','86') DEFAULT NULL;

ALTER TABLE genomic_feature_disease MODIFY COLUMN variant_consequence_attrib set('100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_deleted MODIFY COLUMN variant_consequence_attrib set('100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_log MODIFY COLUMN variant_consequence_attrib set('100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127') DEFAULT NULL;

INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_107_108_b.sql|adding new attribs support new changes');