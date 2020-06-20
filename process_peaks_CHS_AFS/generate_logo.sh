#!/usr/bin/env bash
set -euo pipefail

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
  BN=$(basename -s .pcm ${FN})
  sequence_logo --logo-folder ${DESTINATION_FOLDER} ${SOURCE_FOLDER}/${BN}.pcm
done
