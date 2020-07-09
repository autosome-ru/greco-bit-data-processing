#!/usr/bin/env bash
set -eu
#set -o pipefail

NUM_PROCESSES=12

# wget https://github.com/arq5x/bedtools2/releases/download/v2.29.2/bedtools-2.29.2.tar.gz
# tar -zxf bedtools-2.29.2.tar.gz && rm bedtools-2.29.2.tar.gz
# cd bedtools2/ && make && cd .. && ln -s bedtools2/bin/bedtools bedtools

# mkdir -p affiseq/source_data  chipseq/source_data
# ln -s /home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval "affiseq/source_data/peaks-intervals"
# ln -s /home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval "chipseq/source_data/peaks-intervals"

# ln -s ~/iogen/data/genome/hg38.fa ./source_data/hg38.fa
## Generate index
# echo | ./bedtools getfasta -fi source_data/hg38.fa -bed -

for DATA_TYPE in affiseq chipseq; do
    SOURCE_FOLDER="./${DATA_TYPE}/source_data"
    RESULTS_FOLDER="./${DATA_TYPE}/results"

    mkdir -p "${RESULTS_FOLDER}"

    ruby prepare_peaks_${DATA_TYPE}.rb ${SOURCE_FOLDER} ${RESULTS_FOLDER}

    mkdir -p ${DATA_TYPE}/results/train_sequences/
    for FN in $(find ${DATA_TYPE}/results/train_intervals/ -xtype f); do
      TF="$(basename -s .interval "$FN")"
      cat ${FN} | tail -n+2 | sort -k5,5nr | head -500 | ./bedtools getfasta -fi ./source_data/hg38.fa -bed - > ${DATA_TYPE}/results/train_sequences/${TF}.fa
    done

    mkdir -p ${DATA_TYPE}/results/validation_sequences/
    for FN in $(find ${DATA_TYPE}/results/validation_intervals/ -xtype f); do
      TF="$(basename -s .interval "$FN")"
      cat ${FN} | tail -n+2 | sort -k5,5nr | head -500 | ./bedtools getfasta -fi ./source_data/hg38.fa -bed - > ${DATA_TYPE}/results/validation_sequences/${TF}.fa
    done
done
