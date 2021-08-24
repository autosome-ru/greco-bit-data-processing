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

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

CHIPS_SOURCE_FOLDER='./release_6_motifs/'
RESULTS_FOLDER='./release_6_motifs/'

#######

NUM_THREADS=24
CHIPMUNK_NUM_PROCESSES=12
CHIPMUNK_NUM_INNER_THREADS=2
CHIPMUNK_LENGTH_RANGE="6 16"
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

# # Copy source data
# mkdir -p "${CHIPS_SOURCE_FOLDER}/Train_intensities/"
# for PROCESSING_TYPE in SDQN QNZS; do
#     cp "~/greco-data/release_6.2021-02-13/PBM.${PROCESSING_TYPE}/Train_intensities/*" "${CHIPS_SOURCE_FOLDER}/Train_intensities/"
# done


ruby ${SCRIPT_FOLDER}/chip_sequences.rb \
        --source ${CHIPS_SOURCE_FOLDER}/Train_intensities \
        --destination ${RESULTS_FOLDER}/Train_sequences \
        --linker-length 0 \
        --fasta  --take-top 1000


${SCRIPT_FOLDER}/calculate_motifs.sh --source ${RESULTS_FOLDER}/Train_sequences \
                  --results-destination ${RESULTS_FOLDER}/chipmunk_results \
                  --logs-destination ${RESULTS_FOLDER}/chipmunk_logs \
                  --num-inner-threads ${CHIPMUNK_NUM_INNER_THREADS} \
                  --num-processes ${CHIPMUNK_NUM_PROCESSES} \
                  --length-range ${CHIPMUNK_LENGTH_RANGE} \
                  --shape ${CHIPMUNK_SHAPE} \
                  --weighting-mode ${CHIPMUNK_WEIGHTING_MODE} \
                  --additional-options "${CHIPMUNK_ADDITIONAL_OPTIONS}"

${SCRIPT_FOLDER}/extract_pcms.sh --source ${RESULTS_FOLDER}/chipmunk_results \
              --pcms-destination ${RESULTS_FOLDER}/pcms \
              --dpcms-destination ${RESULTS_FOLDER}/dpcms \
              --words-destination ${RESULTS_FOLDER}/words \
              --motif-id-suffix s_6-16_flat

${SCRIPT_FOLDER}/generate_logo.sh --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/logo
${SCRIPT_FOLDER}/generate_dilogo.sh --source ${RESULTS_FOLDER}/dpcms --destination ${RESULTS_FOLDER}/dilogo

${SCRIPT_FOLDER}/convert_pcm2pfm.sh  --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/pfms
