#!/usr/bin/env python3

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""

"""

import os
import sys
import argparse
import re
import mysql.connector
from mysql.connector import Error
import requests
import datetime

### Fetch data from current db ###
def fetch_attribs(host, port, db, user, password):
    result_data = {}

    sql_query = f""" SELECT a.attrib_id, a.value, at.code, at.name, at.description
                     FROM attrib a
                     LEFT JOIN attrib_type at ON a.attrib_type_id = at.attrib_type_id """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result_data[row[0]] = { 'attrib_value':row[1],
                                            'attrib_type_code':row[2],
                                            'attrib_type_name':row[3],
                                            'attrib_type_description':row[4]}

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result_data

def dump_panels(host, port, db, user, password):
    result_data = {}

    sql_query = f""" SELECT name, is_visible
                     FROM panel """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result_data[row[0]] = { 'is_visible':row[1] }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result_data

def dump_users(host, port, db, user, password, attribs):
    users_data = {}

    sql_query_user = f""" SELECT username, email, panel_attrib
                          FROM user """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_user)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    # print(f"user: {row[0]}, email: {row[1]}, panel_attrib: {list(row[2])}")
                    panel_names = []
                    for panel in list(row[2]):
                        # print(f"attrib: {panel}, {attribs[int(panel)]['attrib_value']}")
                        panel_names.append(attribs[int(panel)]['attrib_value'])
                    users_data[row[0]] = { 'email':row[1],
                                           'panels':panel_names }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return users_data

def dump_publications(host, port, db, user, password):
    result = {}
    duplicated_pmids = {}

    sql_query = f""" SELECT publication_id, pmid, title, source
                     FROM publication """
    
    sql_query_duplicates = f""" SELECT pmid 
                                FROM publication 
                                WHERE pmid IS NOT NULL
                                GROUP BY pmid HAVING count(*)>1
                            """

    sql_query_gfd = f""" SELECT distinct publication_id
                         FROM genomic_feature_disease_publication
                         WHERE publication_id in ( SELECT publication_id FROM publication WHERE pmid = %s ) """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_duplicates)
            data_dup = cursor.fetchall()
            if len(data_dup) != 0:
                for row in data_dup:
                    pmid = row[0]
                    cursor.execute(sql_query_gfd, [pmid])
                    data_gfd = cursor.fetchall()
                    if len(data_gfd) == 0:
                        duplicated_pmids[pmid] = 1

            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    if row[1] not in duplicated_pmids and row[2] is not None and row[2] != '':
                        # Check if publication is being used
                        cursor.execute(sql_query_gfd, [row[1]])
                        data_gfd_2 = cursor.fetchall()
                        if len(data_gfd_2) != 0:
                            result[row[0]] = { 'pmid':row[1],
                                           'title':row[2],
                                           'source':row[3] }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result

def dump_phenotype(host, port, db, user, password):
    result = {}

    sql_query_user = f""" SELECT phenotype_id, stable_id, name, description, source
                          FROM phenotype """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_user)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result[row[0]] = { 'stable_id':row[1],
                                       'name':row[2],
                                       'description':row[3],
                                       'source':row[4] }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result

def dump_organ(host, port, db, user, password):
    result = {}

    sql_query_user = f""" SELECT organ_id, name
                          FROM organ """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_user)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result[row[0]] = row[1]

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result

def dump_ontology(host, port, db, user, password, attribs):
    so_mapping = {  '5_prime or 3_prime UTR mutation':{'so':'SO:NA', 'description':'NA'},
                    'absent gene product':{'so':'SO:0002317', 'description':'A sequence variant that results in no gene product'},
                    'altered gene product structure':{'so':'SO:0002318', 'description':'A sequence variant that alters the structure of a gene product'},
                    'cis-regulatory or promotor mutation':{'so':'SO:NA', 'description':'NA'},
                    'decreased gene product level':{'so':'SO:0002316', 'description':'A sequence variant that decreases the level or amount of gene product produced'},
                    'increased gene product level':{'so':'SO:0002315', 'description':'A variant that increases the level or amount of gene product produced'},
                    'uncertain':{'so':'SO:0002220', 'description':'A sequence variant in which the function of a gene product is unknown with respect to a reference'}
                 }
    result = {}
    result_disease = {}

    sql_query = f""" SELECT a.attrib_id, a.value, at.code, at.name, at.description
                     FROM attrib a
                     LEFT JOIN attrib_type at ON a.attrib_type_id = at.attrib_type_id
                     WHERE at.code = 'mutation_consequence' """
    
    sql_query_disease = """ SELECT d.disease_id, d.ontology_term_id, d.mapped_by_attrib, o.ontology_accession, o.description
                            FROM disease_ontology_mapping d
                            LEFT JOIN ontology_term o ON d.ontology_term_id = o.ontology_term_id
                        """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result[row[0]] = { 'attrib_value':row[1],
                                       'attrib_type_code':row[2],
                                       'attrib_type_name':row[3],
                                       'attrib_type_description':row[4],
                                       'so_term':so_mapping[row[1]]['so'],
                                       'so_description':so_mapping[row[1]]['description'] }

            cursor.execute(sql_query_disease)
            data_disease = cursor.fetchall()
            if len(data_disease) != 0:
                for row in data_disease:
                    # Fetch ontology (MONDO) info
                    url = f"https://www.ebi.ac.uk/ols4/api/search?q={row[3]}&ontology=mondo&exact=1"
                    # print(f"{row[3]}")
                    mondo_description = get_mondo(url, row[3])
                    # print(f"Description: {mondo_description}")
                    result_disease[row[0]] = { 'ontology_term_id':row[1],
                                               'mapped_by_attrib':attribs[int(list(row[2])[0])]['attrib_value'],
                                               'ontology_accession':row[3],
                                               'ontology_description':row[4],
                                               'mondo_description':mondo_description }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result, result_disease

def dump_diseases(host, port, db, user, password):
    result = {}

    sql_query_user = f""" SELECT disease_id, name, mim
                          FROM disease """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_user)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result[row[0]] = { 'disease_name':row[1],
                                       'disease_mim':row[2] }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result

def dump_genes(host, port, db, user, password):
    result = {}

    sql_query = f""" SELECT genomic_feature_id, gene_symbol, hgnc_id, mim, ensembl_stable_id
                     FROM genomic_feature """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    result[row[0]] = { 'gene_symbol':row[1],
                                       'hgnc_id':row[2],
                                       'mim':row[3],
                                       'ensembl_stable_id':row[4]  }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result

def dump_gfd(host, port, db, user, password, attribs):
    result = {}
    last_update = {}
    last_update_panel = {}

    sql_query = """  SELECT gfd.genomic_feature_disease_id, gfd.genomic_feature_id, gfd.disease_id, d.name, gfd.allelic_requirement_attrib, gfd.cross_cutting_modifier_attrib, gfd.mutation_consequence_attrib, gfd.mutation_consequence_flag_attrib, gfd.variant_consequence_attrib, gfd.restricted_mutation_set, gf.gene_symbol
                     FROM genomic_feature_disease gfd
                     LEFT JOIN disease d ON d.disease_id = gfd.disease_id 
                     LEFT JOIN genomic_feature gf ON gf.genomic_feature_id = gfd.genomic_feature_id"""
    
    sql_query_panel = f""" SELECT panel_attrib, clinical_review, is_visible, confidence_category_attrib
                           FROM genomic_feature_disease_panel
                           WHERE genomic_feature_disease_id = %s
                       """

    sql_query_organ = f""" SELECT gfd.genomic_feature_disease_id, gfd.organ_id, o.name
                           FROM genomic_feature_disease_organ gfd
                           LEFT JOIN organ o ON o.organ_id = gfd.organ_id
                           WHERE gfd.genomic_feature_disease_id = %s
                       """

    sql_query_publication = f""" SELECT gfd.publication_id, c.comment_text, c.created, c.user_id
                                 FROM genomic_feature_disease_publication gfd
                                 LEFT JOIN GFD_publication_comment c ON c.genomic_feature_disease_publication_id = gfd.genomic_feature_disease_publication_id
                                 WHERE gfd.genomic_feature_disease_id = %s
                             """

    sql_query_phenotype = f""" SELECT gfd.phenotype_id, c.comment_text, c.created, c.user_id
                               FROM genomic_feature_disease_phenotype gfd
                               LEFT JOIN GFD_phenotype_comment c ON c.genomic_feature_disease_phenotype_id = gfd.genomic_feature_disease_phenotype_id
                               WHERE gfd.genomic_feature_disease_id = %s
                          """

    sql_query_date = """ SELECT gfd.genomic_feature_disease_id, d.created 
                         FROM genomic_feature_disease gfd
                         LEFT JOIN genomic_feature_disease_log d ON d.genomic_feature_disease_id = gfd.genomic_feature_disease_id 
                         WHERE d.created IS NOT NULL """

    sql_query_date_panel = """ SELECT gfd.genomic_feature_disease_id, d.created from
                               genomic_feature_disease gfd
                               LEFT JOIN genomic_feature_disease_panel_log d ON d.genomic_feature_disease_id = gfd.genomic_feature_disease_id 
                               WHERE d.created is not null """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    save = 0
                    panels = {}
                    gfd_id = row[0]
                    # print(f"\ngfd_id: {gfd_id}, {row[3]}")

                    # Check if entry is in a panel
                    cursor.execute(sql_query_panel, [gfd_id])
                    data_panel = cursor.fetchall()
                    if len(data_panel) != 0:
                        for row_panel in data_panel:
                            # print(f"Found in panel: {row_panel[0]}")
                            if row_panel[0] != 46:
                                save = 1
                                panels[attribs[row_panel[0]]['attrib_value']] = { 'clinical_review':row_panel[1],
                                                                                  'is_visible':row_panel[2],
                                                                                  'confidence_category':attribs[row_panel[3]]['attrib_value']  }                               
                    # else:
                    #     print("--- Not found in panel ---")
                    
                    if save == 1:
                        allelic_requirement = attribs[int(list(row[4])[0])]['attrib_value']
                        cross_cutting_modifier = []
                        if row[5] is not None:
                            for ccm in list(row[5]):
                                cross_cutting_modifier.append(attribs[int(ccm)]['attrib_value'])
                        mutation_consequence = []
                        for mc in list(row[6]):
                            mutation_consequence.append(attribs[int(mc)]['attrib_value'])
                        mc_flag = []
                        if row[7] is not None:
                            for mc in list(row[7]):
                                mc_flag.append(attribs[int(mc)]['attrib_value'])
                        variant_consequence = []
                        if row[8] is not None:
                            for mc in list(row[8]):
                                variant_consequence.append(attribs[int(mc)]['attrib_value'])

                        organs = []
                        cursor.execute(sql_query_organ, [gfd_id])
                        data_organ = cursor.fetchall()
                        if len(data_organ) != 0:
                            for row_organ in data_organ:
                                organs.append(row_organ[2])

                        publications = {}
                        cursor.execute(sql_query_publication, [gfd_id])
                        data_pub = cursor.fetchall()
                        if len(data_pub) != 0:
                            for row_pub in data_pub:
                                publications[row_pub[0]] = { 'comment':row_pub[1],
                                                              'date':row_pub[2],
                                                              'user':row_pub[3] }
                        
                        phenotypes = {}
                        cursor.execute(sql_query_phenotype, [gfd_id])
                        data_pheno = cursor.fetchall()
                        if len(data_pheno) != 0:
                            for row_pheno in data_pheno:
                                phenotypes[row_pheno[0]] = { 'comment':row_pheno[1],
                                                             'date':row_pheno[2],
                                                             'user':row_pheno[3] }

                        result[gfd_id] = { 'genomic_feature_id':row[1],
                                           'gene_symbol':row[10],
                                           'disease_id':row[2],
                                           'disease_name':row[3],
                                           'allelic_requirement_attrib':allelic_requirement,
                                           'cross_cutting_modifier_attrib':cross_cutting_modifier,
                                           'mutation_consequence_attrib':mutation_consequence,
                                           'mutation_consequence_flag_attrib':mc_flag,
                                           'variant_consequence_attrib':variant_consequence,
                                           'restricted_mutation_set':row[9],
                                           'panels':panels,
                                           'organs':organs,
                                           'publications':publications,
                                           'phenotypes':phenotypes }

            cursor.execute(sql_query_date)
            data_date = cursor.fetchall()
            if len(data_date) != 0:
                for row_date in data_date:
                    if row_date[0] in last_update:
                        if row_date[1] > last_update[row_date[0]]:
                            last_update[row_date[0]] = row_date[1]
                    else:
                        last_update[row_date[0]] = row_date[1]

            cursor.execute(sql_query_date_panel)
            data_date = cursor.fetchall()
            if len(data_date) != 0:
                for row_date in data_date:
                    if row_date[0] in last_update_panel:
                        if row_date[1] > last_update_panel[row_date[0]]:
                            last_update_panel[row_date[0]] = row_date[1]
                    else:
                        last_update_panel[row_date[0]] = row_date[1]

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result, last_update, last_update_panel

def get_mondo(url, id):
    r = requests.get(url, headers={ "Content-Type" : "application/json"})

    if not r.ok:
        r.raise_for_status()
        sys.exit()

    decoded = r.json()
    # print(f"{url} : {decoded}")
    if id.startswith("MONDO") and len(decoded['response']['docs'][0]['description']) > 0:
        description = decoded['response']['docs'][0]['description'][0]
    else:
        description = ''

    return description

def get_publication(url):
    r = requests.get(url, headers={ "Content-Type" : "application/json"})
    decoded = None

    if not r.ok:
        r.raise_for_status()
        sys.exit()

    decoded = r.json()

    return decoded

######

### Populate new db ###
def populate_source(host, port, db, user, password):
    sources_info = {   'SO': {'description':'Sequence Ontology', 'url':'https://www.sequenceontology.org'},
                       'HPO': {'description':'Human Phenotype Ontology', 'url':'https://hpo.jax.org'},
                       'Mondo': {'description':'Mondo Disease Ontology', 'url':'https://www.ebi.ac.uk/ols4/ontologies/mondo'},
                       'OMIM': {'description':'Online Catalog of Human Genes and Genetic Disorders', 'url':'https://www.omim.org'},
                       'Orphanet': {'description':'The portal for rare diseases and orphan drugs', 'url':'https://www.orpha.net/consor/cgi-bin/index.php'},
                       'HGNC': {'description':'HUGO Gene Nomenclature Committee', 'url':'https://www.genenames.org'},
                       'Ensembl': {'description':'Ensembl', 'url':'https://www.ensembl.org'},
                       'UniProt': {'description':'Gene function imported from UniProt', 'url':'https://www.uniprot.org'}
                      }

    sql_query = f""" INSERT INTO source (name, description, url)
                     VALUES (%s, %s, %s)
                 """
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for name, info in sources_info.items():
                cursor.execute(sql_query, [name, info['description'], info['url']])
                connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

def populate_attribs(host, port, db, user, password, attribs):
    attrib_types = {}

    ar_mapping = {
        'biallelic_autosomal':'biallelic_autosomal',
        'biallelic_PAR':'biallelic_PAR',
        'mitochondrial':'mitochondrial',
        'monoallelic_autosomal':'monoallelic_autosomal',
        'monoallelic_PAR':'monoallelic_PAR',
        'monoallelic_X_hem':'monoallelic_X_hemizygous',
        'monoallelic_X_het':'monoallelic_X_heterozygous',
        'monoallelic_Y_hem':'monoallelic_Y_hemizygous'
    }

    ccm_mapping = {
        'imprinted':'imprinted region',
        'potential IF':'potential secondary finding',
        'requires heterozygosity':'requires heterozygosity', # CHECK
        'typically de novo':'typically de novo',
        'typically mosaic':'typically mosaic',
        'typified by age related penetrance':'typified by age related penetrance',
        'typified by reduced penetrance':'typified by incomplete penetrance'
    }

    so_mapping = { 'absent gene product':'SO:0002317', 'altered gene product structure':'SO:0002318', 'decreased gene product level':'SO:0002316',
                   'increased gene product level': 'SO:0002315', 'uncertain': 'SO:0002220',
                   '3_prime_UTR_variant':'SO:0001624',
                   '5_prime_UTR_variant':'SO:0001623',
                   'frameshift_variant':'SO:0001589',
                   'frameshift_variant_NMD_escaping':'SO:0002324',
                   'frameshift_variant_NMD_triggering':'SO:0002323',
                   'inframe_deletion':'SO:0001822',
                   'inframe_insertion':'SO:0001821',
                    'intergenic_variant':'SO:0001628',
                    'intron_variant':'SO:0001627',
                    'missense_variant':'SO:0001583',
                    'NMD_escaping':'SO:0002320',
                    'NMD_triggering':'SO:0002319',
                    'regulatory_region_variant':'SO:0001566',
                    'splice_acceptor_variant':'SO:0001574',
                    'splice_acceptor_variant_NMD_escaping':'SO:0002328',
                    'splice_acceptor_variant_NMD_triggering':'SO:0002327',
                    'splice_donor_variant':'SO:0001575',
                    'splice_donor_variant_NMD_escaping':'SO:0002326',
                    'splice_donor_variant_NMD_triggering':'SO:0002325',
                    'splice_region_variant':'SO:0001630',
                    'start_lost':'SO:0002012',
                    'stop_gained':'SO:0001587',
                    'stop_gained_NMD_escaping':'SO:0002322',
                    'stop_gained_NMD_triggering':'SO:0002321',
                    'stop_lost':'SO:0001578',
                    'synonymous_variant':'SO:0001819',
                    }

    for attrib in attribs:
        if attribs[attrib]['attrib_type_code'] not in attrib_types:
            attrib_types[attribs[attrib]['attrib_type_code']] = { 'name':attribs[attrib]['attrib_type_name'],
                                                                  'description':attribs[attrib]['attrib_type_description'] }

    sql_query = f""" INSERT INTO attrib_type (code, name, description)
                     VALUES (%s, %s, %s)
                 """
    
    sql_query_attrib = f""" INSERT INTO attrib (value, type_id)
                            VALUES (%s, %s)
                        """
    
    sql_query_ontology_term = f""" INSERT INTO ontology_term (accession, term, source_id)
                                   VALUES (%s, %s, %s)
                               """
    
    inserted_attrib_type = {}
    inserted_attrib = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()

            for type in attrib_types:
                # print(f"type: {type}, {attrib_types[type]}")
                if type == 'confidence_category' or type == 'cross_cutting_modifier' or type == 'ontology_mapping':
                    cursor.execute(sql_query, [type, attrib_types[type]['name'], attrib_types[type]['description']])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid
                elif type == 'allelic_requirement':
                    cursor.execute(sql_query, ['genotype', 'genotype', 'Mendelian inheritance terms (previously: allelic_requirement)'])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid
                elif type == 'mutation_consequence':
                    cursor.execute(sql_query, ['mutation_consequence', 'Mutation consequence', 'Mutation consequence (deprecated)'])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid
                elif type == 'mutation_consequence_flag':
                    cursor.execute(sql_query, ['mutation_consequence_flag', 'Mutation consequence flag', 'Mutation consequence flag (deprecated)'])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid

            for old_id in attribs:
                if attribs[old_id]['attrib_type_code'] in inserted_attrib_type:
                    if attribs[old_id]['attrib_type_code'] == 'allelic_requirement':
                        mapping = ar_mapping[attribs[old_id]['attrib_value']]
                    elif attribs[old_id]['attrib_type_code'] == 'cross_cutting_modifier':
                        mapping = ccm_mapping[attribs[old_id]['attrib_value']]
                    else:
                        mapping = attribs[old_id]['attrib_value']
                    cursor.execute(sql_query_attrib, [mapping, inserted_attrib_type[attribs[old_id]['attrib_type_code']]])
                    connection.commit()
                    inserted_attrib[attribs[old_id]['attrib_value']] = { 'old_id':old_id, 'new_id':cursor.lastrowid }

            for old_id in attribs:
                if (attribs[old_id]['attrib_type_code'] == 'mutation_consequence' or attribs[old_id]['attrib_type_code'] == 'variant_consequence') and attribs[old_id]['attrib_value'] in so_mapping.keys():
                    cursor.execute(sql_query_ontology_term, [so_mapping[attribs[old_id]['attrib_value']], attribs[old_id]['attrib_value'], 1])
                    connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    # print(f"Inserted attrib type: {inserted_attrib_type}")
    # print(f"Inserted attribs: {inserted_attrib}")

def populate_new_attribs(host, port, db, user, password):
    attrib_types = {   'mechanism':'Type of molecular mechanism' ,
                       'mechanism_synopsis':'Synopsis of the molecular mechanism',
                       'support': 'The support can be inferred by the curator or taken from evidence in the paper',
                       'locus_type':'Locus type',
                       'reference':'Assembly reference',
                       'gene_synonym':'Gene symbol synonym',
                       'disease_synonym':'Disease synonym'
                      }

    attribs = {        'loss of function':'mechanism',
                       'dominant negative':'mechanism',
                       'gain of function':'mechanism',
                       'undetermined non-loss-of-function':'mechanism',
                       'undetermined':'mechanism',
                       'destabilising LOF':'mechanism_synopsis',
                       'interaction-disrupting LOF':'mechanism_synopsis',
                       'loss of activity LOF':'mechanism_synopsis',
                       'LOF due to protein mislocalisation':'mechanism_synopsis',
                       'assembly-mediated dominant negative':'mechanism_synopsis',
                       'competitive dominant-negative':'mechanism_synopsis',
                       'assembly-mediated GOF':'mechanism_synopsis',
                       'protein aggregation':'mechanism_synopsis',
                       'local LOF leading to overall GOF':'mechanism_synopsis',
                       'other GOF':'mechanism_synopsis',
                       'inferred':'support',
                       'evidence':'support',
                       'gene':'locus_type',
                       'variant':'locus_type',
                       'region':'locus_type',
                       'grch38':'reference',
                       'refuted':'confidence_category',
                       'disputed':'confidence_category',
                       'dyadic_name': 'disease_synonym'
                     }

    sql_query = f""" INSERT INTO attrib_type (code, name, description)
                     VALUES (%s, %s, %s)
                 """
    
    sql_query_attrib = f""" INSERT INTO attrib (value, type_id)
                            VALUES (%s, %s)
                        """

    inserted = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for mt, description in attrib_types.items():
                cursor.execute(sql_query, [mt, mt, description])
                connection.commit()
                inserted[mt] = cursor.lastrowid
            
            for data, t in attribs.items():
                if t == 'confidence_category':
                    attrib_type_id = 1
                else:
                    attrib_type_id = inserted[t]
                cursor.execute(sql_query_attrib, [data, attrib_type_id])
                connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

def populates_user_panel(host, port, db, user, password, user_panel_data, panels_data):
    attrib_types = {}

    sql_query_user = f""" INSERT INTO user (username, email, is_staff, is_active, is_deleted, password, is_superuser)
                          VALUES (%s, %s, %s, %s, %s, %s, %s)
                      """
    
    sql_query_panel = f""" INSERT INTO panel (name, is_visible)
                            VALUES (%s, %s)
                        """
    
    sql_query_user_panel = f""" INSERT INTO user_panel (is_deleted, panel_id, user_id)
                                VALUES (%s, %s, %s)
                            """
    
    inserted_user = {}
    inserted_panel = {}
    is_active = 1
    is_deleted = 0

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()

            for panel in panels_data:
                cursor.execute(sql_query_panel, [panel, panels_data[panel]['is_visible']])
                connection.commit()
                inserted_panel[panel] = cursor.lastrowid
            
            for username in user_panel_data:
                if username != 'diana_lemos': # TODO: remove 
                    if username == 'anja_thormann' or username == 'fiona_cunningham' or username == 'david_fitzpatrick':
                        is_active = 0
                    else:
                        is_active = 1
                    cursor.execute(sql_query_user, [username, user_panel_data[username]['email'], 0, is_active, 0, 'g2p_default_2024', 0])
                    connection.commit()
                    inserted_user[username] = cursor.lastrowid
                    for p in user_panel_data[username]['panels']:
                        cursor.execute(sql_query_user_panel, [is_deleted, inserted_panel[p], inserted_user[username]])
                        connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

def populates_publications(host, port, db, user, password, publication_data):
    sql_query = f""" INSERT INTO publication (pmid, title, source, authors, year)
                     VALUES (%s, %s, %s, %s, %s)
                 """
    
    inserted_publication = {}
    pmids = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()

            for old_id in publication_data:
                # Avoid duplicated PMIDs
                # Do not insert publication with empty title
                if ((publication_data[old_id]['pmid'] is not None and publication_data[old_id]['pmid'] not in pmids) or publication_data[old_id]['pmid'] is None) and publication_data[old_id]['title'] is not None:
                    source = publication_data[old_id]['source']
                    if (source is not None and source.startswith('1993')) or source == ' ':
                        source = None

                    # Get authors and year from EuropePMC
                    url = f"https://www.ebi.ac.uk/europepmc/webservices/rest/article/MED/{publication_data[old_id]['pmid']}?format=json"
                    response = get_publication(url)
                    authors = None
                    year = None
                    if response:
                        if 'authorString' in response['result']:
                            authors = response['result']['authorString']
                            if len(authors) > 250:
                                authors_split = authors.split(',')
                                authors = f"{authors_split[0]} et al."
                        if 'pubYear' in response['result']:
                            year = response['result']['pubYear']

                    # Insert publication
                    cursor.execute(sql_query, [publication_data[old_id]['pmid'], publication_data[old_id]['title'], source, authors, year])
                    connection.commit()
                    inserted_publication[old_id] = {'new_id':cursor.lastrowid}
                    pmids[publication_data[old_id]['pmid']] = 1

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return inserted_publication

def populates_phenotypes(host, port, db, user, password, phenotype_data):
    sql_query_ontology_term = f""" INSERT INTO ontology_term (accession, term, description, source_id)
                                   VALUES (%s, %s, %s, %s)
                               """

    inserted_ontology_term = {}
    inserted_phenotypes = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for old_id in phenotype_data:
                cursor.execute(sql_query_ontology_term, [phenotype_data[old_id]['stable_id'], phenotype_data[old_id]['name'], phenotype_data[old_id]['description'], 2])
                connection.commit()
                inserted_phenotypes[old_id] = {'new_id':cursor.lastrowid}

                connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return inserted_phenotypes

def populates_disease(host, port, db, user, password, disease_data, disease_ontology_data):
    sql_query_ontology_term = f""" INSERT INTO ontology_term (accession, term, description, source_id)
                                   VALUES (%s, %s, %s, %s)
                               """

    sql_query = f""" INSERT INTO disease (name, mim)
                     VALUES (%s, %s)
                 """
    
    sql_query_disease_ontology = f""" INSERT INTO disease_ontology (disease_id, mapped_by_attrib_id, ontology_term_id)
                                      VALUES (%s, %s, %s)
                                 """

    mapping = { 'Data source':fetch_attrib(host, port, db, user, password, 'Data source'), 
                'OLS exact':fetch_attrib(host, port, db, user, password, 'OLS exact'), 
                'Manual':fetch_attrib(host, port, db, user, password, 'Manual'), 
                'OLS partial':fetch_attrib(host, port, db, user, password, 'OLS partial') 
              }

    inserted_mondo = {}
    inserted_ontology_term = {} # contains old (from disease) and new ontology_term ids
    inserted_disease = {}
    inserted_disease_by_name = {}
    source_id = 0
    description = None
    duplicated_ontology = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            # Insert into ontology_term
            for old_id, ontology in disease_ontology_data.items():
                if old_id not in inserted_ontology_term:
                    if ontology['ontology_accession'] in inserted_mondo:
                        duplicated_ontology[ontology['ontology_accession']] = 1
                    else:
                        if ontology['ontology_accession'].startswith('MONDO'):
                            source_id = 3
                            if ontology['mondo_description'] == '':
                                description = None
                            else:
                                description = ontology['mondo_description']
                        elif ontology['ontology_accession'].startswith('OMIM'):
                            source_id = 4
                            description = ontology['ontology_description']
                        elif ontology['ontology_accession'].startswith('Orphanet'):
                            source_id = 5
                            description = ontology['ontology_description']
                        cursor.execute(sql_query_ontology_term, [ontology['ontology_accession'], ontology['ontology_accession'], description, source_id])
                        connection.commit()
                        inserted_ontology_term[old_id] = { 'new_ontology_term_id':cursor.lastrowid }
                        inserted_mondo[ontology['ontology_accession']] = inserted_ontology_term[old_id]

            # Insert into disease
            for old_id in disease_data:
                name = disease_data[old_id]['disease_name']
                clean_name = clean_up_disease_name(name)
                if clean_name not in inserted_disease_by_name:
                    cursor.execute(sql_query, [name, disease_data[old_id]['disease_mim']])
                    connection.commit()
                    inserted_disease[old_id] = { 'new_disease_id':cursor.lastrowid }
                    inserted_disease_by_name[clean_name] =  { 'new_disease_id':inserted_disease[old_id]['new_disease_id'] }
                else:
                    inserted_disease[old_id] = { 'new_disease_id':inserted_disease_by_name[clean_name]['new_disease_id'] }

            # Insert into disease_ontology
            for disease_old_id, ontology in disease_ontology_data.items():
                # print(f"\ndisease old id: {disease_old_id}, ontology data: {ontology}")
                new_disease_id = inserted_disease[disease_old_id]['new_disease_id']
                new_ontology_id = inserted_mondo[ontology['ontology_accession']]['new_ontology_term_id']
                # print(f"New disease id: {new_disease_id}, new ontology id: {new_ontology_id}")
                cursor.execute(sql_query_disease_ontology, [new_disease_id,  mapping[ontology['mapped_by_attrib']], new_ontology_id])
                connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return inserted_disease_by_name

def populates_locus(host, port, db, user, password, genomic_feature_data, gene_symbols, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password):
    sql_genes = """ SELECT g.stable_id, s.name, g.seq_region_start, g.seq_region_end, g.seq_region_strand
                    FROM gene g
                    LEFT JOIN seq_region s on s.seq_region_id = g.seq_region_id
                    WHERE s.coord_system_id = 4
                """

    sql_sequence = f""" INSERT INTO sequence (name, reference_id)
                        VALUES (%s, %s)
                    """

    sql_query = f""" INSERT INTO locus (sequence_id, start, end, strand, name, type_id)
                     VALUES (%s, %s, %s, %s, %s, %s)
                 """

    sql_query_ids = f""" INSERT INTO locus_identifier (locus_id, identifier, source_id)
                         VALUES (%s, %s, %s)
                     """

    sql_meta = f""" INSERT INTO meta (`key`, date_update, is_public, description, source_id, version)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """

    genes = {}

    # Connect to Ensembl db
    connection_ensembl = mysql.connector.connect(host=ensembl_host,
                                                 database=ensembl_db,
                                                 user=ensembl_user,
                                                 port=ensembl_port,
                                                 password=ensembl_password)

    try:
        if connection_ensembl.is_connected():
            cursor = connection_ensembl.cursor()
            cursor.execute(sql_genes)
            data_genes = cursor.fetchall()
            if len(data_genes) != 0:
                for gene in data_genes:
                    if gene[0] not in genes.keys():
                        genes[gene[0]] = { 'sequence':gene[1],
                                           'start':gene[2],
                                           'end':gene[3],
                                           'strand':gene[4] }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection_ensembl.is_connected():
            cursor.close()
            connection_ensembl.close()

    locus_type_id = fetch_attrib(host, port, db, user, password, 'gene')
    reference_id = fetch_attrib(host, port, db, user, password, 'grch38')
    hgnc_source_id = fetch_source(host, port, db, user, password, 'HGNC')
    ensembl_source_id = fetch_source(host, port, db, user, password, 'Ensembl')
    version = re.search("[0-9]+", ensembl_db)
    description = 'Update genes to Ensembl release 111'

    genes_ids = {}
    sequence_ids = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for gf_id, info in genomic_feature_data.items():
                stable_id = info['ensembl_stable_id']
                if info['gene_symbol'] in gene_symbols:
                    gene_data = genes[stable_id]
                    # Insert sequence
                    if gene_data['sequence'] not in sequence_ids.keys():
                        cursor.execute(sql_sequence, [gene_data['sequence'], reference_id])
                        connection.commit()
                        sequence_ids[gene_data['sequence']] = cursor.lastrowid

                    cursor.execute(sql_query, [sequence_ids[gene_data['sequence']], gene_data['start'], gene_data['end'], gene_data['strand'],
                                            info['gene_symbol'], locus_type_id])
                    connection.commit()
                    genes_ids[gf_id] = { 'new_gf_id':cursor.lastrowid }

                    if info['hgnc_id'] is not None:
                        cursor.execute(sql_query_ids, [genes_ids[gf_id]['new_gf_id'], f"HGNC:{info['hgnc_id']}", hgnc_source_id])
                        connection.commit()
                    if stable_id is not None:
                        cursor.execute(sql_query_ids, [genes_ids[gf_id]['new_gf_id'], stable_id, ensembl_source_id])
                        connection.commit()
            # Insert into meta
            cursor.execute(sql_meta, ['locus_gene_update', datetime.datetime.now(), 0, description, ensembl_source_id, version.group()])
            connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return genes_ids

def populates_gene_synonyms(host, port, db, user, password, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password):
    sql_get_synonym = """ SELECT ga.value, g.stable_id, g.description, g.biotype, e.synonym
                          FROM gene g
                          LEFT JOIN gene_attrib ga ON ga.gene_id = g.gene_id
                          LEFT JOIN external_synonym e ON e.xref_id = g.display_xref_id
                          WHERE (g.source = 'ensembl_havana' or g.source = 'havana') AND ga.attrib_type_id = 4 AND e.synonym IS NOT NULL
                      """

    sql_get_gene_info = """ SELECT id, name
                            FROM locus
                        """

    sql_attrib = """ SELECT id
                     FROM attrib_type
                     WHERE code = 'gene_synonym'
                 """

    sql_insert = f""" INSERT INTO locus_attrib(value, locus_id, attrib_type_id, source_id, is_deleted)
                      VALUES (%s, %s, %s, %s, %s)
                  """

    source_id = fetch_source(host, port, db, user, password, 'Ensembl')

    gene_synonyms = {}
    # gene_list_g2p = {}
    attrib_id = None

    # Connect to Ensembl core db
    connection = mysql.connector.connect(host=ensembl_host,
                                         database=ensembl_db,
                                         user=ensembl_user,
                                         port=ensembl_port,
                                         password=ensembl_password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_get_synonym)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    gene_name = row[0]
                    if gene_name not in gene_synonyms.keys():
                        synonyms_list = set()
                        synonyms_list.add(row[4])
                        gene_synonyms[gene_name] = { 'stable_id':row[1],
                                                     'synonyms':synonyms_list }
                    else:
                        gene_synonyms[gene_name]['synonyms'].add(row[4])

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    # Connect to G2P db
    connection_g2p = mysql.connector.connect(host=host,
                                             database=db,
                                             user=user,
                                             port=port,
                                             password=password)

    try:
        if connection_g2p.is_connected():
            cursor = connection_g2p.cursor()
            cursor.execute(sql_attrib)
            data_attrib = cursor.fetchall()
            if len(data_attrib) != 0:
                attrib_id = data_attrib[0][0]

            cursor.execute(sql_get_gene_info)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    if row[1] in gene_synonyms.keys():
                        # stable_id = gene_synonyms[row[1]]['stable_id']
                        synonyms = gene_synonyms[row[1]]['synonyms']
                        # gene_list_g2p[row[1]] = {'locus_id':row[0],
                        #                          'stable_id':stable_id,
                        #                          'synonyms':synonyms}

                        # Insert gene synonym into locus_attrib table
                        for synonym in synonyms:
                            cursor.execute(sql_insert, [synonym, row[0], attrib_id, source_id, 0])
                            connection_g2p.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection_g2p.is_connected():
            cursor.close()
            connection_g2p.close()

def populates_lgd(host, port, db, user, password, gfd_data, inserted_publications, inserted_phenotypes, last_updates, last_update_panel, inserted_disease_by_name):
    # url = "https://www.ebi.ac.uk/gene2phenotype/gfd?search_type=gfd&dbID="

    # # Check panels confidence: if they don't agree print entries to be reviewed
    # print("GFD ID\tpanel\tconfidence category\turl")
    # for gfd_id, info in gfd_data.items():
    #     confidence = {}
    #     for panel, panel_info in info['panels'].items():
    #         confidence[panel_info['confidence_category']] = 1

    #     if len(confidence.keys()) > 1:
    #         print("\n")
    #         for panel, panel_info in info['panels'].items():
    #             print(f"{gfd_id}\t{panel}\t{panel_info['confidence_category']}\t{url}{gfd_id}")

    ar_mapping = {
        'biallelic_autosomal':'biallelic_autosomal',
        'biallelic_PAR':'biallelic_PAR',
        'mitochondrial':'mitochondrial',
        'monoallelic_autosomal':'monoallelic_autosomal',
        'monoallelic_PAR':'monoallelic_PAR',
        'monoallelic_X_hem':'monoallelic_X_hemizygous',
        'monoallelic_X_het':'monoallelic_X_heterozygous',
        'monoallelic_Y_hem':'monoallelic_Y_hemizygous'
    }

    ccm_mapping = {
        'imprinted':'imprinted region',
        'potential IF':'potential secondary finding',
        'requires heterozygosity':'requires heterozygosity', # CHECK
        'typically de novo':'typically de novo',
        'typically mosaic':'typically mosaic',
        'typified by age related penetrance':'typified by age related penetrance', # CHECK
        'typified by reduced penetrance':'typified by incomplete penetrance' # CHECK
    }

    sql_query_lgd = f""" INSERT INTO locus_genotype_disease (stable_id, date_review, is_reviewed, 
                         is_deleted, confidence_id, disease_id, genotype_id, locus_id)
                         VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                     """
    
    sql_query_lgd_panel = f""" INSERT INTO lgd_panel (is_deleted, relevance_id, lgd_id, panel_id)
                               VALUES (%s, %s, %s, %s)
                           """
    
    sql_query_lgd_ccm = f""" INSERT INTO lgd_cross_cutting_modifier (is_deleted, ccm_id, lgd_id)
                             VALUES (%s, %s, %s)
                         """

    sql_query_lgd_pub = f""" INSERT INTO lgd_publication (is_deleted, publication_id, lgd_id)
                             VALUES (%s, %s, %s)
                         """

    sql_query_lgd_gencc = f""" INSERT INTO lgd_variant_gencc_consequence (is_deleted, support_id, lgd_id, variant_consequence_id)
                               VALUES (%s, %s, %s, %s)
                           """

    sql_query_lgd_var = f""" INSERT INTO lgd_variant_type (is_deleted, lgd_id, variant_type_ot_id)
                               VALUES (%s, %s, %s)
                           """

    sql_query_lgd_pheno = f""" INSERT INTO lgd_phenotype (is_deleted, lgd_id, phenotype_id)
                               VALUES (%s, %s, %s)
                           """

    sql_query_lgd_mechanism = f""" INSERT INTO lgd_molecular_mechanism (mechanism_id, mechanism_support_id, lgd_id, is_deleted)
                                   VALUES (%s, %s, %s, %s)
                               """

    stable_id = 0
    inserted_lgd = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for gfd, data in gfd_data.items():
                # print(f"\n{gfd}, {data}")
                locus_id = fetch_locus_id(host, port, db, user, password, data['gene_symbol'])
                # print(f"Locus id: {locus_id}")
                new_disease_name = clean_up_disease_name(data['disease_name'])
                disease_id = inserted_disease_by_name[new_disease_name]['new_disease_id']

                genotype_id = fetch_attrib(host, port, db, user, password, ar_mapping[data['allelic_requirement_attrib']])

                # Get date last update
                date = None
                if gfd in last_updates:
                    date = last_updates[gfd]
                if gfd in last_update_panel and (date is None or date < last_update_panel[gfd]):
                    date = last_update_panel[gfd]
                
                if date is None:
                    date = '2010-01-01 00:00:00' # TODO: which date to use?
                
                # cross cutting modifier
                ccm_id = []
                for ccm in data['cross_cutting_modifier_attrib']:
                    ccm_id.append(fetch_attrib(host, port, db, user, password, ccm_mapping[ccm]))

                # variant consequence ( new: variant type)
                mechanism = []
                variant_type_list = []
                for var_type in data['variant_consequence_attrib']:
                    # This is a molecular mechanism
                    if var_type == 'gain_of_function_variant':
                        mechanism.append(fetch_attrib(host, port, db, user, password, 'gain of function'))
                    elif var_type == 'loss_of_function_variant':
                        mechanism.append(fetch_attrib(host, port, db, user, password, 'loss of function'))
                    else:
                        variant_type_list.append(fetch_ontology(host, port, db, user, password, var_type))

                # multiple mutation_consequence_attrib
                # some mutation consequences are now variant type
                variant_gencc_consequences = []
                variant_gencc_consequences_support = fetch_attrib(host, port, db, user, password, 'inferred')
                for mc in data['mutation_consequence_attrib']:
                    if (mc == '5_prime or 3_prime UTR mutation' or mc == 'cis-regulatory or promotor mutation') and '5_prime_UTR_variant' not in data['variant_consequence_attrib'] and '3_prime_UTR_variant' not in data['variant_consequence_attrib'] and 'regulatory_region_variant' not in data['variant_consequence_attrib']:
                        variant_type_list.append(fetch_ontology(host, port, db, user, password, 'regulatory_region_variant'))
                    elif mc != '5_prime or 3_prime UTR mutation' and mc != 'cis-regulatory or promotor mutation':
                        variant_gencc_consequences.append(fetch_ontology(host, port, db, user, password, mc))

                # fetch panel id
                panels = []
                confidence = {}
                final_confidence = None
                for panel, panel_data in data['panels'].items():
                    panel_id = fetch_panel(host, port, db, user, password, panel)
                    panels.append(panel_id)
                    confidence[panel_id] = fetch_attrib(host, port, db, user, password, panel_data['confidence_category'])
                    final_confidence = confidence[panel_id]
                
                # publications
                publications = []
                for pub_id, pub_data in data['publications'].items():
                    if pub_id in inserted_publications:
                        publications.append(inserted_publications[pub_id]['new_id'])
                    else:
                        print(f"Publication id (old): {pub_id} not found")

                    # publication comments - TODO
                    # if pub_data['comment'] is not None:
                
                # phenotypes
                phenotypes = []
                for pheno_id in data['phenotypes']:
                    phenotypes.append(inserted_phenotypes[pheno_id]['new_id'])

                # print(f"locus: {locus_id}, disease: {disease_id}, genotype: {genotype_id}, variant consequence: {variant_gencc_consequences}, panels confidence: {confidence}")
                stable_id += 1
                key = f"{locus_id}-{disease_id}-{genotype_id}" # TODO: Change to support disease updates

                # Insert LGD
                # Skip entries with multiple confidence
                if key not in inserted_lgd.keys():
                    cursor.execute(sql_query_lgd, [f"G2P{stable_id}", date, 1, 0, final_confidence, disease_id, genotype_id, locus_id])
                    connection.commit()
                    inserted_lgd[key] = { 'id':cursor.lastrowid, 'variant_gencc_consequence':variant_gencc_consequences,
                                          'confidence':confidence, 'ccm':ccm_id, 'publications':publications,
                                          'variant_types':variant_type_list, 'phenotypes':phenotypes,
                                          'final_confidence':final_confidence, 'mechanisms':mechanism }

                    # Insert lgd_panel
                    for panel_id in confidence:
                        cursor.execute(sql_query_lgd_panel, [0, confidence[panel_id], inserted_lgd[key]['id'], panel_id])
                        connection.commit()
                    
                    # Insert cross cutting modifier
                    for ccm_data in ccm_id:
                        cursor.execute(sql_query_lgd_ccm, [0, ccm_data, inserted_lgd[key]['id']])
                        connection.commit()
                    
                    # Insert publications
                    for pub in publications:
                        cursor.execute(sql_query_lgd_pub, [0, pub, inserted_lgd[key]['id']])
                        connection.commit()

                    # Insert gencc variant consequence
                    for var_cons_gencc in variant_gencc_consequences:
                        cursor.execute(sql_query_lgd_gencc, [0, variant_gencc_consequences_support, inserted_lgd[key]['id'], var_cons_gencc])
                        connection.commit()

                    # Insert variant type
                    for var_id in variant_type_list:
                        cursor.execute(sql_query_lgd_var, [0, inserted_lgd[key]['id'], var_id])
                        connection.commit()
                    
                    # Insert phenotypes
                    for new_pheno_id in phenotypes:
                        cursor.execute(sql_query_lgd_pheno, [0, inserted_lgd[key]['id'], new_pheno_id])
                        connection.commit()

                    # Insert mechanisms
                    for mec in mechanism:
                        cursor.execute(sql_query_lgd_mechanism, [mec, variant_gencc_consequences_support, inserted_lgd[key]['id'], 0])
                        connection.commit()

                # Merge entries - disease is the same
                elif set(variant_gencc_consequences) == set(inserted_lgd[key]['variant_gencc_consequence']) and final_confidence == inserted_lgd[key]['final_confidence']:
                    lgd_id = inserted_lgd[key]['id']
                    print(f"Merge entries: {lgd_id}")
                    # print(f"variant consequences: {variant_gencc_consequences} = {inserted_lgd[key]['variant_gencc_consequence']}")
                    # Insert lgd_panel
                    for panel_id in confidence:
                        if panel_id not in inserted_lgd[key]['confidence']:
                            cursor.execute(sql_query_lgd_panel, [0, confidence[panel_id], lgd_id, panel_id])
                            connection.commit()
                    # Insert cross cutting modifier
                    for ccm_data in ccm_id:
                        if ccm_data not in inserted_lgd[key]['ccm']:
                            cursor.execute(sql_query_lgd_ccm, [0, ccm_data, lgd_id])
                            connection.commit()
                    # Insert publications
                    for pub in publications:
                        if pub not in inserted_lgd[key]['publications']:
                            cursor.execute(sql_query_lgd_pub, [0, pub, lgd_id])
                            connection.commit()
                    # Insert variant type
                    for var_id in variant_type_list:
                        if var_id not in inserted_lgd[key]['variant_types']:
                            cursor.execute(sql_query_lgd_var, [0, lgd_id, var_id])
                            connection.commit()
                    # Insert phenotypes
                    for new_pheno_id in phenotypes:
                        if new_pheno_id not in inserted_lgd[key]['phenotypes']:
                            cursor.execute(sql_query_lgd_pheno, [0, lgd_id, new_pheno_id])
                            connection.commit()
                    # Insert mechanism
                    for mec in mechanism:
                        if mec not in inserted_lgd[key]['mechanisms']:
                            cursor.execute(sql_query_lgd_mechanism, [mec, variant_gencc_consequences_support, lgd_id, 0])
                            connection.commit()
                    
                    # TODO: update last_updated

                elif final_confidence != inserted_lgd[key]['final_confidence']:
                    # print(f"\nKey already inserted with id: {inserted_lgd[key]}")
                    print(f"(Different confidence) Key already in db: {key}, locus: {locus_id}, disease: {disease_id}, genotype: {genotype_id}, variant consequence: {variant_gencc_consequences}, panels confidence: {confidence}")

                else:
                    # print(f"\nKey already inserted with id: {inserted_lgd[key]}")
                    print(f"Key already in db: {key}, locus: {locus_id}, disease: {disease_id}, genotype: {genotype_id}, variant consequence: {variant_gencc_consequences}, panels confidence: {confidence}")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

def fetch_locus_id(host, port, db, user, password, name):
    id = None

    sql_query = f""" SELECT id
                     FROM locus
                     WHERE name = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [name])
            data = cursor.fetchall()
            if len(data) != 0:
                id = data[0][0]
 
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return id

