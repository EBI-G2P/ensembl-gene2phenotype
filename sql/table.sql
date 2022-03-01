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

CREATE TABLE meta (
  meta_id     INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  species_id  INT UNSIGNED DEFAULT 1,
  meta_key    VARCHAR( 40 ) NOT NULL,
  meta_value  VARCHAR( 255 ) NOT NULL,
  PRIMARY KEY ( meta_id ),
  UNIQUE KEY species_key_value_idx (species_id, meta_key, meta_value ),
  KEY species_value_idx (species_id, meta_value )
) ENGINE=INNODB;
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_type', 'gene2phenotype'), (NULL, 'schema_version', '105');
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_104_105_a.sql|schema version');
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_104_105_b.sql|adding potential IF as a cross cutting modifier');

CREATE TABLE attrib_type (
  attrib_type_id smallint(5)  unsigned NOT NULL AUTO_INCREMENT,
  code varchar(20) NOT NULL DEFAULT '',
  name varchar(255) NOT NULL DEFAULT '',
  description text, 
  PRIMARY KEY (attrib_type_id),
  UNIQUE KEY code_idx (code)
) ENGINE=INNODB;

CREATE TABLE attrib (
  attrib_id int(11) unsigned NOT NULL,
  attrib_type_id smallint(5) unsigned NOT NULL,
  value text NOT NULL,
  PRIMARY KEY (attrib_id),
  UNIQUE KEY attrib_type_idx (attrib_type_id, value(80))
) ENGINE=INNODB;

CREATE TABLE disease (
  disease_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  name varchar(255) DEFAULT NULL,
  mim int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (disease_id),
  KEY name_idx (name)
) ENGINE=INNODB;

