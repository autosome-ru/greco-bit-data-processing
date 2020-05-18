#!/usr/bin/env bash

NUM_THREADS=12
NUM_CHIPMUNK_THREADS=2

mkdir -p results/chip_scores_for_benchmark
mkdir -p results/chip_scores_for_benchmark_zscored
mkdir -p results/top_seqs
mkdir -p results/chipmunk_results
mkdir -p results/chipmunk_logs
mkdir -p results/pcms
mkdir -p results/dpcms
mkdir -p results/words
mkdir -p results/dilogo
mkdir -p results/logo
mkdir -p results/factors
ln -ns "$(readlink -e websrc)" results/websrc

# Generates files in ./seq_score folder

CHIPMUNK_LENGTH_RANGE='8 15'

CHIPMUNK_WEIGHTING_MODE='s'
#ADDITIONAL_CHIPMUNK_OPTIONS='disable_log_weighting'
ADDITIONAL_CHIPMUNK_OPTIONS=''

#CHIPMUNK_MODE=flat
CHIPMUNK_MODE=single

NORMALIZATION_MODE='--log10'
#NORMALIZATION_MODE='--log10-bg'

# TOP_MODE='--max-head-size 1000'
# TOP_MODE='--quantile 0.01'
TOP_MODE='--quantile 0.05'

ruby normalize_pbm.rb ${NORMALIZATION_MODE}
ruby extract_top_seqs.rb ${TOP_MODE}
ruby generate_summary.rb

for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})

  # It's better not to use more than 2 threads in chipmunk
  echo "java -cp chipmunk.jar ru.autosome.di.ChIPMunk" \
      "${CHIPMUNK_LENGTH_RANGE} y 1.0 ${CHIPMUNK_WEIGHTING_MODE}:${FN} 400 40 1 ${NUM_CHIPMUNK_THREADS} random auto ${CHIPMUNK_MODE} ${ADDITIONAL_CHIPMUNK_OPTIONS}" \
      "> results/chipmunk_results/${BN}.chipmunk.txt" \
      "2> results/chipmunk_logs/${BN}.chipmunk.log"
done | parallel -j ${NUM_THREADS}

for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})

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

echo -e "chip\tcorrelation" > results/motif_qualities.tsv
echo -e "chip\tcorrelation" > results/motif_qualities_zscored.tsv
for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})
  cat data/RawData/${BN}.txt | awk -F $'\t' -e '{print $8 "\t" $6}' | tail -n+2 > results/chip_scores_for_benchmark/${BN}.txt
  cat results/zscored_chips/${BN}.txt | awk -F $'\t' -e '{print $8 "\t" $6}' | tail -n+2 > results/chip_scores_for_benchmark_zscored/${BN}.txt
  CORRELATION=$(docker run --rm \
      --security-opt apparmor=unconfined \
      --mount type=bind,src=$(pwd)/results/chip_scores_for_benchmark/${BN}.txt,dst=/pbm_data.txt,readonly \
      --mount type=bind,src=$(pwd)/results/pcms/${BN}.pcm,dst=/motif.pcm,readonly \
      vorontsovie/pwmbench_pbm:1.1.0 \
      LOG /pbm_data.txt /motif.pcm)
  echo -e "${BN}\t${CORRELATION}" >> results/motif_qualities.tsv

  CORRELATION_zscored=$(docker run --rm \
      --security-opt apparmor=unconfined \
      --mount type=bind,src=$(pwd)/results/chip_scores_for_benchmark_zscored/${BN}.txt,dst=/pbm_data.txt,readonly \
      --mount type=bind,src=$(pwd)/results/pcms/${BN}.pcm,dst=/motif.pcm,readonly \
      vorontsovie/pwmbench_pbm:1.1.0 \
      EXP /pbm_data.txt /motif.pcm)
  echo -e "${BN}\t${CORRELATION_zscored}" >> results/motif_qualities_zscored.tsv
done

ruby generate_summary.rb # It will recreate existing docs with correlations appended

# Moves files from ./results/pcms ./results/logo ./results/seq_zscore ./results/top_seqs ./results/chipmunk_results ./results/chipmunk_logs etc --> into ./results/factors/{TF}
ruby move_files.rb
