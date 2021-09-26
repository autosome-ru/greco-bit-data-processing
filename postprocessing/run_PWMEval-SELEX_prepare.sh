#!/usr/bin/env bash
set -euo pipefail

function prepare_benchmark() {
  DATASET="$(readlink -m "$1")"
  FLANK_5="$2"
  FLANK_3="$3"
  PREPARED_SEQUENCES="$(readlink -m "$4")"
  
  DATASET_BN="$(basename "$DATASET")"

  docker run --rm \
    --security-opt apparmor=unconfined \
    --volume "${DATASET}:/seq.fastq.gz:ro" \
    --volume "${PREPARED_SEQUENCES}:/sequences" \
    vorontsovie/pwmeval_selex:2.0.0 \
        prepare \
        --positive-file "/sequences/positive/pos_${DATASET_BN}" \
        --negative-file "/sequences/negative/neg_${DATASET_BN}" \
        --non-redundant --maxnum-reads 500000 \
        --flank-5 ${FLANK_5} --flank-3 ${FLANK_3} \
        --seed 1
}

prepare_benchmark "$@"
