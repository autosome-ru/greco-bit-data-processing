#!/usr/bin/env bash

NUM_THREADS=4

mkdir -p top_seqs
mkdir -p chipmunk_results
mkdir -p chipmunk_logs
mkdir -p pcms
mkdir -p dpcms
mkdir -p logo
mkdir -p factors

# Generates files in ./seq_score folder
ruby normalize_pbm.rb

for FN in $( find seq_zscore/ -xtype f ); do
  BN=$(basename -s .tsv ${FN})
  cat $FN \
    | head -1000 \
    | awk -F $'\t' -e '{print "> " $3 "\n" $2}' \
    > top_seqs/${BN}.fa
done

for FN in $( find top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})
  java -cp chipmunk.jar ru.autosome.di.ChIPMunk 20 6 y 1.0 s:${FN} 100 10 1 ${NUM_THREADS} random auto single > chipmunk_results/${BN}.chipmunk.txt 2> chipmunk_logs/${BN}.chipmunk.log

  # cat chipmunk_results/${BN}.chipmunk.txt  \
  #   | grep -Pe '^[ACGT]\|'  \
  #   | sed -re 's/^[ACGT]\|//' \
  #   > pcms/${BN}.pcm

  cat chipmunk_results/${BN}.chipmunk.txt  \
    | grep -Pe '^[ACGT][ACGT]\|'  \
    | sed -re 's/^[ACGT][ACGT]\|//' \
    | ruby -e 'readlines.map{|l| l.chomp.split }.transpose.each{|r| puts r.join("\t") }' \
    > dpcms/${BN}.dpcm


  # sequence_logo --logo-folder logo pcms/${BN}.pcm
  ruby ./pmflogo/dpmflogo3.rb dpcms/${BN}.dpcm logo/${BN}.png
done

# Moves files from ./pcms ./logo ./seq_zscore ./top_seqs ./chipmunk_results ./chipmunk_logs  --> into ./factors/{TF}
ruby move_files.rb
