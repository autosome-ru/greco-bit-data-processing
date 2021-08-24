#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

while true; do
    case "${1-}" in
        --source)
            SOURCE_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --destination)
            DESTINATION_FOLDER="$(readlink -m "$2")"
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
  BN=$(basename -s .dpcm ${FN})
  ruby ${SCRIPT_FOLDER}/pmflogo/dpmflogo3.rb ${SOURCE_FOLDER}/${BN}.dpcm ${DESTINATION_FOLDER}/${BN}.png
done
