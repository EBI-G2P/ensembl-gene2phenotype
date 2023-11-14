#!/usr/bin/env python3

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2023] EMBL-European Bioinformatics Institute
#
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
This script finds duplicated disease names in the table disease
 - flags which disease name are duplicated
 - checks if entries are used in other tables
 - prints sql queries to 'sql_file'
 - 'error_file' has all the gfd_ids that cannot be updated because same entry already exists in the db

pyenv local variation-production
python find_dup_disease_name.py --database dlemos_G2P_2023_08_02 --user xxxx --password xxxx --host xxxx --port xxxx
"""

import os
import sys
import argparse
import re
import mysql.connector
from mysql.connector import Error


def clean_up_string(disease_name):
    new_disease_name = disease_name

    new_disease_name = re.sub(r'^\s+|\s+$', '', new_disease_name)
    new_disease_name = re.sub(r'^\?', '', new_disease_name)
    new_disease_name = re.sub(r'\n', '', new_disease_name)
    new_disease_name = re.sub(r', ', ' ', new_disease_name)
    new_disease_name = re.sub(r'\.$', '', new_disease_name)
    new_disease_name = re.sub(r'\“', '', new_disease_name)
    new_disease_name = re.sub(r'\”', '', new_disease_name)
    new_disease_name = re.sub('-', ' ', new_disease_name)
    new_disease_name = re.sub(r'\t', '', new_disease_name)

    new_disease_name = new_disease_name.lower()

    # remove 'biallelic' and 'autosomal'
    new_disease_name = re.sub(r'biallelic$', '', new_disease_name)
    new_disease_name = re.sub(r'autosomal$', '', new_disease_name)
    new_disease_name = re.sub(r'\(biallelic\)$', '', new_disease_name)
    new_disease_name = re.sub(r'\(autosomal\)$', '', new_disease_name)

    new_disease_name = re.sub(r'type xvii$', 'type 17', new_disease_name)
    new_disease_name = re.sub(r'type ix$', 'type 9', new_disease_name)
    new_disease_name = re.sub(r'type viii$', 'type 8', new_disease_name)
    new_disease_name = re.sub(r'type vii$', 'type 7', new_disease_name)
    new_disease_name = re.sub(r'type vi$', 'type 6', new_disease_name)
    new_disease_name = re.sub(r'type v$', 'type 5', new_disease_name)
    new_disease_name = re.sub(r'type iv$', 'type 4', new_disease_name)
    new_disease_name = re.sub(r'type iii$', 'type 3', new_disease_name)
    new_disease_name = re.sub(r'type ii$', 'type 2', new_disease_name)
    new_disease_name = re.sub(r'type i$', 'type 1', new_disease_name)

    # remove 'type'
    if re.search(r'\s+type\s+[0-9]+[a-z]?$', new_disease_name):
        new_disease_name = re.sub(r'\s+type\s+', ' ', new_disease_name)

    # specific cases
    new_disease_name = re.sub(r'\s+syndrom$', ' syndrome', new_disease_name)
    new_disease_name = re.sub(r'\(yndrome', 'syndrome', new_disease_name)
    new_disease_name = re.sub('sjoegren larsson syndrom', 'sjogren larsson syndrome', new_disease_name)
    new_disease_name = re.sub('sjorgren larrson syndrome', 'sjogren larsson syndrome', new_disease_name)
    new_disease_name = re.sub('marinesco sjoegren syndrome', 'marinesco sjogren syndrome', new_disease_name)
    new_disease_name = re.sub('complementation group 0', 'complementation group o', new_disease_name)
    new_disease_name = re.sub('\s+\([a-z]+$', '', new_disease_name)

    new_disease_name = re.sub(r'\(|\)', ' ', new_disease_name)
    new_disease_name = re.sub(r'\s+', ' ', new_disease_name)
    new_disease_name = re.sub(r'\s+$', '', new_disease_name)

    # tokenise string
    disease_tokens = sorted(new_disease_name.split())

    return " ".join(disease_tokens)


""" 
get_matches
Finds duplicated disease names in table disease

