#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

CHIPS_SOURCE_FOLDER=./data/RawData
NUM_THREADS=20
NORMALIZATION_OPTS='--log10'

INTERMEDIATE_FOLDER='results_databox_intermediate'
RESULTS_FOLDER='results_databox'

NAME_MAPPING='no' # 'tf_name_mapping.txt' # use `--name_mapping no` to skip mapping

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

if [[ "$NAME_MAPPING" != "no" ]]; then
    ruby ${SCRIPT_FOLDER}/rename_chips.rb \
         --source ${CHIPS_SOURCE_FOLDER} \
         --destination ${INTERMEDIATE_FOLDER}/raw_intensities/ \
         --tf-mapping "${NAME_MAPPING}";
    CHIPS_SOURCE_FOLDER="${INTERMEDIATE_FOLDER}/raw_intensities/"
fi

## SDQN_intensities
# window-size=5 means window 11x11
${SCRIPT_FOLDER}/spatial_detrending.sh --source ${CHIPS_SOURCE_FOLDER} \
                        --destination ${INTERMEDIATE_FOLDER}/spatial_detrended_intensities/ \
                        --window-size 5 \
                        --num-threads ${NUM_THREADS}

ruby ${SCRIPT_FOLDER}/quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${INTERMEDIATE_FOLDER}/spatial_detrended_intensities/ \
        --destination ${INTERMEDIATE_FOLDER}/SDQN_intensities

## QNZS_intensities
ruby ${SCRIPT_FOLDER}/quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${CHIPS_SOURCE_FOLDER} \
        --destination ${INTERMEDIATE_FOLDER}/quantile_normalized_intensities

ruby ${SCRIPT_FOLDER}/zscore_transform_chips.rb \
        --source ${INTERMEDIATE_FOLDER}/quantile_normalized_intensities \
        --destination ${INTERMEDIATE_FOLDER}/QNZS_intensities

#########

# mkdir -p ${RESULTS_FOLDER}/raw/Train_intensities  ${RESULTS_FOLDER}/raw/Val_intensities
# # raw
# for FN in $(find ${CHIPS_SOURCE_FOLDER} -xtype f -name '*_1M-ME_*'); do
#     BN=$(basename -s .pbm.txt ${FN})
#     cp ${FN} ${RESULTS_FOLDER}/raw/Train_intensities/${BN}.raw.pbm.train.txt
# done

# for FN in $(find ${CHIPS_SOURCE_FOLDER} -xtype f -name '*_1M-HK_*'); do
#     BN=$(basename -s .pbm.txt ${FN})
#     cp ${FN} ${RESULTS_FOLDER}/raw/Val_intensities/${BN}.raw.pbm.val.txt
# done

for PROCESSING_TYPE in SDQN QNZS; do
    mkdir -p source_data_prepared/PBM.${PROCESSING_TYPE}/Train_intensities  source_data_prepared/PBM.${PROCESSING_TYPE}/Val_intensities

    for SLICE_TYPE in Train Val; do
        for CHIP_TYPE in ME HK; do
            for FN in $(find ${INTERMEDIATE_FOLDER}/${PROCESSING_TYPE}_intensities/ -xtype f -name "*_1M-${CHIP_TYPE}_*"); do
                NEW_DIRNAME="source_data_prepared/PBM.${PROCESSING_TYPE}/${SLICE_TYPE}_intensities"
                NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_pbm.rb "$FN" --slice-type ${SLICE_TYPE} --extension tsv --processing-type ${PROCESSING_TYPE} --action find-or-generate --lookup-folder ${NEW_DIRNAME} )
                if [[ -n "$NEW_BN" ]]; then
                    if [[ -s "${NEW_DIRNAME}/${NEW_BN}" ]]; then # file exists and has a size greater than zero.
                        echo "${NEW_DIRNAME}/${NEW_BN} already exists" >&2
                    else
                        cp "${FN}" "${NEW_DIRNAME}/${NEW_BN}"
                    fi
                else
                    echo "Can't get filename for ${FN}. Probably no metadata supplied" >&2
                fi
            done
        done
    done

    for SLICE_TYPE in Train Val; do
        mkdir -p "source_data_prepared/PBM.${PROCESSING_TYPE}/${SLICE_TYPE}_sequences"

        for FN in $( find "source_data_prepared/PBM.${PROCESSING_TYPE}/${SLICE_TYPE}_intensities" -xtype f ); do
            NEW_DIRNAME="source_data_prepared/PBM.${PROCESSING_TYPE}/${SLICE_TYPE}_sequences"
            NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_pbm.rb "$FN" \
                            --source-mode normalized --slice-type ${SLICE_TYPE} \
                            --extension fa --processing-type ${PROCESSING_TYPE} ); \
            if [[ -n "$NEW_BN" ]]; then
                if [[ -s "${NEW_DIRNAME}/${NEW_BN}" ]]; then # file exists and has a size greater than zero.
                    echo "${NEW_DIRNAME}/${NEW_BN} already exists"  >&2
                else
                    ruby ${SCRIPT_FOLDER}/single_chip_sequences.rb \
                            --linker-length 0 \
                            --fasta  --take-top 1000 \
                            ${FN}
                        > "${NEW_DIRNAME}/${NEW_BN}";
                fi
            else
                echo "Can't get sequence filename for ${FN}" >&2
            fi
        done
    done
done
