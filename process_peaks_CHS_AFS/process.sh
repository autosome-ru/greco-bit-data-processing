#!/usr/bin/env bash
set -euo pipefail

NUM_PROCESSES=2
LENGTH_RANGE="8 15"
WEIGHTING_MODE="m" # peak summit
NUM_INNER_THREADS=2
SHAPE="flat"
ADDITIONAL_OPTIONS=""

# wget https://github.com/arq5x/bedtools2/releases/download/v2.29.2/bedtools-2.29.2.tar.gz
# tar -zxf bedtools-2.29.2.tar.gz && rm bedtools-2.29.2.tar.gz
# cd bedtools2/ && make && cd .. && ln -s bedtools2/bin/bedtools bedtools

SOURCE_FOLDER="./source_data/affiseq"
RESULTS_FOLDER="./results/affiseq"
# ln -s /home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval "${SOURCE_FOLDER}/peaks-intervals"
# ln -s ~/iogen/data/genome/hg38.fa ./source_data/hg38.fa

mkdir -p "${RESULTS_FOLDER}"
cat "${SOURCE_FOLDER}/metrics_by_exp.tsv" | tail -n+2 | cut -d $'\t' -f2,4 | awk -F $'\t' -e '$1 != "CONTROL" && $1 != ""' > "${RESULTS_FOLDER}/tf_peaks.txt"

ruby prepare_peaks.rb ./source_data/affiseq ./results/affiseq

mkdir -p results/affiseq/train/sequences/
for FN in $(find results/affiseq/train/tf_peaks/ -xtype f); do
  TF="$(basename -s .train.interval "$FN")"
  ./bedtools getfasta -fi ./source_data/hg38.fa -bed ${FN} -name | ruby fixup_summit.rb > results/affiseq/train/sequences/${TF}.fa
done

CHIPMUNK_RESULTS_DESTINATION_FOLDER="./results/affiseq/chipmunk_results/"
CHIPMUNK_LOGS_DESTINATION_FOLDER="./results/affiseq/chipmunk_logs/"
mkdir -p ${CHIPMUNK_RESULTS_DESTINATION_FOLDER} ${CHIPMUNK_LOGS_DESTINATION_FOLDER}
for FN in $(find results/affiseq/train/sequences/ -xtype f); do
  TF="$(basename -s .fa "$FN")"
  echo "java -cp chipmunk.jar ru.autosome.di.ChIPMunk" \
      "${LENGTH_RANGE} y 1.0 ${WEIGHTING_MODE}:${FN} 400 40 1 ${NUM_INNER_THREADS} random auto ${SHAPE} ${ADDITIONAL_OPTIONS}" \
      "> ${CHIPMUNK_RESULTS_DESTINATION_FOLDER}/${TF}.txt" \
      "2> ${CHIPMUNK_LOGS_DESTINATION_FOLDER}/${TF}.log"
done | parallel -j ${NUM_PROCESSES}

PCMS_FOLDER="./results/affiseq/pcms/"
DPCMS_FOLDER="./results/affiseq/dpcms/"
WORDS_FOLDER="./results/affiseq/words/"
LOGO_FOLDER="./results/affiseq/logo/"

./extract_pcms.sh --source ${CHIPMUNK_RESULTS_DESTINATION_FOLDER} --dpcms-destination ${DPCMS_FOLDER} --pcms-destination ${PCMS_FOLDER} --words-destination ${WORDS_FOLDER}
./generate_logo.sh --source ${PCMS_FOLDER} --destination ${LOGO_FOLDER}
