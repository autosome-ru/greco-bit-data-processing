#!/usr/bin/env bash
set -euo pipefail

# # Where to install R packages
# mkdir -p ~/.R_libs
# export R_LIBS_USER=~/.R_libs
#
# # Install requirements
# # For R
# ./requirements.R
#
# # For ruby
# bundle install
#

# CHIPS_SOURCE_FOLDER=./data/RawData
# RESULTS_FOLDER=./results

# TOP_OPTS='--max-head-size 1000'
# TOP_OPTS='--quantile 0.01'
TOP_OPTS='--quantile 0.05'

#NORMALIZATION_OPTS='--log10-bg'
NORMALIZATION_OPTS='--log10'

NUM_THREADS=1
CHIPMUNK_NUM_PROCESSES=1
CHIPMUNK_NUM_INNER_THREADS=2
CHIPMUNK_LENGTH_RANGE="8 15"
CHIPMUNK_SHAPE="flat"
CHIPMUNK_WEIGHTING_MODE="s"
CHIPMUNK_ADDITIONAL_OPTIONS=""

while true; do
    case "${1-}" in
        --source)
            CHIPS_SOURCE_FOLDER="$2"
            shift
            ;;
        --destination)
            RESULTS_FOLDER="$2"
            shift
            ;;
        --normalization-opts)
            NORMALIZATION_OPTS="$2"
            shift
            ;;
        --extract-top-opts)
            TOP_OPTS="$2"
            shift
            ;;
        --num-threads)
            NUM_THREADS="$2"
            shift
            ;;
        --chipmunk-num-processes)
            CHIPMUNK_NUM_PROCESSES="$2"
            shift
            ;;
        --chipmunk-num-inner-threads)
            CHIPMUNK_NUM_INNER_THREADS="$2"
            shift
            ;;
        --chipmunk-length-range)
            CHIPMUNK_LENGTH_RANGE="$2 $3"
            shift 2
            ;;
        --chipmunk-shape)
            CHIPMUNK_SHAPE="$2"
            shift
            ;;
        --chipmunk-weighting-mode)
            CHIPMUNK_WEIGHTING_MODE="$2"
            shift
            ;;
        --chipmunk-additional-options)
            CHIPMUNK_ADDITIONAL_OPTIONS="$2"
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

mkdir -p ${RESULTS_FOLDER}/raw_chips/
cp ${CHIPS_SOURCE_FOLDER}/*.txt ${RESULTS_FOLDER}/raw_chips/

./spatial_detrending.sh --source ${RESULTS_FOLDER}/raw_chips/ \
                        --destination ${RESULTS_FOLDER}/spatial_detrended_chips/ \
                        --window-size 5 \
                        --num-threads ${NUM_THREADS}

ruby quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${RESULTS_FOLDER}/raw_chips/ \
        --destination ${RESULTS_FOLDER}/quantile_normalized_chips

ruby zscore_transform_chips.rb \
        --source ${RESULTS_FOLDER}/quantile_normalized_chips \
        --destination ${RESULTS_FOLDER}/zscored_chips

ruby chip_sequences.rb \
        --source ${RESULTS_FOLDER}/zscored_chips \
        --destination ${RESULTS_FOLDER}/zscored_seqs \
        --linker-length 0


ruby top_seqs_fasta.rb ${TOP_OPTS} --source ${RESULTS_FOLDER}/zscored_seqs --destination ${RESULTS_FOLDER}/top_seqs_fasta

./calculate_motifs.sh --source ${RESULTS_FOLDER}/top_seqs_fasta \
                      --results-destination ${RESULTS_FOLDER}/chipmunk_results \
                      --logs-destination ${RESULTS_FOLDER}/chipmunk_logs \
                      --num-inner-threads ${CHIPMUNK_NUM_INNER_THREADS} \
                      --num-processes ${CHIPMUNK_NUM_PROCESSES} \
                      --length-range ${CHIPMUNK_LENGTH_RANGE} \
                      --shape ${CHIPMUNK_SHAPE} \
                      --weighting-mode ${CHIPMUNK_WEIGHTING_MODE} \
                      --additional-options "${CHIPMUNK_ADDITIONAL_OPTIONS}"

./extract_pcms.sh --source ${RESULTS_FOLDER}/chipmunk_results \
                  --pcms-destination ${RESULTS_FOLDER}/pcms \
                  --dpcms-destination ${RESULTS_FOLDER}/dpcms \
                  --words-destination ${RESULTS_FOLDER}/words


./generate_logo.sh --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/logo
./generate_dilogo.sh --source ${RESULTS_FOLDER}/dpcms --destination ${RESULTS_FOLDER}/dilogo

./convert_pcm2pfm.sh  --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/pfms

for CHIP_STAGE in raw_chips quantile_normalized_chips zscored_chips spatial_detrended_chips; do
    for METRICS in ASIS EXP LOG ROC PR ROCLOG PRLOG ; do
        mkdir -p ${RESULTS_FOLDER}/motif_metrics/${CHIP_STAGE}
        echo "./motif_metrics.sh  " \
                    "--metrics ${METRICS}" \
                    "--linker-opts '--linker-length 6'" \
                    "--chips-source ${RESULTS_FOLDER}/${CHIP_STAGE}/" \
                    "--motifs-source ${RESULTS_FOLDER}/pfms" \
            "> ${RESULTS_FOLDER}/motif_metrics/${CHIP_STAGE}/motif_metrics_${METRICS}.tsv"
    done
done | parallel -j ${NUM_THREADS}

for CHIP_STAGE in raw_chips quantile_normalized_chips zscored_chips spatial_detrended_chips; do
    for METRICS in ASIS EXP LOG ROC PR ROCLOG PRLOG ; do
        # It will recreate existing docs with correlations appended
        ruby generate_summary.rb  --sequences-source  ${RESULTS_FOLDER}/zscored_seqs \
                                  --motif_metrics ${RESULTS_FOLDER}/motif_metrics/${CHIP_STAGE}/motif_metrics_${METRICS}.tsv \
                                  --html-destination ${RESULTS_FOLDER}/summary_${METRICS}_${CHIP_STAGE}.html \
                                  --tsv-destination ${RESULTS_FOLDER}/summary_${METRICS}_${CHIP_STAGE}.tsv \
                                  --web-sources-url ../websrc
    done
done

ruby organize_results.rb --chips-source ${RESULTS_FOLDER}/raw_chips/ --results-source ${RESULTS_FOLDER} --destination ${RESULTS_FOLDER}/factors
