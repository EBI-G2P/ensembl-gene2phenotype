-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2024] EMBL-European Bioinformatics Institute
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



#28-03-2024

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (128, 16, 'exon_loss_variant');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (129, 16, 'tandem_duplication');
INSERT IGNORE INTO attrib(attrib_id, attrib_type_id, value) VALUES(130, 16, 'complex_structural_alteration');
INSERT IGNORE INTO attrib(attrib_id, attrib_type_id, value) VALUES(131, 16, 'copy_number_variation');

ALTER TABLE genomic_feature_disease MODIFY COLUMN variant_consequence_attrib set('100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127','128','129','130','131') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_deleted MODIFY COLUMN variant_consequence_attrib set('100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127','128','129','130','131') DEFAULT NULL;
ALTER TABLE genomic_feature_disease_log MODIFY COLUMN variant_consequence_attrib set('100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127','128','129','130','131') DEFAULT NULL;

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_110_111_b.sql|adding new variant consequence to support cardiac');
