#!/usr/bin/env bash
set -euo pipefail
DATASET="$1"
MOTIF="$2"
TOP_FRACTION="$3"
FLANK_5="$4"
FLANK_3="$5"

MOTIF_EXT="${MOTIF##*.}"


function run_benchmark() {
    PSEUDO_WEIGHT="$1"
    docker run --rm \
      --security-opt apparmor=unconfined \
      --volume "${DATASET}:/seq.fastq.gz:ro" \
      --volume "${MOTIF}:/motif.${MOTIF_EXT}:ro" \
      vorontsovie/pwmeval_selex:1.0.3 \
      --non-redundant --top ${TOP_FRACTION} --bin 1000 --maxnum-reads 500000 \
      --pseudo-weight ${PSEUDO_WEIGHT} --flank-5 ${FLANK_5} --flank-3 ${FLANK_3} \
      --seed 1
}

echo -ne "${DATASET}\t${MOTIF}\t"
run_benchmark 0.0001 || echo
