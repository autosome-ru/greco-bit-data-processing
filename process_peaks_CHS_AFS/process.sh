#!/usr/bin/env bash
set -euo pipefail

# wget https://github.com/arq5x/bedtools2/releases/download/v2.29.2/bedtools-2.29.2.tar.gz
# tar -zxf bedtools-2.29.2.tar.gz && rm bedtools-2.29.2.tar.gz
# cd bedtools2/ && make && cd .. && ln -s bedtools2/bin/bedtools bedtools

SOURCE_FOLDER="./source_data/affiseq"
RESULTS_FOLDER="./results/affiseq"
# ln -s /home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval "${SOURCE_FOLDER}/peaks-intervals"

mkdir -p "${RESULTS_FOLDER}"
cat "${SOURCE_FOLDER}/metrics_by_exp.tsv" | tail -n+2 | cut -d $'\t' -f2,4 | awk -F $'\t' -e '$1 != "CONTROL" && $1 != ""' > "${RESULTS_FOLDER}/tf_peaks.txt"

ruby prepare_peaks.rb ./source_data/affiseq ./results/affiseq
