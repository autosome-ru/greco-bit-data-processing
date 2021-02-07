#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

CHIPS_SOURCE_FOLDER=./data/RawData
NUM_THREADS=20
NORMALIZATION_OPTS='--log10'

INTERMEDIATE_FOLDER='results_databox_intermediate'
RESULTS_FOLDER='results_databox'

NAME_MAPPING='tf_name_mapping.txt' # use `--name_mapping no` to skip mapping

while true; do
    case "${1-}" in
        --source)
            CHIPS_SOURCE_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --destination)
            RESULTS_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --tmp)
            INTERMEDIATE_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --num-threads)
            NUM_THREADS="$2"
            shift
            ;;
        --name-mapping)
            if [[ "$2" == "no" ]]; then
                NAME_MAPPING="no"
            else
                NAME_MAPPING="$(readlink -m "$2")"
            fi
            shift
            ;;
        -?*)
            echo -e "WARN: Unknown option (ignored): $1\n" >&2
            ;;
        *)
            break
    esac
    shift
done

if [[ "$NAME_MAPPING" == "no" ]]; then
    ruby ${SCRIPT_FOLDER}/rename_chips.rb \
         --source ${CHIPS_SOURCE_FOLDER} \
         --destination ${INTERMEDIATE_FOLDER}/raw_intensities/ \
         --tf-mapping "${NAME_MAPPING}";
    CHIPS_SOURCE_FOLDER="${INTERMEDIATE_FOLDER}/raw_intensities/"
fi

## sd_qn_intensities
# window-size=5 means window 11x11
./spatial_detrending.sh --source ${CHIPS_SOURCE_FOLDER} \
                        --destination ${INTERMEDIATE_FOLDER}/spatial_detrended_intensities/ \
                        --window-size 5 \
                        --num-threads ${NUM_THREADS}

ruby ${SCRIPT_FOLDER}/quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${INTERMEDIATE_FOLDER}/spatial_detrended_intensities/ \
        --destination ${INTERMEDIATE_FOLDER}/sd_qn_intensities

## qn_zscore_intensities
ruby ${SCRIPT_FOLDER}/quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${CHIPS_SOURCE_FOLDER} \
        --destination ${INTERMEDIATE_FOLDER}/quantile_normalized_intensities

ruby ${SCRIPT_FOLDER}/zscore_transform_chips.rb \
        --source ${INTERMEDIATE_FOLDER}/quantile_normalized_intensities \
        --destination ${INTERMEDIATE_FOLDER}/qn_zscore_intensities

#########

mkdir -p ${RESULTS_FOLDER}/raw/train_intensities  ${RESULTS_FOLDER}/raw/validation_intensities
mkdir -p ${RESULTS_FOLDER}/spatialDetrend_quantNorm/train_intensities  ${RESULTS_FOLDER}/spatialDetrend_quantNorm/validation_intensities 
mkdir -p ${RESULTS_FOLDER}/quantNorm_zscore/train_intensities  ${RESULTS_FOLDER}/quantNorm_zscore/validation_intensities

# raw
for FN in $(find ${CHIPS_SOURCE_FOLDER} -xtype f -name '*_1M-ME_*'); do
    BN=$(basename -s .pbm.txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/raw/train_intensities/${BN}.raw.pbm.train.txt
done

for FN in $(find ${CHIPS_SOURCE_FOLDER} -xtype f -name '*_1M-HK_*'); do
    BN=$(basename -s .pbm.txt ${FN})
    cp ${FN} ${RESULTS_FOLDER}/raw/validation_intensities/${BN}.raw.pbm.val.txt
done

# sd_qn
for FN in $(find ${INTERMEDIATE_FOLDER}/sd_qn_intensities/ -xtype f -name '*_1M-ME_*'); do
    BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_samples.rb "$FN" --slice-type Train --extension tsv --processing-type SDQN )
    cp ${FN} ${RESULTS_FOLDER}/spatialDetrend_quantNorm/train_intensities/${BN}.spatialDetrend_quantNorm.pbm.train.txt
    cp ${FN} source_data_prepared/PBM.SDQN/train_intensities/${NEW_BN}
done

for FN in $(find ${INTERMEDIATE_FOLDER}/sd_qn_intensities/ -xtype f -name '*_1M-HK_*'); do
    BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_samples.rb "$FN" --slice-type Val --extension tsv --processing-type SDQN )
    cp ${FN} ${RESULTS_FOLDER}/spatialDetrend_quantNorm/validation_intensities/${BN}.spatialDetrend_quantNorm.pbm.val.txt
    cp ${FN} source_data_prepared/PBM.SDQN/validation_intensities/${NEW_BN}
done

# qn_zscore
for FN in $(find ${INTERMEDIATE_FOLDER}/qn_zscore_intensities/ -xtype f -name '*_1M-ME_*'); do
    BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_samples.rb "$FN" --slice-type Train --extension tsv --processing-type QNZS )
    cp ${FN} ${RESULTS_FOLDER}/quantNorm_zscore/train_intensities/${BN}.quantNorm_zscore.pbm.train.txt
    cp ${FN} source_data_prepared/PBM.QNZS/train_intensities/${NEW_BN}
done

for FN in $(find ${INTERMEDIATE_FOLDER}/qn_zscore_intensities/ -xtype f -name '*_1M-HK_*'); do
    BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_samples.rb "$FN" --slice-type Val --extension tsv --processing-type QNZS )
    cp ${FN} ${RESULTS_FOLDER}/quantNorm_zscore/validation_intensities/${BN}.quantNorm_zscore.pbm.val.txt
    cp ${FN} source_data_prepared/PBM.QNZS/validation_intensities/${NEW_BN}
done


for SUBFOLDER in raw  spatialDetrend_quantNorm  quantNorm_zscore; do
    ruby ${SCRIPT_FOLDER}/chip_sequences.rb \
            --source ${RESULTS_FOLDER}/${SUBFOLDER}/train_intensities \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/train_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000

    ruby ${SCRIPT_FOLDER}/chip_sequences.rb \
            --source ${RESULTS_FOLDER}/${SUBFOLDER}/validation_intensities \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/validation_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000
done

for PROCESSING_TYPE  in  SDQN  QNZS; do
    ruby ${SCRIPT_FOLDER}/chip_sequences.rb \
            --source source_data_prepared/PBM.${PROCESSING_TYPE}/train_intensities \
            --destination source_data_prepared/PBM.${PROCESSING_TYPE}/train_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000

    ruby ${SCRIPT_FOLDER}/chip_sequences.rb \
            --source source_data_prepared/PBM.${PROCESSING_TYPE}/validation_intensities \
            --destination source_data_prepared/PBM.${PROCESSING_TYPE}/validation_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000
done
