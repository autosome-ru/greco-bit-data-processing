#!/usr/bin/env bash
set -euo pipefail

NUM_PROCESSES=1
NUM_INNER_THREADS=2

LENGTH_RANGE='8 15'

WEIGHTING_MODE='s'
ADDITIONAL_OPTIONS=''

SHAPE=flat

while true; do
    case "${1-}" in
        --source)
            SOURCE_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --results-destination)
            RESULTS_DESTINATION_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --logs-destination)
            LOGS_DESTINATION_FOLDER="$(readlink -m "$2")"
            shift
            ;;
        --num-processes)
            NUM_PROCESSES="$2"
            shift
            ;;
        --num-inner-threads)
            NUM_INNER_THREADS="$2"
            shift
            ;;
        --length-range)
            LENGTH_RANGE="$2 $3"
            shift 2
            ;;
        --shape)
            SHAPE="$2"
            shift
            ;;
        --weighting-mode)
            WEIGHTING_MODE="$2"
            shift
            ;;
        --additional-options)
            ADDITIONAL_OPTIONS="$2"
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

mkdir -p "${RESULTS_DESTINATION_FOLDER}"
mkdir -p "${LOGS_DESTINATION_FOLDER}"

for FN in $( find "${SOURCE_FOLDER}" -xtype f ); do
  BN=$(basename -s .fa ${FN})

  # It's better not to use more than 2 threads in chipmunk
  echo "java -cp chipmunk.jar ru.autosome.di.ChIPMunk" \
      "${LENGTH_RANGE} y 1.0 ${WEIGHTING_MODE}:${FN} 400 40 1 ${NUM_INNER_THREADS} random auto ${SHAPE} ${ADDITIONAL_OPTIONS}" \
      "> ${RESULTS_DESTINATION_FOLDER}/${BN}.txt" \
      "2> ${LOGS_DESTINATION_FOLDER}/${BN}.log"
done | parallel -j ${NUM_PROCESSES}
