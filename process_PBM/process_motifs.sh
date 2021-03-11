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
mkdir -p ./release_6_motifs/Train_intensities/

cp ~/greco-data/release_6.2021-02-13/PBM.SDQN/Train_intensities/* ./release_6_motifs/Train_intensities/
cp ~/greco-data/release_6.2021-02-13/PBM.QNZS/Train_intensities/* ./release_6_motifs/Train_intensities/

CHIPS_SOURCE_FOLDER='./release_6_motifs/'
RESULTS_FOLDER='./release_6_motifs/'
#######

NUM_THREADS=24
CHIPMUNK_NUM_PROCESSES=12
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

ruby chip_sequences.rb \
        --source ${CHIPS_SOURCE_FOLDER}/Train_intensities \
        --destination ${RESULTS_FOLDER}/Train_sequences \
        --linker-length 0 \
        --fasta  --take-top 1000


./calculate_motifs.sh --source ${RESULTS_FOLDER}/Train_sequences \
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
              --words-destination ${RESULTS_FOLDER}/words \
              --motif-id-suffix s_8-15_flat

./generate_logo.sh --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/logo
./generate_dilogo.sh --source ${RESULTS_FOLDER}/dpcms --destination ${RESULTS_FOLDER}/dilogo

./convert_pcm2pfm.sh  --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/pfms
