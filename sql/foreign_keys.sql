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

# Foreign key relationships in the Ensembl-gene2phenotype schema (see table.sql);
#
# This file is intended as a reference since some of the relationships
# are not obvious.
#
# Note that these constraints are not actually used by Ensembl-gene2phenotype.
# Referential integrity is enforced at the application level.

ALTER TABLE attrib ADD FOREIGN KEY (attrib_type_id) REFERENCES attrib_type(attrib_type_id);

ALTER TABLE genomic_feature_disease ADD FOREIGN KEY (genomic_feature_id) REFERENCES genomic_feature(genomic_feature_id);
ALTER TABLE genomic_feature_disease ADD FOREIGN KEY (disease_id) REFERENCES disease(disease_id);

ALTER TABLE genomic_feature_disease_log ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE genomic_feature_disease_log ADD FOREIGN KEY (genomic_feature_id) REFERENCES genomic_feature(genomic_feature_id);
ALTER TABLE genomic_feature_disease_log ADD FOREIGN KEY (disease_id) REFERENCES disease(disease_id);

ALTER TABLE genomic_feature_disease_panel ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);

ALTER TABLE genomic_feature_disease_panel_log ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE genomic_feature_disease_panel_log ADD FOREIGN KEY (genomic_feature_disease_panel_id) REFERENCES genomic_feature_disease_panel(genomic_feature_disease_panel_id);

ALTER TABLE genomic_feature_disease_comment ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE genomic_feature_disease_comment ADD FOREIGN KEY (user_id) REFERENCES user(user_id);

ALTER TABLE genomic_feature_disease_organ ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE genomic_feature_disease_organ ADD FOREIGN KEY (organ_id) REFERENCES organ(organ_id);

ALTER TABLE genomic_feature_disease_phenotype ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE genomic_feature_disease_phenotype ADD FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id);

ALTER TABLE GFD_phenotype_log ADD FOREIGN KEY (genomic_feature_disease_phenotype_id) REFERENCES genomic_feature_disease_phenotype(genomic_feature_disease_phenotype_id);
ALTER TABLE GFD_phenotype_log ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE GFD_phenotype_log ADD FOREIGN KEY (phenotype_id) REFERENCES phenotype(phenotype_id);
ALTER TABLE GFD_phenotype_log ADD FOREIGN KEY (user_id) REFERENCES user(user_id);

ALTER TABLE GFD_phenotype_comment ADD FOREIGN KEY (genomic_feature_disease_phenotype_id) REFERENCES genomic_feature_disease_phenotype(genomic_feature_disease_phenotype_id);
ALTER TABLE GFD_phenotype_comment ADD FOREIGN KEY (user_id) REFERENCES user(user_id);

ALTER TABLE genomic_feature_disease_publication ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE genomic_feature_disease_publication ADD FOREIGN KEY (publication_id) REFERENCES publication(publication_id);

ALTER TABLE GFD_publication_comment ADD FOREIGN KEY (genomic_feature_disease_publication_id) REFERENCES genomic_feature_disease_publication(genomic_feature_disease_publication_id);
ALTER TABLE GFD_publication_comment ADD FOREIGN KEY (user_id) REFERENCES user(user_id);

ALTER TABLE GFD_disease_synonym ADD FOREIGN KEY (genomic_feature_disease_id) REFERENCES genomic_feature_disease(genomic_feature_disease_id);
ALTER TABLE GFD_disease_synonym ADD FOREIGN KEY (disease_id) REFERENCES disease(disease_id);

ALTER TABLE genomic_feature_statistic ADD FOREIGN KEY (genomic_feature_id) REFERENCES genomic_feature(genomic_feature_id);

ALTER TABLE disease_ontology_mapping 
ADD FOREIGN KEY (disease_id) REFERENCES disease(disease_id),
ADD FOREIGN KEY (ontology_accession_id) REFERENCES ontology_accession(ontology_accession_id);


