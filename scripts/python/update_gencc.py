#!/usr/bin/env python3

import subprocess 
import argparse
import os
import sys
import mysql.connector
from mysql.connector import Error
from datetime import date, datetime
import requests
import json
import gzip
import csv
from openpyxl import Workbook

# Mapping terms to GenCC IDs
allelic_requirement = {
    "biallelic_autosomal" : "HP:0000007",
    "monoallelic_autosomal" : "HP:0000006",
    "monoallelic_X_hem"  : "HP:0001417",
    "monallelic_Y_hem" : "HP:0001450",
    "monoallelic_X_het" : "HP:0001417",
    "mitochondrial" : "HP:0001427",
    "monoallelic_PAR" : "HP:0000006",
    "biallelic_PAR" : "HP:0000007"
}
confidence_category = {
    "definitive" : "GENCC:100001",
    "strong" : "GENCC:100002",
    "moderate" : "GENCC:100003",
    "limited" : "GENCC:100004",
    "disputed": "GENCC:100005",
    "refuted": "GENCC:100006"
}


def get_ols(disease_name):
    # only using mondo because mondo gives a close enough match with how we name diseases in G2P
    statement = "No disease mim"
    endpoint = 'http://www.ebi.ac.uk/ols/api/search?q='
    ontology = '&ontology=mondo'
    url = endpoint + disease_name + ontology
    result = requests.get(url)
    if result.status_code == 200:
        final_result = json.loads(result.content)
        response = final_result["response"]
        documents = response["docs"]

        mondo_id = [i["obo_id"] for i in documents if "obo_id" in i ]
    else:
        print("Connecting to the " + endpoint + " failed")
        sys.exit()
        pass
        
    if len(mondo_id) > 0:
        return mondo_id[0]
    else:
        return statement

def fetch_g2p_attribs(host, port, db, user, password):
    """
        Fetchs allelic requirement and mutation consequence attribs from the db.
    """
    ar_attribs = {}
    mc_attribs = {}

    sql_query_attribs = """ SELECT at.code, a.attrib_id, a.value
                            FROM attrib a 
                            LEFT JOIN attrib_type at ON at.attrib_type_id = a.attrib_type_id
                            WHERE at.code = 'allelic_requirement' or at.code = 'mutation_consequence'
                        """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_attribs)
            attrib_data = cursor.fetchall()
            for row in attrib_data:
                if(row[0] == "allelic_requirement"):
                    ar_attribs[row[1]] = row[2] # key: attrib id; value: attrib name
                else:
                    mc_attribs[row[1]] = row[2] # key: attrib id; value: attrib name
    
    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
    
    return ar_attribs, mc_attribs

def fetch_g2p_records(host, port, db, user, password, ar_attribs_dict, mc_attribs_dict):
    """
        Fetchs all G2P records from the db.
    """
    all_records = {}

    sql_query_gfd = """ SELECT gfd.genomic_feature_disease_id, gf.gene_symbol, d.name,
                        gfd.allelic_requirement_attrib, gfd.mutation_consequence_attrib
                        from genomic_feature_disease gfd
                        left join genomic_feature gf on gf.genomic_feature_id = gfd.genomic_feature_id
                        left join disease d on d.disease_id = gfd.disease_id
                    """

    connection = mysql.connector.connect(host=host,
                                         database=db,
                                         user=user,
                                         port=port,
                                         password=password)

    try:
        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute(sql_query_gfd)
            gfd_data = cursor.fetchall()
            for row in gfd_data:
                ar_final_values = []
                mc_final_values = []

                for ar_id in row[3]:
                    ar_final_values.append(ar_attribs_dict[int(ar_id)])
                for mc_id in row[4]:
                    mc_final_values.append(mc_attribs_dict[int(mc_id)])

                gene_symbol = row[1]
                disease = row[2]
                ar_final_values.sort()
                mc_final_values.sort()
                gfd_ar = ";".join(ar_final_values)
                gfd_mc = ";".join(mc_final_values)

                key = f"{gene_symbol}---{disease}---{gfd_ar}---{gfd_mc}"
                all_records[key] = row[0]

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
    
    return all_records

