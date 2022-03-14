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

CREATE TABLE ontology_term (
  ontology_accession_id int(10) NOT NULL,
  ontology_accession VARCHAR(255) DEFAULT NULL,
  description VARCHAR(255) DEFAULT NULL, 
  PRIMARY KEY (ontology_accession_id)
) ENGINE=INNODB; 

CREATE TABLE disease_ontology_mapping (
  disease_ontology_mapping_id int(10) NOT NULL,
  disease_id INT(10) NOT NULL,
  ontology_accession_id INT(10) NOT NULL, 
  mapped_by_attrib set('437', '438', '439', '440', '441', '442', '443', '444') DEFAULT NULL,
  PRIMARY KEY (disease_ontology_mapping_id),
  FOREIGN KEY (ontology_accession_id) REFERENCES ontology_term(ontology_accession_id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (disease_id) REFERENCES disease(disease_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=INNODB; 

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_104_105_d.sql|creating ontology_term and ontology_accession table'); 
