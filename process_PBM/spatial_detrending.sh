#!/usr/bin/env bash
set -euo pipefail

SCRIPT_FOLDER=$(dirname $(readlink -f $0))

WINDOW_SIZE=5
NUM_THREADS=1

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
        --window-size)
            WINDOW_SIZE="$2"
            shift
            ;;
        --num-threads)
            NUM_THREADS="$2"
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
  BN=$(basename ${FN})

  echo "Rscript ${SCRIPT_FOLDER}/spatial_detrend.R --window-size ${WINDOW_SIZE} ${SOURCE_FOLDER}/${BN} > ${DESTINATION_FOLDER}/${BN}"
done | parallel -j ${NUM_THREADS}
