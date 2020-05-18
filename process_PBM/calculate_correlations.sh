#!/usr/bin/env bash

mkdir -p results/chip_scores_for_benchmark
mkdir -p results/chip_scores_for_benchmark_zscored

echo -e "chip\tcorrelation" > results/motif_qualities.tsv
echo -e "chip\tcorrelation" > results/motif_qualities_zscored.tsv
for FN in $( find results/top_seqs/ -xtype f ); do
  BN=$(basename -s .fa ${FN})
  
  # append linker sequence
  cat data/RawData/${BN}.txt | awk -F $'\t' -e '{print $8 "\t" $7$6}' | tail -n+2 > results/chip_scores_for_benchmark/${BN}.txt
  cat results/zscored_chips/${BN}.txt | awk -F $'\t' -e '{print $8 "\t" $7$6}' | tail -n+2 > results/chip_scores_for_benchmark_zscored/${BN}.txt
  
  # # don't append linker sequence
  # cat data/RawData/${BN}.txt | awk -F $'\t' -e '{print $8 "\t" $6}' | tail -n+2 > results/chip_scores_for_benchmark/${BN}.txt
  # cat results/zscored_chips/${BN}.txt | awk -F $'\t' -e '{print $8 "\t" $6}' | tail -n+2 > results/chip_scores_for_benchmark_zscored/${BN}.txt
  

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
