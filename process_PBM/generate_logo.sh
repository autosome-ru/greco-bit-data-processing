#!/usr/bin/env bash

mkdir -p results/dilogo
mkdir -p results/logo

for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})
  sequence_logo --logo-folder results/logo results/pcms/${BN}.pcm
  ruby ./pmflogo/dpmflogo3.rb results/dpcms/${BN}.dpcm results/dilogo/${BN}.png
done
