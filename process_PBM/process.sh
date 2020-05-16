#!/usr/bin/env bash

NUM_THREADS=4

mkdir -p results/top_seqs
mkdir -p results/chipmunk_results
mkdir -p results/chipmunk_logs
mkdir -p results/pcms
mkdir -p results/dpcms
mkdir -p results/words
mkdir -p results/dilogo
mkdir -p results/logo
mkdir -p results/factors

# Generates files in ./seq_score folder
ruby normalize_pbm.rb
ruby calculate_head_sizes.rb

for FN in $( find results/seq_zscore/ -xtype f ); do
  BN=$(basename -s .tsv ${FN})
  cat $FN \
    | head -1000 \
    | awk -F $'\t' -e '{print "> " $3 "\n" $2}' \
    > results/top_seqs/${BN}.fa
done


for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})
  java -cp chipmunk.jar ru.autosome.di.ChIPMunk 20 6 y 1.0 s:${FN} 100 10 1 ${NUM_THREADS} random auto single > results/chipmunk_results/${BN}.chipmunk.txt 2> results/chipmunk_logs/${BN}.chipmunk.log

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

  sequence_logo --logo-folder results/logo results/pcms/${BN}.pcm
  ruby ./pmflogo/dpmflogo3.rb results/dpcms/${BN}.dpcm results/dilogo/${BN}.png
done

# Moves files from ./results/pcms ./results/logo ./results/seq_zscore ./results/top_seqs ./results/chipmunk_results ./results/chipmunk_logs etc --> into ./results/factors/{TF}
ruby move_files.rb
