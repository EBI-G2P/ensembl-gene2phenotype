#!/usr/bin/bash

root_directory=$1
current_date=$(date +'%Y-%m-%d')

final_directory="$root_directory/$current_date"
if [ ! -d "$final_directory" ];
then
    mkdir -m 777 $final_directory
fi

links=("https://www.ebi.ac.uk/gene2phenotype/downloads/CancerG2P.csv.gz"
       "https://www.ebi.ac.uk/gene2phenotype/downloads/CardiacG2P.csv.gz"
       "https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz"
       "https://www.ebi.ac.uk/gene2phenotype/downloads/EyeG2P.csv.gz"
       "https://www.ebi.ac.uk/gene2phenotype/downloads/SkinG2P.csv.gz"
       "https://www.ebi.ac.uk/gene2phenotype/downloads/SkeletalG2P.csv.gz"
       "https://www.ebi.ac.uk/gene2phenotype/downloads/Hearing_lossG2P.csv.gz")

for str in ${links[@]}; do
 file=${str##*/} # to get the basename of the url
 final_file="${current_date}_${file}"
 wget -q $str -O $final_directory/$final_file
done 

file_to_check="${current_date}_DDG2P.csv.gz"

if [ -f $file_to_check ]; then 
    echo "The file's directory is in $final_directory"

fi