Returns:
Returns a list of disease ids with the same disease name
{ 'disease_name' : [disease_id, disease_id, disease_id] }
"""
def get_matches(host, port, db, user, password):

    diseases = {}
    disease_mim = {} # disease_id: mim id
    disease_names = {} # disease_id: disease name

    sql_query = """ SELECT disease_id,name,mim
                    FROM disease """

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
            print (f"Selecting diseases from {db}.disease ...")
            for row in data:
                if row[2] is not None:
                    disease_mim[row[0]] = row[2]

                new_disease_name = clean_up_string(row[1])
                disease_names[row[0]] = row[1]
                if new_disease_name not in diseases:
                    diseases[new_disease_name] = [row[0]]
                else:
                    other_mim = ""
                    # Check if mim id is the same - we don't want to merge diseases with different mim ids
                    for id in diseases[new_disease_name]:
                        if id in disease_mim:
                            other_mim = disease_mim[id]
                    if row[0] in disease_mim and row[2] is not None and other_mim != row[2]:
                        # Print to file - to be reviewed
                        print(f"Same diseases have different MIM id, name {row[0]} {row[1]} {row[2]}")
                    else:
                        diseases[new_disease_name].append(row[0])
                # diseases[row[1]] = { 'id':row[0], 'mim':row[2] }
            print (f"Selecting diseases from {db}.disease ... done")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            print("MySQL connection is closed (get_matches)")

    return diseases, disease_mim, disease_names


def check_other_tables(host, port, db, user, password, list_of_duplicates, disease_name):
    result = {}
    list_of_ids = {}

    map = { "genomic_feature_disease" : "genomic_feature_disease_id",
            "genomic_feature_disease_deleted" : "genomic_feature_disease_id",
            "genomic_feature_disease_log" : "genomic_feature_disease_id",
            "GFD_disease_synonym" : "GFD_disease_synonym_id",
            "disease_ontology_mapping" : "disease_id" }

    for table in map:
        # print (f"\nChecking if disease {disease_name} exists in {db}.{table}...")

        key = map[table]

        sql_query = f""" select {key} 
                         from {table} 
                         where disease_id = %s """

        connection = mysql.connector.connect(host=host,
                                             database=db,
                                             user=user,
                                             port=port,
                                             password=password)

        try:
            if connection.is_connected():
                cursor = connection.cursor()
                info = {}
                list_of_ids[table] = {}
                for id in list_of_duplicates[disease_name]:
                    cursor.execute(sql_query, [id])
                    data = cursor.fetchall()
                    if len(data) != 0:
                        info[id] = 'found'
                        for row in data:
                            try:
                                list_of_ids[table][id]
                            except KeyError:
                                list_of_ids[table][id] = [row[0]]
                            else:
                                list_of_ids[table][id].append(row[0])
                    else:
                        info[id] = 'not_found'
                result[table] = info
                # print (f"Checking if disease {disease_name} exists in {db}.{table}... done\n")

        except Error as e:
            print("Error while connecting to MySQL", e)
        finally:
            if connection.is_connected():
                cursor.close()
                connection.close()
                # print("MySQL connection is closed (check_other_tables)")

    return result, list_of_ids

def delete_ids(host, port, db, user, password, found, list_of_ids, error_file, sql_file, diseases_to_delete, disease_mim):
    map = { "genomic_feature_disease" : "genomic_feature_disease_id",
            "genomic_feature_disease_deleted" : "genomic_feature_disease_id",
            "genomic_feature_disease_log" : "genomic_feature_disease_id",
            "GFD_disease_synonym" : "GFD_disease_synonym_id",
            "disease_ontology_mapping" : "disease_id" }

    found_mim = {}
    count_ids = {}
    for table in found:
        for id in found[table]:
            if found[table][id] == "found":
                try:
                    count_ids[id]
                except:
                    count_ids[id] = 1
                else:
                    count_ids[id] += 1
            
            if id in disease_mim:
                found_mim[id] = 1

    # select a disease_ti to keep
    # first chooses the id that is being used more times
    int = 0
    id_to_keep = 0
    for count in count_ids:
        n = count_ids[count]
        if n > int:
            int = n
            id_to_keep = count

    # check if id_to_keep has MIM
    # if the selected id_to_keep has no MIM ID then try to select one that has an id
    if id_to_keep not in found_mim:
        for disease_id_key in found_mim:
            id_to_keep = disease_id_key

    print (f"Going to keep disease_id: {id_to_keep}")

    file = open(error_file, "a")
    file_sql = open(sql_file, "a")

    # Check how to update/delete rows for each table
    # Before updating disease ids we have to check if the entries have the same allelic_requirement and mutation_consequence
    update_gfd = {}
    for table in list_of_ids:
        print (f"Checking {table}...")
        for disease_id in list_of_ids[table]:
            if disease_id != id_to_keep:
                n_entries = len(list_of_ids[table][disease_id])
                rows_ids = list_of_ids[table][disease_id]
                print (f" disease_id = {disease_id} going to be replaced by disease_id = {id_to_keep} in {n_entries} rows: {rows_ids}?")
                # Check if we can update gfd
                if table == "genomic_feature_disease":
                    row_info = get_gfd_entries(host, port, db, user, password, id_to_keep, rows_ids)
                    update_gfd = check_gfd_entries(host, port, db, user, password, id_to_keep, row_info, file)

                for row in rows_ids:
                    if table == "genomic_feature_disease" and row not in update_gfd:
                        print (f" *** entry printed to error_file (gfd_id : {row}) ***")
                        file.write(f"; disease_id = {disease_id} cannot be replaced by disease_id = {id_to_keep} in gfd_id {rows_ids}\n")
                    elif row in update_gfd:
                        query_to_run = f"update {table} set disease_id = {id_to_keep} where {map[table]} = {row}"
                        file_sql.write(f"{query_to_run}\n")
                        print (f" ACTION (sql_file): {query_to_run}")
                        diseases_to_delete[disease_id] = 1
                    elif row not in update_gfd:
                        print (f" {table} cannot be updated")
                    else:
                        print (f"ERROR")
    file.close()
    file_sql.close()

    return diseases_to_delete


def get_gfd_entries(host, port, db, user, password, id_to_keep, rows_ids):
    result = {}
    sql_query_select = f""" select genomic_feature_id, allelic_requirement_attrib, mutation_consequence_attrib
                            from genomic_feature_disease 
                            where genomic_feature_disease_id = %s """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for row in rows_ids:
                result[row] = {}
                cursor.execute(sql_query_select, [row])
                data = cursor.fetchall()
                if len(data) != 0:
                    result[row]["genomic_feature_id"] = data[0][0]
                    result[row]["allelic_requirement_attrib"] = data[0][1]
                    result[row]["mutation_consequence_attrib"] = data[0][2]
                else:
                    print(f"Error: no genomic_feature_disease_id = {row} found!!")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
    
    return result

def check_gfd_entries(host, port, db, user, password, id_to_keep, row_info, file):
    update = {}

    # genomic_feature_id, disease_id, allelic_requirement_attrib, mutation_consequence_attrib
    sql_query = f""" select genomic_feature_disease_id from genomic_feature_disease 
                     where genomic_feature_id = %s and disease_id = %s 
                     and allelic_requirement_attrib = (%s) and mutation_consequence_attrib = (%s)"""
    
    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for row in row_info:
                gf_id = row_info[row]["genomic_feature_id"]
                ar = row_info[row]["allelic_requirement_attrib"]
                mc = row_info[row]["mutation_consequence_attrib"]
                cursor.execute(sql_query, [gf_id,id_to_keep,list(ar)[0],list(mc)[0]])
                data = cursor.fetchall()
                if len(data) != 0:
                    print(f"   genomic_feature_disease {row} cannot be updated. Found another gfd with same values gfd_id: {data[0][0]}")
                    file.write(f"gfd_id = {data[0][0]} already has disease_id = {id_to_keep}")
                else:
                    update[row] = 1
                    print(f"   genomic_feature_disease {row} can be updated")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

    return update

"""
Write sql queries to delete diseases from tables:
  - 'disease'
  - 'search'
