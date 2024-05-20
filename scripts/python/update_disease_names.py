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
    This script checks which disease names can be updated to use the dyadic format

    Script: update_disease_names.py

    Options:
        --host
        --port 
        --user
        --password (optional)
        --database
"""

import os
import sys
import argparse
import re
import mysql.connector
from mysql.connector import Error


"""
    fetch_from_db checks if the diseases can be updated to dyadic name.
    When checking name it has to consider the MIM ID - same disease in a different gene has a different MIM ID (OMIM API)

    Output: 
            list_entries (dict): diseases that can be updated
            count_mim_ids (dict): mim id and associated disease names
            writes to files:
                disease_names_with_gene.txt - list of diseases that already have the gene symbol in the name
                disease_names_with_pseudo_gene.txt - list of diseases that use an old gene symbol in the name
"""
def fetch_from_db(host, port, db, user, password):
    file_gene = open("disease_names_with_gene.txt", "w") # diseases that use the current gene symbol
    file_pseudo = open("disease_names_with_pseudo_gene.txt", "w") # diseases that use an old gene symbol

    # write headers
    file_gene.write("gfd_id\tdisease_id\tdisease\n")
    file_pseudo.write("gfd_id\tdisease_id\tdisease\tgene synonym\tgene symbol\n")

    # list of disease to update
    list_entries = {}
    # list of mim ids and their disease names
    count_mim_ids = {}

    # select diseases that are only used once in genomic_feature_disease
    sql_query = """ SELECT d.name, gfd.genomic_feature_disease_id, gf.gene_symbol, gfd.disease_id, gf.genomic_feature_id, d.mim
                    FROM disease d
                    LEFT JOIN genomic_feature_disease gfd on gfd.disease_id = d.disease_id
                    LEFT JOIN genomic_feature gf on gf.genomic_feature_id = gfd.genomic_feature_id
                    GROUP BY d.name
                    HAVING COUNT(*) = 1 """
    
    sql_query_gene = f""" SELECT name
                          FROM genomic_feature_synonym
                          WHERE genomic_feature_id = %s """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            # select the disease names
            cursor.execute(sql_query)
            data = cursor.fetchall()
            if len(data) != 0:
                for row in data:
                    if row[0] not in list_entries.keys() and row[1] is not None:
                        # Fetch gene synonyms
                        gene_synonyms = []
                        synonym_flag = 0
                        cursor.execute(sql_query_gene, [row[4]])
                        data_gene = cursor.fetchall()
                        for row_gene in data_gene:
                            gene_synonyms.append(row_gene[0])

                        for synonym in gene_synonyms:
                            # check if the disease name is using an old gene symbol
                            if f"{synonym}-" in row[0] or f"{synonym}," in row[0] or f"{synonym} " in row[0] or f" {synonym}" in row[0] or f",{synonym}" in row[0] or f"-{synonym}" in row[0]:
                                synonym_flag = 1
                                file_pseudo.write(f"{row[1]}\t{row[3]}\t{row[0]}\t{synonym}\t{row[2]}\n")

                        # Skip diseases already represented with dyadic name
                        if ('related' in row[0].lower() or 'associated' in row[0].lower()) and row[2] in row[0]:
                            file_gene.write(f"{row[1]}\t{row[3]}\t{row[0]}\t{row[5]}\n")
                        elif ('-related' in row[0].lower() or '-associated' in row[0].lower()) and synonym_flag == 1:
                            file_pseudo.write(f"{row[1]}\t{row[3]}\t{row[0]}\n")
                        elif row[2] in row[0]:
                            file_gene.write(f"{row[1]}\t{row[3]}\t{row[0]}\t{row[5]}\n")
                        else:
                            list_entries[row[0]] = {     'gfd_id':row[1],
                                                         'gene':row[2],
                                                         'disease_id':row[3],
                                                         'new_disease_name':f"{row[2]}-related {row[0]}",
                                                         'mim_id': row[5] }

                            try:
                                count_mim_ids[row[5]].add(row[0])
                            except:
                                count_mim_ids[row[5]] = set()
                                count_mim_ids[row[5]].add(row[0])

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    file_gene.close()
    file_pseudo.close()

    return list_entries, count_mim_ids

"""
    writes to files:
        update_disease_names.txt - list of diseases to be updated
        update_disease_names_sql.txt - sql queries to update disease names
"""
def update_disease(host, port, db, user, password, list_diseases, mim_id_diseases):
    file = open("update_disease_names.txt", "w")
    file_sql = open("update_disease_names_sql.txt", "w")
    file.write("genomic_feature_disease_id\told disease name\tnew disease name\tmim id\tflag mim\n")

    sql_query = f""" SELECT disease_id
                     FROM disease
                     WHERE name = %s """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for disease_name in list_diseases:
                cursor.execute(sql_query, [list_diseases[disease_name]['new_disease_name']])
                data = cursor.fetchall()
                for row in data:
                    print(f"(dyadic name already exists in db) UPDATE genomic_feature_disease SET disease_id = {row[0]} WHERE genomic_feature_disease_id = {list_diseases[disease_name]['gfd_id']}")

                # Check if mim is linked to different disease names
                flag = 0
                if len(mim_id_diseases[list_diseases[disease_name]['mim_id']]) > 1 and list_diseases[disease_name]['mim_id'] is not None:
                    flag = 1

                file.write(f"{list_diseases[disease_name]['gfd_id']}\t{disease_name}\t{list_diseases[disease_name]['new_disease_name']}\t{list_diseases[disease_name]['mim_id']}\t{flag}\n")
                file_sql.write(f"UPDATE disease set name = \"{list_diseases[disease_name]['new_disease_name']}\" WHERE disease_id = {list_diseases[disease_name]['disease_id']};\n")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    file.close()
    file_sql.close()


def main():
    parser = argparse.ArgumentParser(description="Update disease to dyadic name")
    parser.add_argument("--host", required=True, help="Database host")
    parser.add_argument("--port", required=True, help="Host port")
    parser.add_argument("--database", required=True, help="Database name")
    parser.add_argument("--user", required=True, help="Username")
    parser.add_argument("--password", default='', help="Password (default: '')")

    args = parser.parse_args()

    host = args.host
    port = args.port
    db = args.database
    user = args.user
    password = args.password

    diseases_to_update, mim_id_diseases = fetch_from_db(host, port, db, user, password)
    update_disease(host, port, db, user, password, diseases_to_update, mim_id_diseases)

if __name__ == '__main__':
    main()