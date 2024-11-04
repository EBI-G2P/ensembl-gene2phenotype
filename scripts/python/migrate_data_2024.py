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

import sys
import argparse
import re
import mysql.connector
from mysql.connector import Error
import requests
import datetime
import faulthandler

faulthandler.enable()

### Fetch data from current db ###

"""
    Fetch the attribs from attrib and attrib_type tables

    Output:
            result_data (dict): for each attrib id returns the value and the attrib_type data
                                Structure:
                                { attrib_id : { 
                                                attrib_value,
                                                attrib_type_code,
                                                attrib_type_name,
                                                attrib_type_description
                                              }
                                }
"""
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

"""
    Return the panel name and the visibility
"""
def dump_panels(host, port, db, user, password):
    result_data = {}

    map_name = {
        "DD": "Developmental disorders",
        "Ear": "Ear disorders",
        "Eye": "Eye disorders",
        "Skin": "Skin disorders",
        "Cancer": "Cancer disorders",
        "Prenatal": "Prenatal disorders",
        "Neonatal": "Neonatal disorders",
        "Demo": "Demo",
        "Rapid_PICU_NICU": "Rapid_PICU_NICU disorders",
        "PaedNeuro": "PaedNeuro disorders",
        "Skeletal": "Skeletal disorders",
        "Cardiac": "Cardiac disorders"
    }

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
                    result_data[row[0]] = { 'description': map_name[row[0]], 'is_visible':row[1] }

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result_data

"""
    Return the users data and the panels they can curate
"""
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

"""
    Return the publications
"""
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

"""
    Returns phenotypes
"""
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

