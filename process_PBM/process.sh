#!/usr/bin/env bash

mkdir -p results/top_seqs
mkdir -p results/factors
ln -ns "$(readlink -e websrc)" results/websrc

NORMALIZATION_MODE='--log10'
#NORMALIZATION_MODE='--log10-bg'

# TOP_MODE='--max-head-size 1000'
# TOP_MODE='--quantile 0.01'
TOP_MODE='--quantile 0.05'

ruby normalize_pbm.rb ${NORMALIZATION_MODE}
ruby extract_top_seqs.rb ${TOP_MODE}

./calculate_motifs.sh

./extract_pcms.sh
./generate_logo.sh
ruby generate_summary.rb # It will recreate existing docs with correlations appended

# Moves files from ./results/pcms ./results/logo ./results/seq_zscore ./results/top_seqs ./results/chipmunk_results ./results/chipmunk_logs etc --> into ./results/factors/{TF}
ruby move_files.rb
