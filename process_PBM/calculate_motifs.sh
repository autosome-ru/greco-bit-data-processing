#!/usr/bin/env bash

NUM_THREADS=12
NUM_CHIPMUNK_THREADS=2

CHIPMUNK_LENGTH_RANGE='8 15'

CHIPMUNK_WEIGHTING_MODE='s'
#ADDITIONAL_CHIPMUNK_OPTIONS='disable_log_weighting'
ADDITIONAL_CHIPMUNK_OPTIONS=''

#CHIPMUNK_MODE=flat
CHIPMUNK_MODE=single

mkdir -p results/chipmunk_results
mkdir -p results/chipmunk_logs

for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})

  # It's better not to use more than 2 threads in chipmunk
  echo "java -cp chipmunk.jar ru.autosome.di.ChIPMunk" \
      "${CHIPMUNK_LENGTH_RANGE} y 1.0 ${CHIPMUNK_WEIGHTING_MODE}:${FN} 400 40 1 ${NUM_CHIPMUNK_THREADS} random auto ${CHIPMUNK_MODE} ${ADDITIONAL_CHIPMUNK_OPTIONS}" \
      "> results/chipmunk_results/${BN}.chipmunk.txt" \
      "2> results/chipmunk_logs/${BN}.chipmunk.log"
done | parallel -j ${NUM_THREADS}