CREATE TABLE genomic_feature (
  genomic_feature_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  gene_symbol varchar(128) DEFAULT NULL,
  hgnc_id int(10) unsigned DEFAULT NULL,
  ncbi_id int(10) unsigned DEFAULT NULL,
  mim int(10) unsigned DEFAULT NULL,
  ensembl_stable_id varchar(128) DEFAULT NULL,
  seq_region_id int(10) unsigned DEFAULT NULL,
  seq_region_start int(10) unsigned DEFAULT NULL,
  seq_region_end int(10) unsigned DEFAULT NULL,
  seq_region_strand tinyint(2) DEFAULT NULL,
  PRIMARY KEY (genomic_feature_id),
  KEY gene_symbol_idx (gene_symbol),
  KEY mim_idx (mim),
  KEY ensembl_stable_id_idx (ensembl_stable_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_synonym (
  genomic_feature_id int(10) unsigned NOT NULL,
  name varchar(255) NOT NULL,
  UNIQUE KEY name (genomic_feature_id, name),
  KEY genomic_feature_idx (genomic_feature_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease (
  genomic_feature_disease_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_id int(10) unsigned NOT NULL,
  disease_id int(10) unsigned NOT NULL,
  original_allelic_requirement_attrib set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20') DEFAULT NULL,
  allelic_requirement_attrib set('59','60','61','62','63','64','65','66','67','68','69','70') DEFAULT NULL,
  cross_cutting_modifier_attrib set('54','55','56','57','58','70','82') DEFAULT NULL,
  original_mutation_consequence_attrib set('21','22','23','24','25','26','27','28','29','30','44') DEFAULT NULL,
  mutation_consequence_attrib int(10) unsigned DEFAULT '0',
  mutation_consequence_flag_attrib set('71','72','73','74') DEFAULT NULL,
  restricted_mutation_set tinyint(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (genomic_feature_disease_id),
  UNIQUE KEY genomic_feature_disease (genomic_feature_id, allelic_requirement_attrib, mutation_consequence_attrib, disease_id),
  KEY genomic_feature_idx (genomic_feature_id),
  KEY disease_idx (disease_id)
) ENGINE=INNODB;

CREATE TABLE user (
  user_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  username varchar(255) NOT NULL,
  email varchar(255) NOT NULL,
  panel_attrib set('36','37','38','39','40','41','42','43','45','46','47','48') DEFAULT NULL,
  PRIMARY KEY (user_id),
  UNIQUE KEY user_idx (username),
  UNIQUE KEY email_idx (email)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_deleted (
  genomic_feature_disease_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_id int(10) unsigned NOT NULL,
  disease_id int(10) unsigned NOT NULL,
  original_allelic_requirement_attrib set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20') DEFAULT NULL,
  allelic_requirement_attrib set('59','60','63','64','65','66','67','68') DEFAULT NULL,
  cross_cutting_modifier_attrib set('54','55','56','57','58','70','82') DEFAULT NULL,
  original_mutation_consequence_attrib set('21','22','23','24','25','26','27','28','29','30','44') DEFAULT NULL,
  mutation_consequence_attrib int(10) unsigned DEFAULT '0',
  mutation_consequence_flag_attrib set('71','72','73','74') DEFAULT NULL,
  deleted timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  deleted_by_user_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_id),
  KEY genomic_feature_idx (genomic_feature_id),
  KEY disease_idx (disease_id)
) ENGINE=INNODB;

CREATE TABLE `genomic_feature_disease_log` (
  genomic_feature_disease_log_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  genomic_feature_id int(10) unsigned NOT NULL,
  disease_id int(10) unsigned NOT NULL,
  original_allelic_requirement_attrib set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20') DEFAULT NULL,
  allelic_requirement_attrib set('59','60','63','64','65','66','67','68') DEFAULT NULL,
  cross_cutting_modifier_attrib set('54','55','56','57','58','70','82') DEFAULT NULL,
  original_mutation_consequence_attrib set('21','22','23','24','25','26','27','28','29','30','44') DEFAULT NULL,
  mutation_consequence_attrib int(10) unsigned DEFAULT '0',
  mutation_consequence_flag_attrib set('71','72','73','74') DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  action varchar(128) NOT NULL,
  PRIMARY KEY (genomic_feature_disease_log_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_panel (
  genomic_feature_disease_panel_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  original_confidence_category_attrib set('31','32','33','34','35') DEFAULT NULL,
  confidence_category_attrib int(10) unsigned DEFAULT '0',
  clinical_review tinyint(1) unsigned DEFAULT '0',
  is_visible tinyint(1) unsigned NOT NULL DEFAULT '1',
  panel_attrib tinyint(1) DEFAULT NULL,
  PRIMARY KEY (genomic_feature_disease_panel_id),
  UNIQUE KEY gfd_panel_idx (genomic_feature_disease_id, panel_attrib),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_panel_log (
  genomic_feature_disease_panel_log_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_panel_id int(10) unsigned NOT NULL,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  original_confidence_category_attrib set('31','32','33','34','35') DEFAULT NULL,
  confidence_category_attrib int(10) unsigned DEFAULT '0',
  clinical_review tinyint(1) unsigned DEFAULT '0',
  is_visible tinyint(1) unsigned NOT NULL DEFAULT '1',
  panel_attrib tinyint(1) DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  action varchar(128) NOT NULL,
  PRIMARY KEY (genomic_feature_disease_panel_log_id),
  KEY genomic_feature_disease_panel_idx (genomic_feature_disease_panel_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_panel_deleted (
  genomic_feature_disease_panel_deleted_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_panel_id int(10) unsigned NOT NULL,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  original_confidence_category_attrib set('31','32','33','34','35') DEFAULT NULL,
  confidence_category_attrib int(10) unsigned DEFAULT '0',
  clinical_review tinyint(1) unsigned DEFAULT '0',
  is_visible tinyint(1) unsigned NOT NULL DEFAULT '1',
  panel_attrib tinyint(1) DEFAULT NULL,
  deleted timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  deleted_by_user_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_panel_deleted_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_comment (
  genomic_feature_disease_comment_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  comment_text text DEFAULT NULL,
  is_public tinyint(1) unsigned NOT NULL DEFAULT '0',
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_comment_id),
  KEY GFD_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE GFD_comment_deleted (
  GFD_comment_deleted_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  comment_text text DEFAULT NULL,
  is_public tinyint(1) unsigned NOT NULL DEFAULT '0',
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  deleted timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  deleted_by_user_id int(10) unsigned NOT NULL,
  PRIMARY KEY (GFD_comment_deleted_id),
  KEY GFD_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE organ (
  organ_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  name varchar(255) NOT NULL,
  PRIMARY KEY (organ_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_organ (
  genomic_feature_disease_organ_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  organ_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_organ_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_organ_deleted (
  genomic_feature_disease_organ_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  organ_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_organ_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE phenotype (
  phenotype_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  stable_id varchar(255) DEFAULT NULL,
  name varchar(255) DEFAULT NULL,
  description varchar(255) DEFAULT NULL,
  source varchar(24) DEFAULT NULL,
  PRIMARY KEY (phenotype_id),
  UNIQUE KEY desc_idx (description),
  KEY name_idx (name),
  KEY stable_idx (stable_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_phenotype (
  genomic_feature_disease_phenotype_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  phenotype_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_phenotype_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE GFD_phenotype_log (
  GFD_phenotype_log_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_phenotype_id int(10) unsigned NOT NULL,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  phenotype_id int(10) unsigned NOT NULL,
  is_visible tinyint(1) unsigned NOT NULL DEFAULT '1',
  panel_attrib tinyint(1) DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  action varchar(128) NOT NULL,
  PRIMARY KEY (GFD_phenotype_log_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE GFD_phenotype_comment (
  GFD_phenotype_comment_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_phenotype_id int(10) unsigned NOT NULL,
  comment_text text DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  PRIMARY KEY (GFD_phenotype_comment_id),
  KEY GFD_phenotype_idx (genomic_feature_disease_phenotype_id)
) ENGINE=INNODB;

CREATE TABLE GFD_phenotype_comment_deleted (
  GFD_phenotype_comment_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_phenotype_id int(10) unsigned NOT NULL,
  comment_text text DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL,
  deleted timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  deleted_by_user_id int(10) unsigned NOT NULL,
  PRIMARY KEY (GFD_phenotype_comment_id),
  KEY GFD_phenotype_idx (genomic_feature_disease_phenotype_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_phenotype_deleted (
  genomic_feature_disease_phenotype_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  phenotype_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_phenotype_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE publication (
  publication_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  pmid int(10) DEFAULT NULL,
  title mediumtext DEFAULT NULL,
  source varchar(255) DEFAULT NULL,
  PRIMARY KEY (publication_id),
  KEY pmid_idx (pmid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE genomic_feature_disease_publication (
  genomic_feature_disease_publication_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  publication_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_publication_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE GFD_publication_comment (
  GFD_publication_comment_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_publication_id int(10) unsigned NOT NULL,
  comment_text text DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL, 
  PRIMARY KEY (GFD_publication_comment_id),
  KEY GFD_publication_idx (genomic_feature_disease_publication_id)
) ENGINE=INNODB;

CREATE TABLE GFD_publication_comment_deleted (
  GFD_publication_comment_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_publication_id int(10) unsigned NOT NULL,
  comment_text text DEFAULT NULL,
  created timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  user_id int(10) unsigned NOT NULL, 
  deleted timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  deleted_by_user_id int(10) unsigned NOT NULL, 
  PRIMARY KEY (GFD_publication_comment_id),
  KEY GFD_publication_idx (genomic_feature_disease_publication_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_disease_publication_deleted (
  genomic_feature_disease_publication_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  publication_id int(10) unsigned NOT NULL,
  PRIMARY KEY (genomic_feature_disease_publication_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE GFD_disease_synonym (
  GFD_disease_synonym_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_disease_id int(10) unsigned NOT NULL,
  disease_id int(10) unsigned NOT NULL,
  PRIMARY KEY (GFD_disease_synonym_id),
  KEY genomic_feature_disease_idx (genomic_feature_disease_id)
) ENGINE=INNODB;

CREATE TABLE panel (
  panel_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  name varchar(255) NOT NULL,
  is_visible tinyint(1) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (panel_id)
) ENGINE=INNODB;

CREATE TABLE organ_panel (
  organ_id int(10) unsigned NOT NULL,
  panel_id int(10) unsigned NOT NULL,
  PRIMARY KEY (organ_id, panel_id),
  KEY organ_panel_idx (organ_id, panel_id)
) ENGINE=INNODB;

CREATE TABLE search (
  search_term varchar(255) NOT NULL,
  PRIMARY KEY (search_term)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_statistic (
  genomic_feature_statistic_id int(10) unsigned NOT NULL AUTO_INCREMENT,
  genomic_feature_id int(10) unsigned DEFAULT NULL,
  panel_attrib tinyint(1) DEFAULT NULL,
  PRIMARY KEY (genomic_feature_statistic_id),
  KEY genomic_feature_idx (genomic_feature_id)
) ENGINE=INNODB;

CREATE TABLE genomic_feature_statistic_attrib (
  genomic_feature_statistic_id int(10) unsigned NOT NULL,
  attrib_type_id int(10) DEFAULT NULL,
  value varchar(255) DEFAULT NULL,
  KEY genomic_feature_statistic_idx (genomic_feature_statistic_id),
  KEY type_value_idx (attrib_type_id, value)
) ENGINE=INNODB; 
