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

for SUFFIX in "" "_7a+7c"  "_7a+7c_upd"; do # calculation was multistaged
  cat run_benchmarks_release_7/run_all_pbm${SUFFIX}.sh | parallel > run_benchmarks_release_7/pbm${SUFFIX}.tsv
  cat run_benchmarks_release_7/run_all_VIGG_peaks${SUFFIX}.sh | parallel > run_benchmarks_release_7/VIGG_peaks${SUFFIX}.tsv
  cat run_benchmarks_release_7/run_all_centrimo${SUFFIX}.sh | parallel > run_benchmarks_release_7/centrimo${SUFFIX}.tsv
  cat run_benchmarks_release_7/run_all_pwmeval_peaks${SUFFIX}.sh | parallel > run_benchmarks_release_7/pwmeval_peaks${SUFFIX}.tsv
  cat run_benchmarks_release_7/reads_0.25${SUFFIX}/run_all.sh | parallel > run_benchmarks_release_7/reads_0.25${SUFFIX}.tsv
  cat run_benchmarks_release_7/reads_0.5${SUFFIX}/run_all.sh | parallel > run_benchmarks_release_7/reads_0.5${SUFFIX}.tsv
  cat run_benchmarks_release_7/reads_0.1${SUFFIX}/run_all.sh | parallel > run_benchmarks_release_7/reads_0.1${SUFFIX}.tsv
done

ruby postprocessing/reformat_metrics.rb

bash ./postprocessing/filter_motif_in_flanks.sh # be cautious

ruby postprocessing/motif_ranking.rb \
    run_benchmarks_release_7/metrics_curated_7a+7c.json \
    run_benchmarks_release_7/ranks_curated_7a+7c.json \
    --metadata  run_benchmarks_release_7/metadata_release_7a.json \
    --filter-sticky-flanks  HTS_flanks_hits.tsv \
    --filter-sticky-flanks  AFS_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
    --flank-threshold 4.0 \
  2> run_benchmarks_release_7/ranking.log

ruby postprocessing/motif_ranking.rb \
    run_benchmarks_release_7/metrics_curated_7a+7c.json \
    run_benchmarks_release_7/ranks_curated_7a+7c.json \
    --metadata  run_benchmarks_release_7/metadata_release_7a.json \
    --filter-sticky-flanks  HTS_flanks_hits.tsv \
    --filter-sticky-flanks  AFS_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
    --flank-threshold 4.0 \
    --curation  source_data_meta/shared/curations.tsv \
  2> run_benchmarks_release_7/ranking_curated.log
