#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

while true; do
    case "${1-}" in
        --source)
            SOURCE_FOLDER="$2"
            shift
            ;;
        --destination)
            DESTINATION_FOLDER="$2"
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

mkdir -p "${DESTINATION_FOLDER}"

for FN in $( find "${SOURCE_FOLDER}" -xtype f ); do
  BN=$(basename -s .pcm ${FN})
  ruby ${SCRIPT_FOLDER}/pcm2pfm.rb ${SOURCE_FOLDER}/${BN}.pcm > ${DESTINATION_FOLDER}/${BN}.pfm
done
