import subprocess 
import argparse
import pandas as pd
import os
import random 
import sys
import datetime
import requests
import json

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
con_category = {
    "definitive" : "GENCC:100001",
    "strong" : "GENCC:100002",
    "moderate" : "GENCC:100003",
    "limited" : "GENCC:100004"
}

subprocess.run(['bash', 'download_file.sh' ])

ap = argparse.ArgumentParser()

ap.add_argument("-p", "--path", help="path of where the downloaded files are, usually would be /hps/software/users/ensembl/repositories/olaaustine/GenCC/date[YYYY-MM-DD]")
args = ap.parse_args()

files = [f for f in os.listdir(args.path) if os.path.isfile(os.path.join(args.path, f))]

new_data = pd.DataFrame()
temp_df = []

outfile = args.path + "/final_file.txt"
final_file = args.path + "/gencc.txt"
for file in files:
    file_path = args.path + "/" + file
    df = pd.read_csv(file_path)
    if "Cardiac" in file_path: # because Cardiac only has disease ontology 
        df["disease mim"] = df["disease ontology"]
    else :
        df["disease mim"] =   "OMIM:" + df['disease mim'].astype(str)
    
    temp_df.append(df)

merged_df = pd.concat(temp_df, axis=0, ignore_index=True) #concat different dataframe with different lengths
merged_df.to_csv(outfile, index=False)

new_pd = pd.read_csv(outfile) # reading the already created entries of all our entroes 
confidence = new_pd['confidence category']
moi = new_pd['allelic requirement']

start_num =  1000112000 # the start num is our gencc number + 1 at the beginning and three zeros
size_g2p = len(new_pd) # length of the existing dataframe

#for the date column we always use the same date
#date = datetime.date.today()
#formatted_date = date.strftime("%Y/%m/%d")

# adding disease mim using ols for entries with no existing disease mim or disease ontology (non cardiac)
for index,row in new_pd.iterrows():
    if row["disease mim"] == "OMIM:No disease mim":
        # get the disease mondo name 
        disease_mondo = get_ols(row["disease name"])
        # using it to replace the No disease mim as we need the disease mim to submit and do not want to lose the data
        new_pd.replace(row["disease mim"], disease_mondo, inplace=True)
        #print(row["disease name"] + " " + row["disease mim"] )

file_df = pd.DataFrame()
file_df["submission_id"] = range(start_num, start_num+size_g2p) # Generating the sequence of numbers using the created start num and the end  being the start num + end 
file_df['hgnc id'] = "HGNC:" + new_pd['hgnc id'].astype(str)
file_df['hgnc_symbol'] = new_pd['gene symbol']
file_df['disease_id'] = new_pd['disease mim']
file_df['disease_name'] = new_pd['disease name']
file_df['submitter_id'] = "GENCC:000112"
#replace confidence catrgory and allelic_requirement using the GenCC submission criteria
file_df["classification_id"] = confidence.replace(con_category)
file_df['moi_id'] = moi.replace(allelic_requirement)
file_df['submitter_name'] = "TGMI G2P"
file_df['pmid'] = new_pd['pmids']
file_df["date"] = new_pd['gene disease pair entry date']
file_df['assertion_criteria_url'] = "https://www.ebi.ac.uk/gene2phenotype/terminology"
    

file_df.to_csv(final_file, mode='w', index=False)