"""
    Return organ data
    This data is going to be stored as historical data
"""
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
                    'altered gene product level':{'so':'SO:0002314', 'description':'NA'},
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
                    attrib = row[2]
                    if attrib is not None:
                        attrib = attribs[int(list(row[2])[0])]['attrib_value']
                    result_disease[row[0]] = { 'ontology_term_id':row[1],
                                               'mapped_by_attrib':attrib,
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
    """
        This method dumps the diseases names and IDs (OMIM, Mondo) to be used for the migration

        We don't need to migrate diseases that are not used:
        Step 1: delete from disease and disease_ontology_mapping diseases that are not used
        in tables genomic_feature_disease and GFD_disease_synonym

        On a clean disease table:
        Step 2: select diseases to migrate
    """
    result = {}
    unique_names = {}
    duplicated_names = {} # saves the disease names that are duplicated but they have different disease_id

    # To correctly migrate diseases first we should delete diseases that are not being used in gfd
    sql_del_disease = """ delete from disease 
                          where disease_id not in (select disease_id from genomic_feature_disease)
                          and disease_id not in (select disease_id from GFD_disease_synonym) """

    sql_del_ontology = """ delete from disease_ontology_mapping 
                           where disease_id not in (select disease_id from disease) """

    sql_query = """ SELECT d.disease_id, d.name, d.mim, gf.gene_symbol
                    FROM disease d
                    left join genomic_feature_disease gfd on gfd.disease_id = d.disease_id
                    left join genomic_feature_disease_panel gfdp on gfdp.genomic_feature_disease_id = gfd.genomic_feature_disease_id
                    left join genomic_feature gf on gf.genomic_feature_id = gfd.genomic_feature_id
                    where gf.gene_symbol is not null and gfdp.panel_attrib is not null
                    GROUP BY BINARY d.name, gf.gene_symbol order by d.name """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()

            # Delete diseases that are not used
            cursor.execute(sql_del_disease)
            connection.commit()
            # Delete disease ontologies that are not used
            cursor.execute(sql_del_ontology)
            connection.commit()

            # Select diseases to migrate
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    if row[0] not in result:
                        result[row[0]] = { 'disease_name':row[1],
                                           'disease_mim':row[2],
                                           'gene':[row[3]] }
                        
                        # save unique disease names
                        if row[1] not in unique_names:
                            unique_names[row[1]] = row[0]
                        else:
                            duplicated_names[row[1]] = 1

                    else:
                        result[row[0]]['gene'].append(row[3])

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return result, duplicated_names

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
    
    sql_query_comment = f""" SELECT c.comment_text, c.created, u.username, c.is_public
                             FROM genomic_feature_disease_comment c
                             LEFT JOIN user u ON u.user_id = c.user_id
                             WHERE c.genomic_feature_disease_id = %s
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

                        comments = []
                        cursor.execute(sql_query_comment, [gfd_id])
                        data_lgd_comments = cursor.fetchall()
                        for row_comment in data_lgd_comments:
                            comments.append({ 'comment':row_comment[0],
                                              'created':row_comment[1],
                                              'username': row_comment[2],
                                              'is_public':row_comment[3] })

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
                                           'phenotypes':phenotypes,
                                           'comments': comments }

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
        return ''

    decoded = r.json()
    if id.startswith("MONDO") and len(decoded['response']['docs'][0]['description']) > 0:
        description = decoded['response']['docs'][0]['description'][0]
    else:
        description = ''

    return description

def get_omim(id):
    """
        Get OMIM data from OLS
        This is not the best way to get the data, some IDs return data from other sources.
    """
    disease = None
    description = None

    url = f"https://www.ebi.ac.uk/ols4/api/search?q={id}&ontology=cco"

    r = requests.get(url, headers={ "Content-Type" : "application/json"})

    if not r.ok:
        return disease, description

    decoded = r.json()
    
    if len(decoded['response']['docs']) > 0:
        disease = decoded['response']['docs'][0]['label']

        if len(decoded['response']['docs'][0]['description']) > 0:
            description = decoded['response']['docs'][0]['description'][0]

    return disease, description

"""
    Fetch OMIM disease data from the OMIM API
"""
def get_omim_data(id):
    disease = None
    description = None

    url = f"https://api.omim.org/api/entry?mimNumber={id}&include=text&apiKey={omim_key_global}&format=json"

    r = requests.get(url, headers={ "Content-Type" : "application/json"})    

    if not r.ok:
        return disease, description

    decoded = r.json()

    if len(decoded['omim']['entryList']) > 0:
        disease = decoded['omim']['entryList'][0]['entry']['titles']['preferredTitle']
        disease = re.sub(";.*", "", disease)
        if 'alternativeTitles' in decoded['omim']['entryList'][0]['entry']['titles']:
            description = decoded['omim']['entryList'][0]['entry']['titles']['alternativeTitles']
            description = re.sub(";.*", "", description)
            description = re.sub("\n", "; ", description)
        else:
            description = None
        # description_data = decoded['omim']['entryList'][0]['entry']['textSectionList']
        # for desc in description_data:
        #     if desc['textSection']['textSectionName'] == 'description':
        #         description = desc['textSection']['textSectionContent']
        #         description = re.sub("\n+.*", "", description)
        #         description = re.sub("\s\(.*?\)", "", description)
        #         description = re.sub("\'", "", description)   

    return disease, description

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
                       'UniProt': {'description':'Gene function imported from UniProt', 'url':'https://www.uniprot.org'},
                       'Marsh Mechanism probabilities': {'description':'Marsh Mechanism probabilities', 'url':'https://europepmc.org/article/MED/39172982'}
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
        'typified by reduced penetrance':'typified by incomplete penetrance',
        'incomplete penetrance':'incomplete penetrance'
    }

    so_mapping = { 'absent gene product':'SO:0002317', 'altered gene product structure':'SO:0002318', 'decreased gene product level':'SO:0002316',
                   'increased gene product level': 'SO:0002315', 'uncertain': 'SO:0002220', 'altered gene product level': 'SO:0002314',
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
                    'ncRNA':'SO:0000655',
                    'short_tandem_repeat_change':'SO:0002161',
                    'copy_number_variation':'SO:0001019'
                    }

    for attrib in attribs:
        if attribs[attrib]['attrib_type_code'] not in attrib_types:
            attrib_types[attribs[attrib]['attrib_type_code']] = { 'name':attribs[attrib]['attrib_type_name'],
                                                                  'description':attribs[attrib]['attrib_type_description'] }

    sql_query = f""" INSERT INTO attrib_type (code, name, description, is_deleted)
                     VALUES (%s, %s, %s, %s)
                 """
    
    sql_query_attrib = f""" INSERT INTO attrib (value, type_id, description, is_deleted)
                            VALUES (%s, %s, %s, %s)
                        """
    
    sql_query_ontology_term = f""" INSERT INTO ontology_term (accession, term, source_id, group_type_id)
                                   VALUES (%s, %s, %s, %s)
                               """
    
    inserted_attrib_type = {}
    inserted_attrib = {}
    group_type_id = 1

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
                    cursor.execute(sql_query, [type, attrib_types[type]['name'], attrib_types[type]['description'], 0])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid
                elif type == 'allelic_requirement':
                    cursor.execute(sql_query, ['genotype', 'genotype', 'Mendelian inheritance terms (previously: allelic_requirement)', 0])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid
                elif type == 'mutation_consequence':
                    cursor.execute(sql_query, ['mutation_consequence', 'Mutation consequence', 'Mutation consequence (deprecated)', 0])
                    connection.commit()
                    inserted_attrib_type[type] = cursor.lastrowid
                elif type == 'mutation_consequence_flag':
                    cursor.execute(sql_query, ['mutation_consequence_flag', 'Mutation consequence flag', 'Mutation consequence flag (deprecated)', 0])
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
                    cursor.execute(sql_query_attrib, [mapping, inserted_attrib_type[attribs[old_id]['attrib_type_code']], None, 0])
                    connection.commit()
                    inserted_attrib[attribs[old_id]['attrib_value']] = { 'old_id':old_id, 'new_id':cursor.lastrowid }

            for old_id in attribs:
                # This only inserts attribs from the old db
                # New ontology terms are inserted in method populate_new_attribs()
                if (attribs[old_id]['attrib_type_code'] == 'mutation_consequence' or attribs[old_id]['attrib_type_code'] == 'variant_consequence') and attribs[old_id]['attrib_value'] in so_mapping.keys():
                    cursor.execute(sql_query_ontology_term, [so_mapping[attribs[old_id]['attrib_value']], attribs[old_id]['attrib_value'], 1, group_type_id])
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
    attrib_types = {   'support': 'The support can be inferred by the curator or taken from evidence in the paper',
                       'locus_type':'Locus type',
                       'reference':'Assembly reference',
                       'gene_synonym':'Gene symbol synonym',
                       'disease_synonym':'Disease synonym',
                       'ontology_term_group':'Type of the ontology term. It can be phenotype, disease, variant consequence, etc.',
                       'consanguinity':'Consanguinity associated with families described in publications',
                       'inheritance_type':'Type of inheritance for variant types',
                       'mechanism_probabilities':'Predictions for the human UniProt reference proteome whether human protein coding genes are likely to be associated with DN, GOF, or LOF molecular disease mechanisms.'
                      }

    attribs = {        'inferred':'support',
                       'evidence':'support',
                       'gene':'locus_type',
                       'variant':'locus_type',
                       'region':'locus_type',
                       'grch38':'reference',
                       'dyadic_name': 'disease_synonym',
                       'disease': 'ontology_term_group',
                       'phenotype': 'ontology_term_group',
                       'variant_type': 'ontology_term_group',
                       'yes': 'consanguinity',
                       'no': 'consanguinity',
                       'unknown': 'consanguinity',
                       'de_novo': 'inheritance_type',
                       'inherited': 'inheritance_type',
                       'gain_of_function_mp':'mechanism_probabilities',
                       'loss_of_function_mp':'mechanism_probabilities',
                       'dominant_negative_mp':'mechanism_probabilities'
                     }

    extra_attribs = { 'unknown': 'inheritance_type' }

    mechanisms = {     'loss of function':['mechanism'],
                       'dominant negative':['mechanism'],
                       'gain of function':['mechanism'],
                       'undetermined non-loss-of-function':['mechanism'],
                       'undetermined':['mechanism'],
                       'destabilising LOF':['mechanism_synopsis'],
                       'interaction-disrupting LOF':['mechanism_synopsis'],
                       'loss of activity LOF':['mechanism_synopsis'],
                       'LOF due to protein mislocalisation':['mechanism_synopsis'],
                       'assembly-mediated dominant negative':['mechanism_synopsis'],
                       'competitive dominant-negative':['mechanism_synopsis'],
                       'assembly-mediated GOF':['mechanism_synopsis'],
                       'protein aggregation':['mechanism_synopsis'],
                       'local LOF leading to overall GOF':['mechanism_synopsis'],
                       'other GOF':['mechanism_synopsis'],
                       'inferred':['support'],
                       'evidence':['support'],
                       'biochemical': ['evidence_function'],
                       'protein interaction': ['evidence_function'],
                       'protein expression': ['evidence_function'],
                       'patient cells': ['evidence_functional_alteration', 'evidence_rescue'],
                       'non patient cells': ['evidence_functional_alteration'],
                       'non-human model organism': ['evidence_models', 'evidence_rescue'],
                       'cell culture model': ['evidence_models', 'evidence_rescue'],
                       'human': ['evidence_rescue']
                 }
    
    mechanism_descriptions_list = { "loss of function": "Loss-of-function variants involve a loss of the normal biological function of a protein. Often these are nonsense or frameshift mutations that introduce premature stop codons. Due to nonsense-mediated decay of the resulting mRNAs, most premature stop codons will result in no protein being produced, rather than a truncated protein. However, there are also many examples of loss-of-function variants that change the amino acid sequence and result in non-functional protein products. These mutations can cause a complete loss of function (amorphic), analogous to a protein null mutation, or only a partial loss of function (hypomorphic). May also include variants in regulatory regions.",
                                    "dominant negative": "Dominant-negative variants involve the mutant protein directly or indirectly blocking the normal biological function of the wild-type protein (antimorphic). They can thus cause a disproportionate (>50%) loss of function, even though only half of the protein is mutated eg. heterozygous variants in COL1A1 that disrupt the triple collagen helix.",
                                    "gain of function": "Gain-of-function variants have their phenotypic effect because the mutant protein does something different than the wild-type protein. Often, these variants cause disease by increasing protein activity (hypermorphic) or introducing a completely new function (neomorphic), but the specific molecular mechanisms underlying gain-of-function mutations can be complex. May also include variants in regulatory regions.",
                                    "undetermined non-loss-of-function": "Very often it is difficult to distinguish between dominant negative and gain of function, but it is clearly a non-loss-of-function mechanism (e.g. from co-expression experiments showing a damaging effect from the mutant allele)."
                                  }

    ontology = {   'altered gene product level': 'SO:0002314',
                    'ncRNA':'SO:0000655',
                    'short_tandem_repeat_change':'SO:0002161',
                    'whole_partial_gene_deletion':'SO:0001893', # CHECK
                    'whole_partial_gene_duplication':'SO:0001889' # CHECK
                }

    sql_query = """ INSERT INTO attrib_type (code, name, description, is_deleted)
                     VALUES (%s, %s, %s, %s)
                 """

    sql_query_attrib = """ INSERT INTO attrib (value, type_id, description, is_deleted)
                            VALUES (%s, %s, %s, %s)
                        """

    sql_ins_mechanism = """ INSERT INTO cv_molecular_mechanism (type, subtype, value, description)
                             VALUES (%s, %s, %s, %s)
                         """
    
    sql_ins_ontology = """ INSERT INTO ontology_term (accession, term, group_type_id, source_id)
                             VALUES (%s, %s, %s, %s)
                         """

    sql_upt_ontology_var = """ UPDATE ontology_term SET group_type_id = %s WHERE group_type_id = 1 """

    inserted = {}

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            # Insert into attrib and attrib_type
            for mt, description in attrib_types.items():
                cursor.execute(sql_query, [mt, mt, description, 0])
                connection.commit()
                inserted[mt] = cursor.lastrowid

            for data, t in attribs.items():
                attrib_type_id = inserted[t]
                cursor.execute(sql_query_attrib, [data, attrib_type_id, None, 0])
                connection.commit()

            for data, t in extra_attribs.items():
                attrib_type_id = inserted[t]
                cursor.execute(sql_query_attrib, [data, attrib_type_id, None, 0])
                connection.commit()

            # Insert into cv_molecular_mechanism
            for value, mechanism_type in mechanisms.items():
                mechanism_description = None
                if value in mechanism_descriptions_list:
                    mechanism_description = mechanism_descriptions_list[value]
                mechanism_subtype = None
                for m_type in mechanism_type:
                    if m_type.startswith("evidence"):
                        mechanism_subtype = m_type.replace("evidence_", "")
                        m_type = m_type.split("_",1)[0]

                    cursor.execute(sql_ins_mechanism, [m_type, mechanism_subtype, value, mechanism_description])
                    connection.commit()

            # Insert new ontology terms
            # Before inserting the new terms, fetch the group_type_id for 'variant_type' ('ontology_term_group')
            group_type_id = fetch_attrib(host, port, db, user, password, 'variant_type')
            source_id = fetch_source(host, port, db, user, password, 'SO')
            for ontology_term in ontology:
                cursor.execute(sql_ins_ontology, [ontology[ontology_term], ontology_term, group_type_id, source_id])
                connection.commit()

            # Update the group_type_id to the correct id 'variant_type'
            cursor.execute(sql_upt_ontology_var, [group_type_id])
            connection.commit()

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

def populates_user_panel(host, port, db, user, password, user_panel_data, panels_data):
    staff_list = ["ola_austine", "diana_lemos", "seetaramaraju", "sarah_hunt", "reviewer"]
    super_user_list = ["ecibrian", "ola_austine", "diana_lemos", "seetaramaraju", "sarah_hunt", "reviewer"]

    names_to_edit = { "ecibrian": {"first": "Elena", "last": "Cibrian"},
              "panda": {"first": "Panda", "last": "Theotokis"},
              "seetaramaraju": {"first": "Seeta", "last": "Ramaraju"} }

    sql_query_user = """ INSERT INTO user (username, email, is_staff, is_active, is_deleted, password, is_superuser, first_name, last_name)
                          VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                     """
    
    sql_query_panel = """ INSERT INTO panel (name, description, is_visible)
                            VALUES (%s, %s, %s)
                      """
    
    sql_query_user_panel = """ INSERT INTO user_panel (is_deleted, panel_id, user_id)
                                VALUES (%s, %s, %s)
                           """

    inserted_user = {}
    inserted_panel = {}
    is_active = 1
    is_deleted = 0

    # set a fake password
    fake_password = "g2p_default_2024"

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()

            for panel in panels_data:
                cursor.execute(sql_query_panel, [panel, panels_data[panel]['description'], panels_data[panel]['is_visible']])
                connection.commit()
                inserted_panel[panel] = cursor.lastrowid
            
            for username in user_panel_data:
                if username == 'anja_thormann' or username == 'fiona_cunningham' or username == 'david_fitzpatrick':
                    is_active = 0
                else:
                    is_active = 1

                is_staff = 0
                if username in staff_list:
                    is_staff = 1
                
                is_super_user = 0
                if username in super_user_list:
                    is_super_user = 1
                
                # Check first and last names
                first_name = None
                last_name = None
                if username in names_to_edit:
                    first_name = names_to_edit[username]["first"]
                    last_name = names_to_edit[username]["last"]
                elif "_" in username:
                    names = username.split("_")
                    first_name = names[0].title()
                    last_name = names[1].title()

                cursor.execute(sql_query_user, [username, user_panel_data[username]['email'], is_staff, is_active, 0, fake_password, is_super_user, first_name, last_name])
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
    sql_query = f""" INSERT INTO publication (pmid, title, source, authors, year, doi)
                     VALUES (%s, %s, %s, %s, %s, %s)
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
                    doi = None
                    if response:
                        if 'authorString' in response['result']:
                            authors = response['result']['authorString']
                            if len(authors) > 250:
                                authors_split = authors.split(',')
                                authors = f"{authors_split[0]} et al."
                        if 'pubYear' in response['result']:
                            year = response['result']['pubYear']
                        if 'doi' in response['result']:
                            doi = response['result']['doi']

                    # Insert publication
                    cursor.execute(sql_query, [publication_data[old_id]['pmid'], publication_data[old_id]['title'], source, authors, year, doi])
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
    sql_query_ontology_term = f""" INSERT INTO ontology_term (accession, term, description, source_id, group_type_id)
                                   VALUES (%s, %s, %s, %s, %s)
                               """

    inserted_phenotypes = {}
    group_type_id = fetch_attrib(host, port, db, user, password, 'phenotype')
    source_id = fetch_source(host, port, db, user, password, 'HPO')

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for old_id in phenotype_data:
                cursor.execute(sql_query_ontology_term, [phenotype_data[old_id]['stable_id'], phenotype_data[old_id]['name'], phenotype_data[old_id]['description'], source_id, group_type_id])
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

def populates_disease(host, port, db, user, password, disease_data, disease_ontology_data, duplicated_names):
    """
        To populate diseases we have to know which gene is the disease linked to.
        We are going to edit the disease name to include 'gene-related' if not there yet.
    """

    sql_query_ontology_term = f""" INSERT INTO ontology_term (accession, term, description, source_id, group_type_id)
                                   VALUES (%s, %s, %s, %s, %s)
                               """

    sql_query = f""" INSERT INTO disease (name)
                     VALUES (%s)
                 """
    
    sql_query_disease_ontology = f""" INSERT INTO disease_ontology_term (disease_id, mapped_by_attrib_id, ontology_term_id)
                                      VALUES (%s, %s, %s)
                                 """

    mapping = { 'Data source':fetch_attrib(host, port, db, user, password, 'Data source'), 
                'OLS exact':fetch_attrib(host, port, db, user, password, 'OLS exact'), 
                'Manual':fetch_attrib(host, port, db, user, password, 'Manual'), 
                'OLS partial':fetch_attrib(host, port, db, user, password, 'OLS partial'),
              }

    group_type_id = fetch_attrib(host, port, db, user, password, 'disease')

    inserted_mondo = {}
    inserted_ontology_term = {} # contains old (from disease) and new ontology_term ids
    inserted_disease = {}
    inserted_disease_by_name = {} # key = clean disease name; values = new disease id
    disease_genes = {}
    inserted_disease_ontology = {}
    source_id_mondo = fetch_source(host, port, db, user, password, 'Mondo')
    source_id_omim = fetch_source(host, port, db, user, password, 'OMIM')
    source_id_orphanet = fetch_source(host, port, db, user, password, 'Orphanet')
    description = None
    duplicated_ontology = {}
    omim_ontology_inserted = {}
    omim_ontology_term_inserted = {}

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
                        accession = ontology['ontology_accession']
                        term = ontology['ontology_accession']
                        if ontology['ontology_accession'].startswith('MONDO'):
                            source_id = source_id_mondo
                            if ontology['ontology_description']:
                                term = ontology['ontology_description']
                            description = ontology['mondo_description']
                        elif (ontology['ontology_accession'].startswith('OMIM') 
                              or ontology['ontology_accession'].startswith('MIM')):
                            source_id = source_id_omim
                            term = ontology['ontology_description']
                            description = ontology['ontology_description']
                            accession = re.sub("^OMIM:|^MIM:", "", accession)
                            if term is None:
                                term, description = get_omim_data(accession)
                        elif ontology['ontology_accession'].startswith('Orphanet'):
                            source_id = source_id_orphanet
                            description = ontology['ontology_description']
                        cursor.execute(sql_query_ontology_term, [accession, term, description, source_id, group_type_id])
                        connection.commit()
                        inserted_ontology_term[old_id] = { 'new_ontology_term_id':cursor.lastrowid }
                        inserted_mondo[ontology['ontology_accession']] = inserted_ontology_term[old_id]

                        # Save OMIM IDs
                        if source_id == 4:
                            omim_ontology_inserted[int(accession)] = inserted_ontology_term[old_id]['new_ontology_term_id']

            # print("OMIM inserted:", omim_ontology_inserted)

            # Insert into disease
            # In the old db the MIM ID was stored in the disease table but in the new schema the MIM IDs are
            # going to be saved in ontology_term and linked to the disease in disease_ontology
            for old_id in disease_data:
                omim_id = disease_data[old_id]['disease_mim']
                name = disease_data[old_id]['disease_name']
                genes = disease_data[old_id]['gene']

                # Prepare the dict to return the disease name and its genes
                # The disease_data key is the old disease id, but different ids can have the 
                # same name
                if name in disease_genes:
                    for gene in genes:
                        disease_genes[name].append(gene)
                else:
                    disease_genes[name] = genes

                # Add 'gene-related' to the disease name
                # It's easier to do it if there is only one gene linked to the disease name
                list_names = format_disease_name(name, genes)

                for name_with_gene in list_names:
                    clean_name = clean_up_disease_name(name_with_gene)

                    if clean_name not in inserted_disease_by_name:
                        cursor.execute(sql_query, [name_with_gene])
                        connection.commit()
                        inserted_disease[old_id] = { 'new_disease_id':cursor.lastrowid }
                        inserted_disease_by_name[clean_name] =  { 'new_disease_id':inserted_disease[old_id]['new_disease_id'] }
                    else:
                        inserted_disease[old_id] = { 'new_disease_id':inserted_disease_by_name[clean_name]['new_disease_id'] }

                # Insert OMIM ID in ontology
                if omim_id is not None: #TODO
                    if omim_id not in omim_ontology_inserted:
                        # Get OMIM data from API
                        omim_disease, omim_desc = get_omim_data(omim_id)
                        if omim_disease is None:
                            omim_disease = omim_id

                        if omim_disease in omim_ontology_term_inserted:
                            print(f"WARNING: OMIM term {omim_disease} already in ontology_term associated with OMIM ID {omim_ontology_term_inserted[omim_disease]}\n")

                        else:
                            # Insert OMIM ID into ontology_term
                            cursor.execute(sql_query_ontology_term, [omim_id, omim_disease, omim_desc, 4, group_type_id])
                            connection.commit()
                            omim_ontology_inserted[omim_id] = cursor.lastrowid
                            omim_ontology_term_inserted[omim_disease] = omim_id

                    # Insert into disease_ontology
                    new_ontology_id = omim_ontology_inserted[omim_id]
                    key = f"{int(inserted_disease[old_id]['new_disease_id'])}-{int(new_ontology_id)}"
                    if key not in inserted_disease_ontology:
                        cursor.execute(sql_query_disease_ontology, [inserted_disease[old_id]['new_disease_id'],  mapping['Data source'], new_ontology_id])
                        connection.commit()
                        inserted_disease_ontology[key] = 1

            # Insert into disease_ontology
            for disease_old_id, ontology in disease_ontology_data.items():
                # print(f"\ndisease old id: {disease_old_id}, ontology data: {ontology}")

                # We skipped the diseases that are not being used by any record
                # Here we have to make sure we don't try to access a disease that was not inserted
                if disease_old_id in inserted_disease:
                    new_disease_id = inserted_disease[disease_old_id]['new_disease_id']
                    new_ontology_id = inserted_mondo[ontology['ontology_accession']]['new_ontology_term_id']
                    
                    mapping_id = None
                    if ontology['mapped_by_attrib'] is not None:
                        mapping_id = mapping[ontology['mapped_by_attrib']]
                    else:
                        mapping_id = mapping['Data source']

                    # print(f"New disease id: {new_disease_id}, new ontology id: {new_ontology_id} -> {ontology['mapped_by_attrib']}")
                    key = f"{int(new_disease_id)}-{int(new_ontology_id)}"
                    if key not in inserted_disease_ontology:
                        cursor.execute(sql_query_disease_ontology, [new_disease_id, mapping_id, new_ontology_id])
                        connection.commit()
                        inserted_disease_ontology[key] = 1

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return inserted_disease_by_name, disease_genes

def populates_locus(host, port, db, user, password, genomic_feature_data, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password):
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
    omim_source_id = fetch_source(host, port, db, user, password, 'OMIM')
    ensembl_source_id = fetch_source(host, port, db, user, password, 'Ensembl')
    version = re.search("[0-9]+", ensembl_db)
    description = f"Update genes to Ensembl release {version.group()}"

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
                if info['mim'] is not None:
                    cursor.execute(sql_query_ids, [genes_ids[gf_id]['new_gf_id'], info['mim'], omim_source_id])
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

def populates_lgd(host, port, db, user, password, gfd_data, inserted_publications, inserted_phenotypes, last_updates, last_update_panel, inserted_disease_by_name, disease_genes, duplicated_names):
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
        'typified by reduced penetrance':'typified by incomplete penetrance', # CHECK
        'incomplete penetrance':'incomplete penetrance'
    }

    sql_query_lgd = f""" INSERT INTO locus_genotype_disease (stable_id, date_review, is_reviewed, 
                         is_deleted, confidence_id, disease_id, genotype_id, locus_id, molecular_mechanism_id)
                         VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                     """
    
    sql_query_stable_id = f""" INSERT INTO g2p_stableid (stable_id, is_live, is_deleted)
                               VALUES (%s, %s, %s)
                           """

    sql_query_lgd_panel = f""" INSERT INTO lgd_panel (is_deleted, relevance_id, lgd_id, panel_id)
                               VALUES (%s, %s, %s, %s)
                           """
    
    sql_query_lgd_comment = f""" INSERT INTO lgd_comment (is_deleted, is_public, lgd_id, user_id, date, comment)
                                 VALUES (%s, %s, %s, %s, %s, %s)
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

    sql_query_lgd_var = f""" INSERT INTO lgd_variant_type (is_deleted, lgd_id, variant_type_ot_id, inherited, de_novo, unknown_inheritance)
                               VALUES (%s, %s, %s, %s, %s, %s)
                           """

    sql_query_lgd_pheno = f""" INSERT INTO lgd_phenotype (is_deleted, lgd_id, phenotype_id)
                               VALUES (%s, %s, %s)
                           """

    sql_query_lgd_mechanism = f""" INSERT INTO molecular_mechanism (mechanism_id, mechanism_support_id, is_deleted)
                                   VALUES (%s, %s, %s)
                               """

    stable_id = 0
    inserted_lgd = {}

    # Fetch ID for mechanism 'undetermined' - this is the default mechanism value
    undetermined_id = fetch_mechanism(host, port, db, user, password, 'undetermined', 'mechanism')

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for gfd, data in gfd_data.items():
                gene_symbol = data['gene_symbol']
                locus_id = fetch_locus_id(host, port, db, user, password, gene_symbol)

                # Clean the disease name to be able to match to the new disease id
                # This process removes a few duplicates
                disease_name = data['disease_name']
                # print("\nDisease name:", disease_name, "; Gene symbol:", data['gene_symbol'])
                # Some disease names were updated to include 'gene-related'
                # We have to add 'gene-related' to 'disease_name' before fetching the new disease id from 'inserted_disease_by_name'
                genes = disease_genes[disease_name]
                # print("Genes:", genes)
                # Add 'gene-related' to the disease name
                # It's easier to do it if there is only one gene linked to the disease name
                list_names = format_disease_name(disease_name, genes)
                disease_id = None

                for disease_name_with_gene in list_names:
                    if(gene_symbol.lower() in disease_name_with_gene.lower()):
                        new_disease_name = clean_up_disease_name(disease_name_with_gene)
                        # print("Clean disease name:", new_disease_name)
                        disease_id = inserted_disease_by_name[new_disease_name]['new_disease_id']
                        # print("New disease id:", disease_id)

                if(disease_id is None):
                    print(f"({gene_symbol}) {disease_name}: {list_names}, genes: {genes}")
                    sys.exit(0)

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

                # variant consequence (new: variant type)
                mechanism = []
                variant_type_list = []
                for var_type in data['variant_consequence_attrib']:
                    # This is a molecular mechanism
                    if var_type == 'gain_of_function_variant':
                        mechanism.append(fetch_mechanism(host, port, db, user, password, 'gain of function', 'mechanism'))
                    elif var_type == 'loss_of_function_variant':
                        mechanism.append(fetch_mechanism(host, port, db, user, password, 'loss of function', 'mechanism'))
                    else:
                        variant_type_list.append(fetch_ontology(host, port, db, user, password, var_type))

                # Set empty mechanism to 'undetermined'
                if len(mechanism) == 0:
                    mechanism.append(undetermined_id)

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

                # Insert mechanisms
                mechanism_ids = []
                mechanism_support = fetch_mechanism(host, port, db, user, password, 'inferred', "support")
                for mec in mechanism:
                    cursor.execute(sql_query_lgd_mechanism, [mec, mechanism_support, 0])
                    connection.commit()
                    mec_id = cursor.lastrowid
                    mechanism_ids.append(mec_id)

                # print(f"locus: {locus_id}, disease: {disease_id}, genotype: {genotype_id}, variant consequence: {variant_gencc_consequences}, panels confidence: {confidence}")

                for unique_mechanism in mechanism_ids:
                    key = f"{locus_id}-{disease_id}-{genotype_id}-{unique_mechanism}" # TODO: Change to support disease updates

                    # Insert LGD
                    # Skip entries with multiple confidence
                    if key not in inserted_lgd.keys():
                        # Insert stable ID
                        stable_id += 1
                        cursor.execute(sql_query_stable_id, [f"G2P{stable_id:05d}", 1, 0])
                        connection.commit()
                        stable_id_pk = cursor.lastrowid

                        cursor.execute(sql_query_lgd, [stable_id_pk, date, 1, 0, final_confidence, disease_id, genotype_id, locus_id, unique_mechanism])
                        connection.commit()
                        inserted_lgd[key] = { 'id':cursor.lastrowid, 'variant_gencc_consequence':variant_gencc_consequences,
                                            'confidence':confidence, 'ccm':ccm_id, 'publications':publications,
                                            'variant_types':variant_type_list, 'phenotypes':phenotypes,
                                            'final_confidence':final_confidence, 'mechanism':unique_mechanism }

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
                            cursor.execute(sql_query_lgd_var, [0, inserted_lgd[key]['id'], var_id, 0, 0, 0])
                            connection.commit()

                        # Insert phenotypes
                        for new_pheno_id in phenotypes:
                            cursor.execute(sql_query_lgd_pheno, [0, inserted_lgd[key]['id'], new_pheno_id])
                            connection.commit()

                        # Insert comments
                        for comment in data['comments']:
                            user_id = fetch_user(host, port, db, user, password, comment['username'])
                            cursor.execute(sql_query_lgd_comment, [0, comment['is_public'], inserted_lgd[key]['id'], user_id, comment['created'], comment['comment']])

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
                                cursor.execute(sql_query_lgd_var, [0, lgd_id, var_id, 0, 0, 0])
                                connection.commit()
                        # Insert phenotypes
                        for new_pheno_id in phenotypes:
                            if new_pheno_id not in inserted_lgd[key]['phenotypes']:
                                cursor.execute(sql_query_lgd_pheno, [0, lgd_id, new_pheno_id])
                                connection.commit()

                        # TODO: update last_updated

                    elif final_confidence != inserted_lgd[key]['final_confidence']:
                        # print(f"\nKey already inserted with id: {inserted_lgd[key]}")
                        print(f"(Different confidence) Key already in db: {key}, locus: {locus_id}, disease: {disease_id}, genotype: {genotype_id}, panels confidence: {confidence}")

                    else:
                        # print(f"\nKey already inserted with id: {inserted_lgd[key]}")
                        print(f"Key already in db: {key}, locus: {locus_id}, disease: {disease_id}, genotype: {genotype_id}, panels confidence: {confidence}")

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

def format_disease_name(name_original, genes):
    """
        Check if the disease name has the following format:
            gene-related
            gene-associated
        If not, then add the gene to the disease name
    """
    list_names = []

    for gene in genes:
        name = name_original.lstrip().rstrip()
        name_lower = name.lower()
        gene_lower = gene.lower()
        match = re.search(f"^{gene_lower}\s*-?\s*(related|associated)", name_lower)

        if match is None:
            name = f"{gene}-related {name}"

        list_names.append(name)

    return list_names

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

def fetch_mechanism(host, port, db, user, password, value, type):
    id = None

    sql_query = f""" SELECT id
                     FROM cv_molecular_mechanism
                     WHERE value = %s AND type = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [value, type])
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

    if id is None:
        print(f"ERROR: missing ontology_term for {value}\n")

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

