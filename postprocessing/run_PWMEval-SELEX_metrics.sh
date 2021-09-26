#!/usr/bin/env bash
set -euo pipefail

function run_benchmark() {
    DATASET="$(readlink -m "$1")"
    MOTIF="$(readlink -m "$2")"
    TOP_FRACTION="$3"
    FLANK_5="$4"
    FLANK_3="$5"
    PSEUDO_WEIGHT="$6"
    MOTIF_EXT="${MOTIF##*.}"
    docker run --rm \
      --security-opt apparmor=unconfined \
      --volume "${DATASET}:/seq.fastq.gz:ro" \
      --volume "${MOTIF}:/motif.${MOTIF_EXT}:ro" \
      vorontsovie/pwmeval_selex:2.0.0 \
          evaluate \
          --seq /seq.fastq.gz \
          --motif /motif.${MOTIF_EXT} \
          --non-redundant --top ${TOP_FRACTION} --bin 1000 --maxnum-reads 500000 \
          --pseudo-weight ${PSEUDO_WEIGHT} --flank-5 ${FLANK_5} --flank-3 ${FLANK_3} \
          --seed 1
}

function run_benchmark_using_prepared() {
    DATASET="$(readlink -m "$1")"
    MOTIF="$(readlink -m "$2")"
    TOP_FRACTION="$3"
    PREPARED_SEQUENCES="$(readlink -m "$4")"
    PSEUDO_WEIGHT="$1"

    DATASET_BN="$(basename "$DATASET")"
    MOTIF_EXT="${MOTIF##*.}"

    docker run --rm \
      --security-opt apparmor=unconfined \
      --volume "${PREPARED_SEQUENCES}:/sequences:ro" \
      --volume "${MOTIF}:/motif.${MOTIF_EXT}:ro" \
      vorontsovie/pwmeval_selex:2.0.0 \
          evaluate \
          --positive-file "/sequences/positive/pos_${DATASET_BN}" \
          --negative-file "/sequences/negative/neg_${DATASET_BN}" \
          --top ${TOP_FRACTION} --bin 1000 \
          --pseudo-weight ${PSEUDO_WEIGHT}
}

DATASET="$(readlink -m "$1")"
MOTIF="$(readlink -m "$2")"
echo -ne "${DATASET}\t${MOTIF}\t"
run_benchmark_using_prepared "$@" 0.0001 || echo
