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

###########3
# CHIPS_SOURCE_FOLDER=./data/RawData
# RESULTS_FOLDER=./results

# CHIPS_SOURCE_FOLDER='./release_2_motifs/'
# RESULTS_FOLDER='./release_2_motifs/results_top1000_15-8_single_log_simple_flag/'

# cp ~/greco-data/release_4.2020-11-26/pbm/quantNorm_zscore/ ./release_4_motifs/ -r
# cp ~/greco-data/release_4.2020-11-26/pbm/spatialDetrend_quantNorm/ ./release_4_motifs/ -r
CHIPS_SOURCE_FOLDER='./release_4_motifs/'
RESULTS_FOLDER='./release_4_motifs/'
#######

# TOP_OPTS='--max-head-size 1000'
# TOP_OPTS='--quantile 0.01'
TOP_OPTS='--quantile 0.05'

#NORMALIZATION_OPTS='--log10-bg'
NORMALIZATION_OPTS='--log10'

NUM_THREADS=24
CHIPMUNK_NUM_PROCESSES=12
CHIPMUNK_NUM_INNER_THREADS=2
CHIPMUNK_LENGTH_RANGE="8 15"
CHIPMUNK_SHAPE="flat"
CHIPMUNK_WEIGHTING_MODE="s"
CHIPMUNK_ADDITIONAL_OPTIONS=""

while true; do
    case "${1-}" in
#        --source)
#            CHIPS_SOURCE_FOLDER="$2"
#            shift
#            ;;
#        --destination)
#            RESULTS_FOLDER="$2"
#            shift
#            ;;
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

mkdir -p ./resulting_pcms

SUBFOLDERS="spatialDetrend_quantNorm  quantNorm_zscore"

for SUBFOLDER in $SUBFOLDERS; do
    ruby chip_sequences.rb \
            --source ${CHIPS_SOURCE_FOLDER}/${SUBFOLDER}/train_intensities \
            --destination ${RESULTS_FOLDER}/${SUBFOLDER}/train_sequences \
            --linker-length 0 \
            --fasta  --take-top 1000


    ./calculate_motifs.sh --source ${RESULTS_FOLDER}/${SUBFOLDER}/train_sequences \
                      --results-destination ${RESULTS_FOLDER}/${SUBFOLDER}/chipmunk_results \
                      --logs-destination ${RESULTS_FOLDER}/${SUBFOLDER}/chipmunk_logs \
                      --num-inner-threads ${CHIPMUNK_NUM_INNER_THREADS} \
                      --num-processes ${CHIPMUNK_NUM_PROCESSES} \
                      --length-range ${CHIPMUNK_LENGTH_RANGE} \
                      --shape ${CHIPMUNK_SHAPE} \
                      --weighting-mode ${CHIPMUNK_WEIGHTING_MODE} \
                      --additional-options "${CHIPMUNK_ADDITIONAL_OPTIONS}"

    ./extract_pcms.sh --source ${RESULTS_FOLDER}/${SUBFOLDER}/chipmunk_results \
                  --pcms-destination ${RESULTS_FOLDER}/${SUBFOLDER}/pcms \
                  --dpcms-destination ${RESULTS_FOLDER}/${SUBFOLDER}/dpcms \
                  --words-destination ${RESULTS_FOLDER}/${SUBFOLDER}/words \
                  --suffix .chipmunk.model1

    ./generate_logo.sh --source ${RESULTS_FOLDER}/${SUBFOLDER}/pcms --destination ${RESULTS_FOLDER}/${SUBFOLDER}/logo
    ./generate_dilogo.sh --source ${RESULTS_FOLDER}/${SUBFOLDER}/dpcms --destination ${RESULTS_FOLDER}/${SUBFOLDER}/dilogo

    ./convert_pcm2pfm.sh  --source ${RESULTS_FOLDER}/${SUBFOLDER}/pcms --destination ${RESULTS_FOLDER}/${SUBFOLDER}/pfms

    cp ${RESULTS_FOLDER}/${SUBFOLDER}/pcms/* ./resulting_pcms
done

ruby generate_short_summary.rb  $( for SF in $SUBFOLDERS; do echo -n --logo-source  ${RESULTS_FOLDER}/${SF}/logo " "; done ) \
                                --html-destination ${RESULTS_FOLDER}/results.html \
                                --tsv-destination ${RESULTS_FOLDER}/results.tsv \
                                --web-sources-url ../websrc


#for SUBFOLDER in spatialDetrend_quantNorm  quantNorm_zscore; do
#    for METRICS in ASIS EXP LOG ROC PR ROCLOG PRLOG ; do
#    mkdir -p ${RESULTS_FOLDER}/${SUBFOLDER}/motif_metrics
#        echo "./motif_metrics.sh  " \
#                "--metrics ${METRICS}" \
#                "--linker-opts '--linker-length 6'" \
#                "--chips-source ${RESULTS_FOLDER}/${SUBFOLDER}/" \
#                "--motifs-source ${RESULTS_FOLDER}/pfms" \
#        "> ${RESULTS_FOLDER}/${SUBFOLDER}/motif_metrics/motif_metrics_${METRICS}.tsv"
#    done
#done | parallel -j ${NUM_THREADS}


#ruby organize_results.rb --chips-source ${RESULTS_FOLDER}/raw_chips/ --results-source ${RESULTS_FOLDER} --destination ${RESULTS_FOLDER}/factors
