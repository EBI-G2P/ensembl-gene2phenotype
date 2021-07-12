CREATE TABLE `GFD_comment_deleted` (
  `GFD_comment_deleted_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `comment_text` text,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  `deleted` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `deleted_by_user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`GFD_comment_deleted_id`),
  KEY `GFD_idx` (`genomic_feature_disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

CREATE TABLE `GFD_disease_synonym` (
  `GFD_disease_synonym_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `disease_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`GFD_disease_synonym_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  KEY `disease_id` (`disease_id`),
  CONSTRAINT `GFD_disease_synonym_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `GFD_disease_synonym_ibfk_2` FOREIGN KEY (`disease_id`) REFERENCES `disease` (`disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=555 DEFAULT CHARSET=latin1;

CREATE TABLE `GFD_phenotype_comment` (
  `GFD_phenotype_comment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_phenotype_id` int(10) unsigned NOT NULL,
  `comment_text` text,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`GFD_phenotype_comment_id`),
  KEY `GFD_phenotype_idx` (`genomic_feature_disease_phenotype_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `GFD_phenotype_comment_ibfk_1` FOREIGN KEY (`genomic_feature_disease_phenotype_id`) REFERENCES `genomic_feature_disease_phenotype` (`genomic_feature_disease_phenotype_id`),
  CONSTRAINT `GFD_phenotype_comment_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=latin1;

CREATE TABLE `GFD_phenotype_comment_deleted` (
  `GFD_phenotype_comment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_phenotype_id` int(10) unsigned NOT NULL,
  `comment_text` text,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  `deleted` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `deleted_by_user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`GFD_phenotype_comment_id`),
  KEY `GFD_phenotype_idx` (`genomic_feature_disease_phenotype_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;

CREATE TABLE `GFD_phenotype_log` (
  `GFD_phenotype_log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_phenotype_id` int(10) unsigned NOT NULL,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `phenotype_id` int(10) unsigned NOT NULL,
  `is_visible` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `panel_attrib` tinyint(1) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  `action` varchar(128) NOT NULL,
  PRIMARY KEY (`GFD_phenotype_log_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  KEY `genomic_feature_disease_phenotype_id` (`genomic_feature_disease_phenotype_id`),
  KEY `phenotype_id` (`phenotype_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `GFD_phenotype_log_ibfk_1` FOREIGN KEY (`genomic_feature_disease_phenotype_id`) REFERENCES `genomic_feature_disease_phenotype` (`genomic_feature_disease_phenotype_id`),
  CONSTRAINT `GFD_phenotype_log_ibfk_2` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `GFD_phenotype_log_ibfk_3` FOREIGN KEY (`phenotype_id`) REFERENCES `phenotype` (`phenotype_id`),
  CONSTRAINT `GFD_phenotype_log_ibfk_4` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=799 DEFAULT CHARSET=latin1;

CREATE TABLE `GFD_publication_comment` (
  `GFD_publication_comment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_publication_id` int(10) unsigned NOT NULL,
  `comment_text` text,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`GFD_publication_comment_id`),
  KEY `GFD_publication_idx` (`genomic_feature_disease_publication_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `GFD_publication_comment_ibfk_1` FOREIGN KEY (`genomic_feature_disease_publication_id`) REFERENCES `genomic_feature_disease_publication` (`genomic_feature_disease_publication_id`),
  CONSTRAINT `GFD_publication_comment_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=95 DEFAULT CHARSET=latin1;

CREATE TABLE `GFD_publication_comment_deleted` (
  `GFD_publication_comment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_publication_id` int(10) unsigned NOT NULL,
  `comment_text` text,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  `deleted` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `deleted_by_user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`GFD_publication_comment_id`),
  KEY `GFD_publication_idx` (`genomic_feature_disease_publication_id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;

CREATE TABLE `attrib` (
  `attrib_id` int(11) unsigned NOT NULL,
  `attrib_type_id` smallint(5) unsigned NOT NULL,
  `value` text NOT NULL,
  PRIMARY KEY (`attrib_id`),
  UNIQUE KEY `attrib_type_idx` (`attrib_type_id`,`value`(80)),
  CONSTRAINT `attrib_ibfk_1` FOREIGN KEY (`attrib_type_id`) REFERENCES `attrib_type` (`attrib_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `attrib_type` (
  `attrib_type_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(20) NOT NULL DEFAULT '',
  `name` varchar(255) NOT NULL DEFAULT '',
  `description` text,
  PRIMARY KEY (`attrib_type_id`),
  UNIQUE KEY `code_idx` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;

CREATE TABLE `disease` (
  `disease_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `mim` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`disease_id`),
  KEY `name_idx` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4658 DEFAULT CHARSET=latin1;

CREATE TABLE `disease_ontology_accession` (
  `disease_id` int(11) unsigned NOT NULL,
  `accession` varchar(255) NOT NULL,
  `mapped_by_attrib` set('437','438','439','440','441','442','443','444') DEFAULT NULL,
  `mapping_type` enum('is','involves') DEFAULT NULL,
  PRIMARY KEY (`disease_id`,`accession`),
  KEY `accession_idx` (`accession`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature` (
  `genomic_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `gene_symbol` varchar(128) DEFAULT NULL,
  `hgnc_id` int(10) unsigned DEFAULT NULL,
  `ncbi_id` int(10) unsigned DEFAULT NULL,
  `mim` int(10) unsigned DEFAULT NULL,
  `ensembl_stable_id` varchar(128) DEFAULT NULL,
  `seq_region_id` int(10) unsigned DEFAULT NULL,
  `seq_region_start` int(10) unsigned DEFAULT NULL,
  `seq_region_end` int(10) unsigned DEFAULT NULL,
  `seq_region_strand` tinyint(2) DEFAULT NULL,
  PRIMARY KEY (`genomic_feature_id`),
  KEY `gene_symbol_idx` (`gene_symbol`),
  KEY `mim_idx` (`mim`),
  KEY `ensembl_stable_id_idx` (`ensembl_stable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=118600 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease` (
  `genomic_feature_disease_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_id` int(10) unsigned NOT NULL,
  `disease_id` int(10) unsigned NOT NULL,
  `allelic_requirement_attrib` set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20') DEFAULT NULL,
  `mutation_consequence_attrib` set('21','22','23','24','25','26','27','28','29','30','44') DEFAULT NULL,
  `panel_attrib` tinyint(1) DEFAULT NULL,
  `restricted_mutation_set` tinyint(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`genomic_feature_disease_id`),
  UNIQUE KEY `genomic_feature_disease` (`genomic_feature_id`,`allelic_requirement_attrib`,`mutation_consequence_attrib`,`disease_id`),
  KEY `genomic_feature_idx` (`genomic_feature_id`),
  KEY `disease_idx` (`disease_id`),
  CONSTRAINT `genomic_feature_disease_ibfk_1` FOREIGN KEY (`genomic_feature_id`) REFERENCES `genomic_feature` (`genomic_feature_id`),
  CONSTRAINT `genomic_feature_disease_ibfk_2` FOREIGN KEY (`disease_id`) REFERENCES `disease` (`disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4685 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_comment` (
  `genomic_feature_disease_comment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `comment_text` text,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_comment_id`),
  KEY `GFD_idx` (`genomic_feature_disease_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `genomic_feature_disease_comment_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_comment_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=238 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_deleted` (
  `genomic_feature_disease_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_id` int(10) unsigned NOT NULL,
  `disease_id` int(10) unsigned NOT NULL,
  `allelic_requirement_attrib` set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20') DEFAULT NULL,
  `mutation_consequence_attrib` set('21','22','23','24','25','26','27','28','29','30','44') DEFAULT NULL,
  `deleted` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `deleted_by_user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_id`),
  KEY `genomic_feature_idx` (`genomic_feature_id`),
  KEY `disease_idx` (`disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4586 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_log` (
  `genomic_feature_disease_log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `genomic_feature_id` int(10) unsigned NOT NULL,
  `disease_id` int(10) unsigned NOT NULL,
  `allelic_requirement_attrib` set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20') DEFAULT NULL,
  `mutation_consequence_attrib` set('21','22','23','24','25','26','27','28','29','30','44') DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  `action` varchar(128) NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_log_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  KEY `genomic_feature_id` (`genomic_feature_id`),
  KEY `disease_id` (`disease_id`),
  CONSTRAINT `genomic_feature_disease_log_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_log_ibfk_2` FOREIGN KEY (`genomic_feature_id`) REFERENCES `genomic_feature` (`genomic_feature_id`),
  CONSTRAINT `genomic_feature_disease_log_ibfk_3` FOREIGN KEY (`disease_id`) REFERENCES `disease` (`disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4111 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_organ` (
  `genomic_feature_disease_organ_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `organ_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_organ_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  KEY `organ_id` (`organ_id`),
  CONSTRAINT `genomic_feature_disease_organ_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_organ_ibfk_2` FOREIGN KEY (`organ_id`) REFERENCES `organ` (`organ_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9424 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_organ_deleted` (
  `genomic_feature_disease_organ_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `organ_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_organ_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8987 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_panel` (
  `genomic_feature_disease_panel_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `confidence_category_attrib` set('31','32','33','34','35') DEFAULT NULL,
  `is_visible` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `panel_attrib` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`genomic_feature_disease_panel_id`),
  UNIQUE KEY `gfd_panel_idx` (`genomic_feature_disease_id`,`panel_attrib`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_panel_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3736 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_panel_deleted` (
  `genomic_feature_disease_panel_deleted_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_panel_id` int(10) unsigned NOT NULL,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `confidence_category_attrib` set('31','32','33','34','35') DEFAULT NULL,
  `is_visible` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `panel_attrib` tinyint(1) DEFAULT NULL,
  `deleted` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `deleted_by_user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_panel_deleted_id`),
  UNIQUE KEY `gfd_panel_idx` (`genomic_feature_disease_id`,`panel_attrib`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_panel_log` (
  `genomic_feature_disease_panel_log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_panel_id` int(10) unsigned NOT NULL,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `confidence_category_attrib` set('31','32','33','34','35') DEFAULT NULL,
  `is_visible` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `panel_attrib` tinyint(1) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(10) unsigned NOT NULL,
  `action` varchar(128) NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_panel_log_id`),
  KEY `genomic_feature_disease_panel_idx` (`genomic_feature_disease_panel_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_panel_log_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_panel_log_ibfk_2` FOREIGN KEY (`genomic_feature_disease_panel_id`) REFERENCES `genomic_feature_disease_panel` (`genomic_feature_disease_panel_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4208 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_phenotype` (
  `genomic_feature_disease_phenotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `phenotype_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_phenotype_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  KEY `phenotype_id` (`phenotype_id`),
  CONSTRAINT `genomic_feature_disease_phenotype_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_phenotype_ibfk_2` FOREIGN KEY (`phenotype_id`) REFERENCES `phenotype` (`phenotype_id`)
) ENGINE=InnoDB AUTO_INCREMENT=52082 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_phenotype_deleted` (
  `genomic_feature_disease_phenotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `phenotype_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_phenotype_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=51732 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_publication` (
  `genomic_feature_disease_publication_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `publication_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_publication_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`),
  KEY `publication_id` (`publication_id`),
  CONSTRAINT `genomic_feature_disease_publication_ibfk_1` FOREIGN KEY (`genomic_feature_disease_id`) REFERENCES `genomic_feature_disease` (`genomic_feature_disease_id`),
  CONSTRAINT `genomic_feature_disease_publication_ibfk_2` FOREIGN KEY (`publication_id`) REFERENCES `publication` (`publication_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10355 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_disease_publication_deleted` (
  `genomic_feature_disease_publication_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_disease_id` int(10) unsigned NOT NULL,
  `publication_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genomic_feature_disease_publication_id`),
  KEY `genomic_feature_disease_idx` (`genomic_feature_disease_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10054 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_statistic` (
  `genomic_feature_statistic_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genomic_feature_id` int(10) unsigned DEFAULT NULL,
  `panel_attrib` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`genomic_feature_statistic_id`),
  KEY `genomic_feature_idx` (`genomic_feature_id`),
  CONSTRAINT `genomic_feature_statistic_ibfk_1` FOREIGN KEY (`genomic_feature_id`) REFERENCES `genomic_feature` (`genomic_feature_id`)
) ENGINE=InnoDB AUTO_INCREMENT=94 DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_statistic_attrib` (
  `genomic_feature_statistic_id` int(10) unsigned NOT NULL,
  `attrib_type_id` int(10) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  KEY `genomic_feature_statistic_idx` (`genomic_feature_statistic_id`),
  KEY `type_value_idx` (`attrib_type_id`,`value`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genomic_feature_synonym` (
  `genomic_feature_id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  UNIQUE KEY `name` (`genomic_feature_id`,`name`),
  KEY `genomic_feature_idx` (`genomic_feature_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `meta` (
  `meta_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned DEFAULT '1',
  `meta_key` varchar(40) NOT NULL,
  `meta_value` varchar(255) NOT NULL,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `species_key_value_idx` (`species_id`,`meta_key`,`meta_value`),
  KEY `species_value_idx` (`species_id`,`meta_value`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

CREATE TABLE `organ` (
  `organ_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`organ_id`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=latin1;

CREATE TABLE `organ_panel` (
  `organ_id` int(10) unsigned NOT NULL,
  `panel_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`organ_id`,`panel_id`),
  KEY `organ_panel_idx` (`organ_id`,`panel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `panel` (
  `panel_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `is_visible` tinyint(1) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`panel_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;

CREATE TABLE `phenotype` (
  `phenotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `stable_id` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `source` varchar(24) DEFAULT NULL,
  PRIMARY KEY (`phenotype_id`),
  UNIQUE KEY `desc_idx` (`description`),
  KEY `name_idx` (`name`),
  KEY `stable_idx` (`stable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15233 DEFAULT CHARSET=latin1;

CREATE TABLE `phenotype_mapping` (
  `mesh_id` int(10) unsigned NOT NULL,
  `phenotype_id` int(10) unsigned NOT NULL,
  `source` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`mesh_id`,`phenotype_id`),
  KEY `phenotype_mapping_idx` (`mesh_id`,`phenotype_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `publication` (
  `publication_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `pmid` int(10) DEFAULT NULL,
  `title` mediumtext,
  `source` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`publication_id`),
  KEY `pmid_idx` (`pmid`)
) ENGINE=InnoDB AUTO_INCREMENT=28298 DEFAULT CHARSET=utf8;

CREATE TABLE `search` (
  `search_term` varchar(255) NOT NULL,
  PRIMARY KEY (`search_term`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `user` (
  `user_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `panel_attrib` set('36','37','38','39','40','41','42','43','45','46','47','48') DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_idx` (`username`),
  UNIQUE KEY `email_idx` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;

