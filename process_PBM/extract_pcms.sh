#!/usr/bin/env bash

mkdir -p results/pcms
mkdir -p results/dpcms
mkdir -p results/words

for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})

  # # It's reserved for mono-chipmunk results
  # cat results/chipmunk_results/${BN}.chipmunk.txt  \
  #   | grep -Pe '^[ACGT]\|'  \
  #   | sed -re 's/^[ACGT]\|//' \
  #   > results/pcms/${BN}.pcm

  cat results/chipmunk_results/${BN}.chipmunk.txt  \
    | grep -Pe '^[ACGT][ACGT]\|'  \
    | sed -re 's/^[ACGT][ACGT]\|//' \
    | ruby -e 'readlines.map{|l| l.chomp.split }.transpose.each{|r| puts r.join("\t") }' \
    > results/dpcms/${BN}.dpcm

  cat results/chipmunk_results/${BN}.chipmunk.txt  \
    | grep -Pe '^WORD\|'  \
    | sed -re 's/^WORD\|//' \
    | ruby -e 'readlines.each{|l| word, weight = l.chomp.split("\t").values_at(2, 5); puts(">#{weight}"); puts(word) }' \
    > results/words/${BN}.fa

  cat results/words/${BN}.fa | ruby fasta2pcm.rb --weighted > results/pcms/${BN}.pcm
done
