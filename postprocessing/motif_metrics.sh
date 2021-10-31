#!/usr/bin/env bash
mkdir -p results
DATA_FOLDER='/home_local/vorontsovie/greco-data/release_7a.2021-10-14/full/'
MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_7c_motifs_2020-10-31/'

ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} > run_benchmarks_release_7/run_all_pbm_7a+7c.sh
ruby postprocessing/motif_metrics_peaks_VIGG.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} > run_benchmarks_release_7/run_all_VIGG_peaks_7a+7c.sh
ruby postprocessing/motif_metrics_peaks_centrimo.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} > run_benchmarks_release_7/run_all_centrimo_7a+7c.sh
ruby postprocessing/motif_metrics_peaks.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} > run_benchmarks_release_7/run_all_pwmeval_peaks_7a+7c.sh
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_7/reads_0.1_7a+7c/ --fraction 0.1
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_7/reads_0.5_7a+7c/ --fraction 0.5
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_7/reads_0.25_7a+7c/ --fraction 0.25

cat run_benchmarks_release_7/run_all_pbm_7a+7c.sh | parallel > run_benchmarks_release_7/pbm_7a+7c.tsv
cat run_benchmarks_release_7/run_all_VIGG_peaks_7a+7c.sh | parallel > run_benchmarks_release_7/VIGG_peaks_7a+7c.tsv
cat run_benchmarks_release_7/run_all_centrimo_7a+7c.sh | parallel > run_benchmarks_release_7/centrimo_7a+7c.tsv
cat run_benchmarks_release_7/run_all_pwmeval_peaks_7a+7c.sh | parallel > run_benchmarks_release_7/pwmeval_peaks_7a+7c.tsv
cat run_benchmarks_release_7/reads_0.25_7a+7c/run_all.sh | parallel > run_benchmarks_release_7/reads_0.25_7a+7c.tsv
cat run_benchmarks_release_7/reads_0.5_7a+7c/run_all.sh | parallel > run_benchmarks_release_7/reads_0.5_7a+7c.tsv
cat run_benchmarks_release_7/reads_0.1_7a+7c/run_all.sh | parallel > run_benchmarks_release_7/reads_0.1_7a+7c.tsv
