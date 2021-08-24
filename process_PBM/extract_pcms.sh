#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

CHIPMUNK_ARITY="di"
MOTIF_ID_SUFFIX="" # common suffix for all motifs in a batch
while true; do
    case "${1-}" in
        --source)
            SOURCE_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --pcms-destination)
            PCMS_DESTINATION_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --dpcms-destination)
            DPCMS_DESTINATION_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --words-destination)
            WORDS_DESTINATION_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --motif-id-suffix)
            MOTIF_ID_SUFFIX="$2"
            shift
            ;;
        --mono-chipmunk)
            CHIPMUNK_ARITY="mono"
            ;;
        --di-chipmunk)
            CHIPMUNK_ARITY="di"
            ;;
        -?*)
            echo -e "WARN: Unknown option (ignored): $1\n" >&2
            ;;
        *)
            break
    esac
    shift
done


mkdir -p "${PCMS_DESTINATION_FOLDER}"
mkdir -p "${DPCMS_DESTINATION_FOLDER}"
mkdir -p "${WORDS_DESTINATION_FOLDER}"

for FN in $( find "${SOURCE_FOLDER}" -xtype f ); do
    BN=$(basename -s .txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/motif_name_pbm.rb --dataset "${BN}" --motif-id "${MOTIF_ID_SUFFIX}" --ext '' --team 'autosome-ru' --tool ChIPMunk )

    if [[ "${CHIPMUNK_ARITY}" == "mono" ]]; then
        # It's reserved for mono-chipmunk results
        ( echo ">${NEW_BN}"; cat "${SOURCE_FOLDER}/${BN}.txt"  \
          | grep -Pe '^[ACGT]\|'  \
          | sed -re 's/^[ACGT]\|//' \
        ) > "${PCMS_DESTINATION_FOLDER}/${NEW_BN}.pcm"
    elif [[ "${CHIPMUNK_ARITY}" == "di" ]]; then
        ( echo ">${NEW_BN}"; cat "${SOURCE_FOLDER}/${BN}.txt"  \
          | grep -Pe '^[ACGT][ACGT]\|'  \
          | sed -re 's/^[ACGT][ACGT]\|//' \
          | ruby -e 'readlines.map{|l| l.chomp.split }.transpose.each{|r| puts r.join("\t") }' \
        ) > "${DPCMS_DESTINATION_FOLDER}/${NEW_BN}.dpcm"

        cat "${SOURCE_FOLDER}/${BN}.txt"  \
          | grep -Pe '^WORD\|'  \
          | sed -re 's/^WORD\|//' \
          | ruby -e 'readlines.each{|l| word, weight = l.chomp.split("\t").values_at(2, 5); puts(">#{weight}"); puts(word) }' \
          > "${WORDS_DESTINATION_FOLDER}/${NEW_BN}.fa"

        ( echo ">${NEW_BN}"; cat "${WORDS_DESTINATION_FOLDER}/${NEW_BN}.fa" \
          | ruby ${SCRIPT_FOLDER}/fasta2pcm.rb --weighted \
        ) > "${PCMS_DESTINATION_FOLDER}/${NEW_BN}.pcm"
    else
        echo "Unknown ChIPMunk arity. Should be 'mono' or 'di'" >&2
        exit 1
    fi
done