These diseases are not used by any table anymore.
"""
def delete_diseases(host, port, db, user, password, diseases_to_delete, error_file, sql_file):
    file = open(error_file, "a")
    file_sql = open(sql_file, "a")
    file.write("\n### Delete diseases ###\n")
    file_sql.write("\n### Delete diseases ###\n")

    sql_query = """ SELECT name FROM disease WHERE disease_id = %s """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            for disease_id in diseases_to_delete:
                cursor.execute(sql_query, [disease_id])
                data = cursor.fetchall()
                if len(data) != 0:
                    query_to_run = f"delete from disease where disease_id = {disease_id}"
                    query_to_run_search = f"delete from search where binary search_term = '{data[0][0]}'" # case-sensitive
                    print(f"ACTION (sql_file): {query_to_run}")
                    print(f"ACTION (sql_file): {query_to_run_search}\n")
                    file_sql.write(f"ACTION (sql_file): {query_to_run}\n")
                    file_sql.write(f"ACTION (sql_file): {query_to_run_search}\n\n")
                else:
                    print(f"disease_id {disease_id} cannot be deleted: not found in disease table\n")
                    file.write(f"disease_id {disease_id} cannot be deleted: not found in disease table\n")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            print("MySQL connection is closed (delete_diseases)")


def main():
    parser = argparse.ArgumentParser(description="Find duplicated disease names")
    parser.add_argument("--host", required=True, help="Database host")
    parser.add_argument("--port", required=True, help="Host port")
    parser.add_argument("--database", required=True, help="Database name")
    parser.add_argument("--user", required=True, help="Username")
    parser.add_argument("--password", default='', help="Password (default: '')")
    parser.add_argument("--error_file", default="error_log.txt", help="File output containing entries that could not be updated")
    parser.add_argument("--sql_file", default="sql_to_run.txt", help="File output containing sql queries to run")

    args = parser.parse_args()

    host = args.host
    port = args.port
    db = args.database
    user = args.user
    password = args.password
    error_file = args.error_file
    sql_file = args.sql_file

    diseases_to_delete = {}
    list_of_duplicates, disease_mim, disease_names = get_matches(host, port, db, user, password)

    for disease in list_of_duplicates:
        if len(list_of_duplicates[disease]) > 1:
            print (f"\n{disease}: {list_of_duplicates[disease]}")
            for id in list_of_duplicates[disease]:
                print (f"  {id}: {disease_names[id]}")

            found, list_of_ids = check_other_tables(host, port, db, user, password, list_of_duplicates, disease)
            diseases_to_delete = delete_ids(host, port, db, user, password, found, list_of_ids, error_file, sql_file, diseases_to_delete, disease_mim)

    # Delete diseases that are not used anymore
    print("\nGoing to delete diseases that are not being used anymore ...")
    delete_diseases(host, port, db, user, password, diseases_to_delete, error_file, sql_file)
    print("Going to delete diseases that are not being used anymore ... done")

if __name__ == '__main__':
    main()
