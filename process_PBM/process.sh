#!/usr/bin/env bash
set -euo pipefail

# CHIPS_SOURCE_FOLDER=./data/RawData
# RESULTS_FOLDER=./results

# TOP_OPTS='--max-head-size 1000'
# TOP_OPTS='--quantile 0.01'
TOP_OPTS='--quantile 0.05'

#NORMALIZATION_OPTS='--log10-bg'
NORMALIZATION_OPTS='--log10'

CHIPMUNK_NUM_PROCESSES=1
CHIPMUNK_NUM_INNER_THREADS=2
CHIPMUNK_LENGTH_RANGE="8 15"
CHIPMUNK_SHAPE="simple"
CHIPMUNK_WEIGHTING_MODE="s"
CHIPMUNK_ADDITIONAL_OPTIONS=""

while true; do
    case "$1" in
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


# ln -Tfs "$(readlink -e websrc)" ${RESULTS_FOLDER}/websrc



ruby quantile_normalize_chips.rb \
        ${NORMALIZATION_OPTS} \
        --source ${CHIPS_SOURCE_FOLDER} \
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
                      --additional-options ${CHIPMUNK_ADDITIONAL_OPTIONS}

./extract_pcms.sh --source ${RESULTS_FOLDER}/chipmunk_results \
                  --pcms-destination ${RESULTS_FOLDER}/pcms \
                  --dpcms-destination ${RESULTS_FOLDER}/dpcms \
                  --words-destination ${RESULTS_FOLDER}/words

./generate_logo.sh --source ${RESULTS_FOLDER}/pcms --destination ${RESULTS_FOLDER}/logo
./generate_dilogo.sh --source ${RESULTS_FOLDER}/dpcms --destination ${RESULTS_FOLDER}/dilogo

./calculate_correlations.sh --mode LOG \
                            --chips-source ${CHIPS_SOURCE_FOLDER} \
                            --motifs-source ${RESULTS_FOLDER}/pcms \
                            > ${RESULTS_FOLDER}/motif_qualities.tsv

# It will recreate existing docs with correlations appended
ruby generate_summary.rb  --sequences-source  ${RESULTS_FOLDER}/zscored_seqs \
                          --motif_qualities ${RESULTS_FOLDER}/motif_qualities.tsv \
                          --html-destination ${RESULTS_FOLDER}/head_sizes.html \
                          --tsv-destination ${RESULTS_FOLDER}/head_sizes.tsv \
                          --web-sources-url ../websrc

ruby organize_results.rb --chips-source ${CHIPS_SOURCE_FOLDER} --results-source ${RESULTS_FOLDER} --destination ${RESULTS_FOLDER}/factors