def fetch_disease_by_name(host, port, db, user, password, name):
    id = None

    sql_query = f""" SELECT id
                     FROM disease
                     WHERE name = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [name])
            data = cursor.fetchall()
            if len(data) != 0:
                id = data[0][0]
 
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return id

def clean_up_disease_name(name):
    new_disease_name = name.strip()

    new_disease_name = new_disease_name.lstrip('?')
    new_disease_name = new_disease_name.rstrip('.')
    new_disease_name = re.sub(r',\s+', ' ', new_disease_name)
    new_disease_name = new_disease_name.replace('“', '').replace('”', '')
    new_disease_name = new_disease_name.replace('-', ' ')
    new_disease_name = re.sub(r'\t+', ' ', new_disease_name)

    new_disease_name = new_disease_name.lower()

    new_disease_name = re.sub(r'\s+and\s+', ' ', new_disease_name)
    new_disease_name = re.sub(r'\s+or\s+', ' ', new_disease_name)

    # specific cases
    new_disease_name = re.sub(r'\s+syndrom$', ' syndrome', new_disease_name)
    new_disease_name = re.sub(r'\(yndrome', 'syndrome', new_disease_name)
    new_disease_name = new_disease_name.replace('larrson', 'larsson')
    new_disease_name = new_disease_name.replace('sjoegren', 'sjogren')
    new_disease_name = new_disease_name.replace('sjorgren', 'sjogren')
    new_disease_name = new_disease_name.replace('complementation group 0', 'complementation group o')

    new_disease_name = re.sub(r'\(|\)', ' ', new_disease_name)
    new_disease_name = re.sub(r'\s+', ' ', new_disease_name)

    # tokenise string
    disease_tokens = sorted(new_disease_name.split())

    return " ".join(disease_tokens)

def fetch_attrib(host, port, db, user, password, value):
    id = None

    sql_query = f""" SELECT id
                     FROM attrib
                     WHERE value = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [value])
            data = cursor.fetchall()
            if len(data) != 0:
                id = data[0][0]
 
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return id

