#!/usr/bin/env bash
set -euo pipefail

CHIPS_SOURCE_FOLDER=./data/RawData
NUM_THREADS=20
NORMALIZATION_OPTS='--log10'


INTERMEDIATE_FOLDER='results_databox_intermediate'
RESULTS_FOLDER='results_databox'

ruby rename_chips.rb \
     --source ${CHIPS_SOURCE_FOLDER} \
     --destination ${INTERMEDIATE_FOLDER}/raw_intensities/ \
     --tf-mapping 'tf_name_mapping.txt'

## sd_qn_intensities
# window-size=5 means window 11x11
./spatial_detrending.sh --source ${INTERMEDIATE_FOLDER}/raw_intensities/ \
                        --destination ${INTERMEDIATE_FOLDER}/spatial_detrended_intensities/ \
                        --window-size 5 \
                        --num-threads ${NUM_THREADS}

ruby quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${INTERMEDIATE_FOLDER}/spatial_detrended_intensities/ \
        --destination ${INTERMEDIATE_FOLDER}/sd_qn_intensities

## qn_zscore_intensities
ruby quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${INTERMEDIATE_FOLDER}/raw_intensities/ \
        --destination ${INTERMEDIATE_FOLDER}/quantile_normalized_intensities

ruby zscore_transform_chips.rb \
        --source ${INTERMEDIATE_FOLDER}/quantile_normalized_intensities \
        --destination ${INTERMEDIATE_FOLDER}/qn_zscore_intensities

#########

mkdir -p ${RESULTS_FOLDER}/raw/train_intensities  ${RESULTS_FOLDER}/raw/validation_intensities
mkdir -p ${RESULTS_FOLDER}/spatialDetrend_quantNorm/train_intensities  ${RESULTS_FOLDER}/spatialDetrend_quantNorm/validation_intensities 
mkdir -p ${RESULTS_FOLDER}/quantNorm_zscore/train_intensities  ${RESULTS_FOLDER}/quantNorm_zscore/validation_intensities

# raw
for FN in $(find ${INTERMEDIATE_FOLDER}/raw_intensities/ -xtype f -name '*_1M-ME_*'); do
    BN=$(basename -s .txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/raw/train_intensities/${BN}.train.txt
done

for FN in $(find ${INTERMEDIATE_FOLDER}/raw_intensities/ -xtype f -name '*_1M-HK_*'); do
    BN=$(basename -s .txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/raw/validation_intensities/${BN}.val.txt
done

# sd_qn
for FN in $(find ${INTERMEDIATE_FOLDER}/sd_qn_intensities/ -xtype f -name '*_1M-ME_*'); do
    BN=$(basename -s .txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/spatialDetrend_quantNorm/train_intensities/${BN}.train.txt
done

for FN in $(find ${INTERMEDIATE_FOLDER}/sd_qn_intensities/ -xtype f -name '*_1M-HK_*'); do
    BN=$(basename -s .txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/spatialDetrend_quantNorm/validation_intensities/${BN}.val.txt
done

# qn_zscore
for FN in $(find ${INTERMEDIATE_FOLDER}/qn_zscore_intensities/ -xtype f -name '*_1M-ME_*'); do
    BN=$(basename -s .txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/quantNorm_zscore/train_intensities/${BN}.train.txt
done

for FN in $(find ${INTERMEDIATE_FOLDER}/qn_zscore_intensities/ -xtype f -name '*_1M-HK_*'); do
    BN=$(basename -s .txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/quantNorm_zscore/validation_intensities/${BN}.val.txt
done


for SUBFOLDER in raw  spatialDetrend_quantNorm  quantNorm_zscore; do
    ruby chip_sequences.rb \
            --source ${RESULTS_FOLDER}/${SUBFOLDER}/train_intensities \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/train_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000

    ruby chip_sequences.rb \
            --source ${RESULTS_FOLDER}/${SUBFOLDER}/validation_intensities \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/validation_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000
done
