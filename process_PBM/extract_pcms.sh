#!/usr/bin/env bash
set -euo pipefail

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

  # # It's reserved for mono-chipmunk results
  # cat "${SOURCE_FOLDER}/${BN}.txt"  \
  #   | grep -Pe '^[ACGT]\|'  \
  #   | sed -re 's/^[ACGT]\|//' \
  #   > "${PCMS_DESTINATION_FOLDER}/${BN}.pcm"

  cat "${SOURCE_FOLDER}/${BN}.txt"  \
    | grep -Pe '^[ACGT][ACGT]\|'  \
    | sed -re 's/^[ACGT][ACGT]\|//' \
    | ruby -e 'readlines.map{|l| l.chomp.split }.transpose.each{|r| puts r.join("\t") }' \
    > "${DPCMS_DESTINATION_FOLDER}/${BN}.dpcm"

  cat "${SOURCE_FOLDER}/${BN}.txt"  \
    | grep -Pe '^WORD\|'  \
    | sed -re 's/^WORD\|//' \
    | ruby -e 'readlines.each{|l| word, weight = l.chomp.split("\t").values_at(2, 5); puts(">#{weight}"); puts(word) }' \
    > "${WORDS_DESTINATION_FOLDER}/${BN}.fa"

  cat "${WORDS_DESTINATION_FOLDER}/${BN}.fa" | ruby fasta2pcm.rb --weighted > "${PCMS_DESTINATION_FOLDER}/${BN}.pcm"
done