def fetch_ontology(host, port, db, user, password, value):
    id = None

    sql_query = f""" SELECT id
                     FROM ontology_term
                     WHERE term = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [value])
            data = cursor.fetchall()
            if len(data) != 0:
                id = data[0][0]
 
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return id

def fetch_panel(host, port, db, user, password, name):
    id = None

    sql_query = f""" SELECT id
                     FROM panel
                     WHERE name = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [name])
            data = cursor.fetchall()
            if len(data) != 0:
                id = data[0][0]
 
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return id

def fetch_source(host, port, db, user, password, value):
    id = None

    sql_query = f""" SELECT id
                     FROM source
                     WHERE name = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [value])
            data = cursor.fetchall()
            if len(data) != 0:
                id = data[0][0]
 
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return id


def main():
    parser = argparse.ArgumentParser(description="")
    parser.add_argument("--host", required=True, help="Database host")
    parser.add_argument("--port", required=True, help="Host port")
    parser.add_argument("--database", required=True, help="Database name")
    parser.add_argument("--user", required=True, help="Username")
    parser.add_argument("--password", default='', help="Password (default: '')")
    parser.add_argument("--new_host", default='', help="New Database host")
    parser.add_argument("--new_port", default='', help="New Host port")
    parser.add_argument("--new_database", default='', help="New Database name")
    parser.add_argument("--new_user", default='', help="New Username")
    parser.add_argument("--new_password", default='', help="New Password (default: '')")
    parser.add_argument("--ensembl_host", default='', help="Ensembl core Database host")
    parser.add_argument("--ensembl_port", default='', help="Ensembl core Host port")
    parser.add_argument("--ensembl_database", default='', help="Ensembl core Database name")
    parser.add_argument("--ensembl_user", default='', help="Ensembl core Username")
    parser.add_argument("--ensembl_password", default='', help="Ensembl core Password (default: '')")

    args = parser.parse_args()

    host = args.host
    port = args.port
    db = args.database
    user = args.user
    password = args.password
    new_host = args.new_host
    new_port = args.new_port
    new_db = args.new_database
    new_user = args.new_user
    new_password = args.new_password
    ensembl_host = args.ensembl_host
    ensembl_port = args.ensembl_port
    ensembl_db = args.ensembl_database
    ensembl_user = args.ensembl_user
    ensembl_password = args.ensembl_password

    # Populates: attrib, attrib_type
    attribs = fetch_attribs(host, port, db, user, password)

    # Populates: panel
    panels_data = dump_panels(host, port, db, user, password)

    # Populates: user, user_panel
    user_panel_data = dump_users(host, port, db, user, password, attribs)
  
    # Populates: publication
    publications_data = dump_publications(host, port, db, user, password)

    # Populates: phenotype
    phenotype_data = dump_phenotype(host, port, db, user, password)

    # Populates: organ
    organ_data = dump_organ(host, port, db, user, password)

    # Populates: disease
    disease_data = dump_diseases(host, port, db, user, password)

    # Populates: ontology_term, ontology
    # variant gencc consequence uses these terms
    # disease ontology stored here
    ontology_term_data, disease_ontology_data = dump_ontology(host, port, db, user, password, attribs)

    # Populates: locus
    # TODO: genomic_feature_statistic and genomic_feature_statistic_attrib
    genomic_feature_data = dump_genes(host, port, db, user, password)

    # Populates: locus_genotype_disease
    gfd_data, last_updates, last_update_panel = dump_gfd(host, port, db, user, password, attribs)
    gene_symbols = {}
    for gfd_id, gfd in gfd_data.items():
        if gfd['gene_symbol'] not in gene_symbols:
            gene_symbols[gfd['gene_symbol']] = 1

    ### Store the data in the new database ###
    # Populates: source
    populate_source(new_host, new_port, new_db, new_user, new_password)
    print("INFO: source populated")

    # Populates: attrib, attrib_type, ontology_term (variant consequence, variant type)
    populate_attribs(new_host, new_port, new_db, new_user, new_password, attribs)
    populate_new_attribs(new_host, new_port, new_db, new_user, new_password)
    print("INFO: attribs populated")

    # Populates: user, panel, user_panel, ontology_term
    populates_user_panel(new_host, new_port, new_db, new_user, new_password, user_panel_data, panels_data)
    print("INFO: user data populated")

    # Populates: publication
    # inserted_publications = ''
    inserted_publications = populates_publications(new_host, new_port, new_db, new_user, new_password, publications_data)
    print("INFO: publications populated")

    # Populates: phenotype
    inserted_phenotypes = populates_phenotypes(new_host, new_port, new_db, new_user, new_password, phenotype_data)
    print("INFO: phenotypes populated")

    # Populates: disease, disease_ontology, ontology_term
    # Update disease names before populating new db: https://www.ebi.ac.uk/panda/jira/browse/G2P-45
    inserted_disease_by_name = populates_disease(new_host, new_port, new_db, new_user, new_password, disease_data, disease_ontology_data)
    print("INFO: diseases populated")

    # Populates: locus, locus_attrib, locus_identifier
    inserted_gene_ids = populates_locus(new_host, new_port, new_db, new_user, new_password, genomic_feature_data, gene_symbols, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password)
    print("INFO: genes populated")
    populates_gene_synonyms(new_host, new_port, new_db, new_user, new_password, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password)
    print("INFO: genes synonyms populated")

    # Populates: locus_genotype_disease
    populates_lgd(new_host, new_port, new_db, new_user, new_password, gfd_data, inserted_publications, inserted_phenotypes, last_updates, last_update_panel, inserted_disease_by_name)
    print("INFO: LGD populated")


if __name__ == '__main__':
    main()