-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

UPDATE attrib_type SET code = 'original_allelic_requirement', description = 'Original allelic requirement terms. Before GenCC alignment.' WHERE attrib_type_id = 1;
UPDATE attrib_type SET code = 'original_mutation_consequence', description = 'Original mutation consequence terms. Before GenCC alignment.' WHERE attrib_type_id = 2;
UPDATE attrib_type SET code = 'original_confidence_category', description = 'Original confidence category terms. Before GenCC alignment.' WHERE attrib_type_id = 3;

INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (11, 'confidence_category', 'Confidence category', 'Confidence category terms');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (12, 'cross_cutting_modifier', 'Cross cutting modifier', 'Cross cutting modifier');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (13, 'allelic_requirement', 'Allelic requirement', 'Allelic requirement');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (14, 'mutation_consequence_flag', 'Mutation consequence flag', 'Mutation consequence flag');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (15, 'mutation_consequence', 'Mutation consequence', 'Mutation consequence');

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (49, 11, 'both RD and IF');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (50, 11, 'definitive');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (51, 11, 'limited');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (52, 11, 'strong');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (53, 11, 'child IF');

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (54, 12, 'requires heterozygosity');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (55, 12, 'typically de novo');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (56, 12, 'typically mosaic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (57, 12, 'typified by age related penetrance');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (58, 12, 'typified by reduced penetrance');

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (59, 13, 'biallelic_autosomal');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (60, 13, 'biallelic_PAR');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (61, 13, 'digenic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (62, 13, 'imprinted');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (63, 13, 'mitochondrial');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (64, 13, 'monoallelic_autosomal');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (65, 13, 'monoallelic_PAR');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (66, 13, 'monoallelic_X_hem');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (67, 13, 'monoallelic_X_het');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (68, 13, 'monoallelic_Y_hem');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (69, 13, 'mosaic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (70, 13, 'uncertain');

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (71, 14, 'likely to escape nonsense mediated decay');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (72, 14, 'part of contiguous gene duplication');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (73, 14, 'part of contiguous genomic interval deletion');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (74, 14, 'restricted mutation set');

INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (75, 15, '5_prime or 3_prime UTR mutation');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (76, 15, 'absent gene product');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (77, 15, 'altered gene product structure');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (78, 15, 'cis-regulatory or promotor mutation');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (79, 15, 'increased gene product level');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (80, 15, 'uncertain');

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_103_104_d.sql|add new terms');