def fetch_user(host, port, db, user, password, username):
    id = None

    sql_query = f""" SELECT id
                     FROM user
                     WHERE username = %s
                 """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query, [username])
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
    parser.add_argument("--omim_key", default='', help="OMIM API key")

    args = parser.parse_args()

    global omim_key_global

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
    omim_key_global = args.omim_key

    print("INFO: Fetching data from old schema...")

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
    disease_data, duplicated_names = dump_diseases(host, port, db, user, password)

    # Populates: ontology_term, ontology
    # variant gencc consequence uses these terms
    # disease ontology stored here
    ontology_term_data, disease_ontology_data = dump_ontology(host, port, db, user, password, attribs)

    # Populates: locus
    # TODO: genomic_feature_statistic and genomic_feature_statistic_attrib
    genomic_feature_data = dump_genes(host, port, db, user, password)

    # Populates: locus_genotype_disease
    gfd_data, last_updates, last_update_panel = dump_gfd(host, port, db, user, password, attribs)

    print("INFO: Fetching data from old schema... done\n")

    ### Store the data in the new database ###
    # Populates: source
    print("INFO: Populating source...")
    populate_source(new_host, new_port, new_db, new_user, new_password)
    print("INFO: source populated\n")

    # Populates: attrib, attrib_type, ontology_term (variant consequence, variant type)
    print("INFO: Populating attribs...")
    populate_attribs(new_host, new_port, new_db, new_user, new_password, attribs)
    populate_new_attribs(new_host, new_port, new_db, new_user, new_password)
    print("INFO: attribs populated\n")

    print("INFO: Populating user data...")
    # Populates: user, panel, user_panel, ontology_term
    populates_user_panel(new_host, new_port, new_db, new_user, new_password, user_panel_data, panels_data)
    print("INFO: user data populated\n")

    # Populates: publication
    # inserted_publications = {}
    print("INFO: Populating publications...")
    inserted_publications = populates_publications(new_host, new_port, new_db, new_user, new_password, publications_data)
    print("INFO: publications populated\n")

    # Populates: phenotype
    # inserted_phenotypes = {}
    print("INFO: Populating phenotypes...")
    inserted_phenotypes = populates_phenotypes(new_host, new_port, new_db, new_user, new_password, phenotype_data)
    print("INFO: phenotypes populated\n")

    # Populates: disease, disease_ontology, ontology_term
    # Update disease names before populating new db: https://www.ebi.ac.uk/panda/jira/browse/G2P-45
    print("INFO: Populating diseases...")
    inserted_disease_by_name, disease_genes = populates_disease(new_host, new_port, new_db, new_user, new_password, disease_data, disease_ontology_data, duplicated_names)
    print("INFO: diseases populated\n")

    # Populates: locus, locus_attrib, locus_identifier
    print("INFO: Populating genes...")
    inserted_gene_ids = populates_locus(new_host, new_port, new_db, new_user, new_password, genomic_feature_data, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password)
    print("INFO: genes populated\n")
    print("INFO: Populating genes synonyms...")
    populates_gene_synonyms(new_host, new_port, new_db, new_user, new_password, ensembl_host, ensembl_port, ensembl_db, ensembl_user, ensembl_password)
    print("INFO: genes synonyms populated\n")

    # Populates: locus_genotype_disease
    print("INFO: Populating LGD...")
    populates_lgd(new_host, new_port, new_db, new_user, new_password, gfd_data, inserted_publications, inserted_phenotypes, last_updates, last_update_panel, inserted_disease_by_name, disease_genes, duplicated_names)
    print("INFO: LGD populated\n")


if __name__ == '__main__':
    main()