def convert_txt_to_excel(input_file, output_file):
    """
        Converts a text file to an Excel file.
    """
    wb = Workbook()
    ws = wb.active

    delimiter='\t'

    with open(input_file, 'r') as file:
        for row_index, line in enumerate(file, start=1):
            for col_index, value in enumerate(line.strip().split(delimiter), start=1):
                ws.cell(row=row_index, column=col_index, value=value)
    wb.save(output_file)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-p", "--path",
                    default='/nfs/production/flicek/ensembl/variation/G2P/GenCC_create/',
                    help="Path where the G2P and GenCC files are going to be saved")
    ap.add_argument("--host", required=True, help="G2P database host")
    ap.add_argument("--port", required=True, help="Host port")
    ap.add_argument("--database", required=True, help="G2P Database name")
    ap.add_argument("--user", required=True, help="Username for the G2P db")
    ap.add_argument("--password", default='', help="Password (default: '')")
    args = ap.parse_args()

    host = args.host
    port = args.port
    db = args.database
    user = args.user
    password = args.password

    ensembl_dir = os.environ.get('ENSEMBL_ROOT_DIR')

    if not ensembl_dir or not os.path.exists(f"{ensembl_dir}/ensembl-gene2phenotype/scripts/download_file.sh"):
        raise FileNotFoundError("ENSEMBL_ROOT_DIR is not set correctly or the script does not exist")

    print("\nDownloading G2P files...")
    subprocess.run(['bash', f"{ensembl_dir}/ensembl-gene2phenotype/scripts/download_file.sh", args.path])
    print("Downloading G2P files... done\n")

    # Attach the date to the path
    present_day = date.today()
    args.path = args.path + "/" + str(present_day)

    print(f"Using directory for GenCC files: {args.path}\n")
    files = [f for f in os.listdir(args.path) if os.path.isfile(os.path.join(args.path, f))]

    outfile = args.path + "/G2P_GenCC.txt"
    final_output_file = args.path + "/G2P_GenCC.xlsx"

    final_data_to_submit = {}
    submitter_id = "GENCC:000112" # G2P submitter id
    submitter_name = "TGMI G2P" # G2P submitter name
    assertion_criteria_url = "https://www.ebi.ac.uk/gene2phenotype/terminology"
    g2p_url = "https://www.ebi.ac.uk/gene2phenotype/gfd?dbID="
    submission_id_base = 1000112 # ID maintained by us. Any alphanumeric string will be accepted up to 64 characters

    print(f"Fetching all G2P records...")
    # Fetch the attribs from G2P db
    ar_attribs, mc_attribs = fetch_g2p_attribs(host, port, db, user, password)
    # Allelic requeriment and mutation consequence are type SET
    # Doing a join is complicated when we have multiple values in the SET
    # That is why we pre-fetched the attribs with fetch_g2p_attribs()
    all_g2p_records = fetch_g2p_records(host, port, db, user, password, ar_attribs, mc_attribs)
    print(f"Fetching all G2P records... done\n")

    # Output format
    # submission_id: automatic id
    # hgnc_id: HGNC gene ID
    # hgnc_symbol: gene symbol (optional)
    # disease_id: omim, mondo or orpha id
    # disease_name: our disease name (optional)
    # moi_id: allelic requeriment GenCC ID
    # moi_name: allelic requeriment (optional)
    # submitter_id: G2P GenCC ID
    # submitter_name: G2P (optional)
    # classification_id: confidence GenCC ID
    # classification_name: confidence (optional)
    # date: format YYYY/MM/DD
    # public_report_url: G2P URL for the record (optional)
    # pmids: Listing of PMIDs that have been used in the submission seperated by comma
    # assertion_criteria_url: G2P terminology url

    with open(outfile, mode='w') as output_file:
        # Write output header
        output_file.write("submission_id\thgnc_id\thgnc_symbol\tdisease_id\tdisease_name\tmoi_id\tmoi_name\tsubmitter_id\tsubmitter_name\tclassification_id\tclassification_name\tdate\tpublic_report_url\tpmids\tassertion_criteria_url\n")

        for file in files:
            file_path = args.path + "/" + file

            with gzip.open(file_path, mode='rt') as gz_file:
                csv_reader = csv.DictReader(gz_file)
                
                for row in csv_reader:
                    gene_symbol = row["gene symbol"]
                    disease_name = row["disease name"]
                    ar = row["allelic requirement"] # we are going to skip records with multiple allelic requirement
                    mc_list = row["mutation consequence"].split(";")
                    mc_list.sort()
                    mc = ";".join(mc_list)
                    key = f"{gene_symbol}---{disease_name}---{ar}---{mc}"

                    if key not in final_data_to_submit:
                        # HGNC ID
                        h = row["hgnc id"]
                        hgnc_id = f"HGNC:{h}"

                        # Prepare MOI - allelic requeriment
                        if ar in allelic_requirement:
                            moi_id = allelic_requirement[ar]
                        else:
                            print(f"SKIP: invalid allelic requeriment '{ar}' not found for key '{key}' in file '{file}'")
                            continue

                        # Get the G2P internal ID to use in the URL
                        if key in all_g2p_records:
                            g2p_id = all_g2p_records[key]
                        else:
                            sys.exit(f"Key: '{key}' from download files not found in G2P database")

                        record_url = g2p_url + str(g2p_id)

                        # the submission id is generated and maintained by us
                        g2p_id_formatted = f"{int(g2p_id):05}"
                        submission_id = f"{submission_id_base}{g2p_id_formatted}"

                        # Confidence
                        confidence = row["confidence category"]
                        classification_id = confidence_category[confidence]

                        # Update disease name to dyadic
                        if not disease_name.startswith(gene_symbol):
                            new_disease_name = gene_symbol + "-related " + disease_name
                        else:
                            new_disease_name = disease_name

                        # We use the OMIM, Mondo or Orphanet as the disease_id
                        disease_id = row["disease mim"]
                        disease_ontology = row["disease ontology"]
                        if disease_id == "No disease mim" and disease_ontology:
                            disease_id = disease_ontology
                        
                        # pmids = row["pmids"].replace(";", ",")
                        pmids = row["pmids"]

                        g2p_date = row["gene disease pair entry date"]
                        if g2p_date:
                            g2p_date_tmp = datetime.strptime(g2p_date, "%Y-%m-%d %H:%M:%S")
                            g2p_date = g2p_date_tmp.strftime("%Y/%m/%d")

                        line_to_output = f"{submission_id}\t{hgnc_id}\t{gene_symbol}\t{disease_id}\t{new_disease_name}\t{moi_id}\t{ar}\t{submitter_id}\t{submitter_name}\t{classification_id}\t{confidence}\t{g2p_date}\t{record_url}\t{pmids}\t{assertion_criteria_url}\n"
                        output_file.write(line_to_output)

                        final_data_to_submit[key] = 1

    output_file.close()

    convert_txt_to_excel(outfile, final_output_file)

if __name__ == '__main__':
    main()