-- See the NOTICE file distributed with this work for additional information
-- regarding copyright ownership.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (1, 'allelic_requirement', 'Allelic requirement', 'Allelic requirement');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (2, 'mutation_consequence', 'Mutation consequence', 'Mutation consequence');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (3, 'confidence_category', 'confidence category', 'confidence category');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (4, 'g2p_panel', 'G2P panel', 'G2P panel');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (5, 'retired', 'retired attrib type', 'retired attrib type');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (6, 'ontology_mapping', 'Ontology Mapping', 'Method used to link a description to an ontology term');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (7, 'gws', 'Genome-wide significance statistic', 'Gene-wise assessment of DNM significance');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (8, 'p_value', 'P-value', 'Minimum P-value from testing of the DDD dataset or the meta-analysis dataset');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (9, 'dataset', 'dataset', 'DDD or meta-analysis dataset');
INSERT IGNORE INTO attrib_type (attrib_type_id, code, name, description) VALUES (10, 'clustering', 'clustering', 'Mutations are considered clustered if the P-value from proximity clustering of DNMs is less than 0.01');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (1, 5, 'monoallelic (autosome)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (2, 5, 'monoallelic (autosome; obligate mosaic)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (3, 1, 'biallelic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (4, 5, 'monoallelic (X; heterozygous)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (5, 5, 'monoallelic (X; hemizygous)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (6, 1, 'monoallelic (Y)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (7, 5, 'mtDNA (homoplasmic)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (8, 5, 'mtDNA (heteroplasmic)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (9, 5, 'digenic (biallelic)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (10, 5, 'digenic (triallelic)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (11, 5, 'digenic (tetra-allelic)');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (12, 1, 'imprinted');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (13, 1, 'uncertain');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (14, 1, 'monoallelic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (15, 1, 'hemizygous');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (16, 1, 'x-linked dominant');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (17, 1, 'x-linked over-dominance');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (18, 1, 'mosaic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (19, 1, 'mitochondrial');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (20, 1, 'digenic');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (21, 2, '5_prime or 3_prime UTR mutation');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (22, 2, 'all missense/in frame');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (23, 2, 'cis-regulatory or promotor mutation');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (24, 2, 'dominant negative');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (25, 2, 'loss of function');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (26, 2, 'uncertain');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (27, 2, 'activating');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (28, 2, 'increased gene dosage');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (29, 2, 'part of contiguous gene duplication');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (30, 2, 'part of contiguous genomic interval deletion');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (44, 2, 'gain of function');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (31, 3, 'both RD and IF');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (32, 3, 'confirmed');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (33, 3, 'possible');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (34, 3, 'probable');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (35, 3, 'child IF');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (36, 4, 'ALL');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (37, 4, 'Cardiac');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (38, 4, 'DD');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (39, 4, 'Ear');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (40, 4, 'Eye');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (41, 4, 'Skin');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (42, 4, 'Cancer');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (43, 4, 'Prenatal');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (45, 4, 'NeonatalRespiratory');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (46, 4, 'Demo');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (47, 4, 'Rapid_PICU_NICU');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (437, 6, 'Data source');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (438, 6, 'OLS exact');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (439, 6, 'OLS partial');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (440, 6, 'Zooma exact');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (441, 6, 'Zooma partial');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (442, 6, 'Manual');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (443, 6, 'HPO');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (444, 6, 'Orphanet');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (445, 7, 'p_value');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (446, 7, 'data_set');
INSERT IGNORE INTO attrib (attrib_id, attrib_type_id, value) VALUES (447, 7, 'clustering');
