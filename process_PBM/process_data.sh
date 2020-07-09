#!/usr/bin/env bash
set -euo pipefail

CHIPS_SOURCE_FOLDER=source_data
NUM_THREADS=20
NORMALIZATION_OPTS='--log10'


INTERMEDIATE_FOLDER='results_databox_intermediate'
RESULTS_FOLDER='results_databox'

mkdir -p ${INTERMEDIATE_FOLDER}/raw_chips/
cp ${CHIPS_SOURCE_FOLDER}/*.txt ${INTERMEDIATE_FOLDER}/raw_chips/

## sd_qn_chips
./spatial_detrending.sh --source ${INTERMEDIATE_FOLDER}/raw_chips/ \
                        --destination ${INTERMEDIATE_FOLDER}/spatial_detrended_chips/ \
                        --window-size 5 \
                        --num-threads ${NUM_THREADS}

ruby quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${INTERMEDIATE_FOLDER}/spatial_detrended_chips/ \
        --destination ${INTERMEDIATE_FOLDER}/sd_qn_chips

## qn_zscore_chips
ruby quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${INTERMEDIATE_FOLDER}/raw_chips/ \
        --destination ${INTERMEDIATE_FOLDER}/quantile_normalized_chips

ruby zscore_transform_chips.rb \
        --source ${INTERMEDIATE_FOLDER}/quantile_normalized_chips \
        --destination ${INTERMEDIATE_FOLDER}/qn_zscore_chips

#########

mkdir -p ${RESULTS_FOLDER}/raw/train_chips  ${RESULTS_FOLDER}/raw/validation_chips
mkdir -p ${RESULTS_FOLDER}/spatialDetrend_quantNorm/train_chips  ${RESULTS_FOLDER}/spatialDetrend_quantNorm/validation_chips 
mkdir -p ${RESULTS_FOLDER}/quantNorm_zscore/train_chips  ${RESULTS_FOLDER}/quantNorm_zscore/validation_chips

cp ${INTERMEDIATE_FOLDER}/raw_chips/*_1M-ME_*  ${RESULTS_FOLDER}/raw/train_chips
cp ${INTERMEDIATE_FOLDER}/raw_chips/*_1M-HK_*  ${RESULTS_FOLDER}/raw/validation_chips

cp ${INTERMEDIATE_FOLDER}/sd_qn_chips/*_1M-ME_*  ${RESULTS_FOLDER}/spatialDetrend_quantNorm/train_chips
cp ${INTERMEDIATE_FOLDER}/sd_qn_chips/*_1M-HK_*  ${RESULTS_FOLDER}/spatialDetrend_quantNorm/validation_chips

cp ${INTERMEDIATE_FOLDER}/qn_zscore_chips/*_1M-ME_*  ${RESULTS_FOLDER}/quantNorm_zscore/train_chips
cp ${INTERMEDIATE_FOLDER}/qn_zscore_chips/*_1M-HK_*  ${RESULTS_FOLDER}/quantNorm_zscore/validation_chips

for SUBFOLDER in raw  spatialDetrend_quantNorm  quantNorm_zscore; do
    ruby chip_sequences.rb \
            --source ${RESULTS_FOLDER}/${SUBFOLDER}/train_chips \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/train_sequences \
            --linker-length 0 \
            --fasta

    ruby chip_sequences.rb \
            --source ${RESULTS_FOLDER}/${SUBFOLDER}/validation_chips \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/validation_sequences \
            --linker-length 0 \
            --fasta
done
