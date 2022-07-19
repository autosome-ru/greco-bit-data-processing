#!/usr/bin/env bash
mkdir -p results
MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_7e_motifs_2022-06-02/'
DATA_FOLDER='/home_local/vorontsovie/greco-data/release_8c.2022-06-01/full/'

ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} > run_benchmarks_release_8/run_all_pbm_7b+7e.sh

# run on new motifs only
# MOTIFS_FOLDER_TMP='./motifs_tmp/7d_minus_7c'
# mkdir -p $MOTIFS_FOLDER_TMP
# ruby -e \
#     'old_release = ARGV[0]; new_release = ARGV[1]; current = Dir.glob("#{new_release}/*").map{|fn| File.basename(fn) }; old = Dir.glob("#{old_release}/*").map{|fn| File.basename(fn) }; (current - old).each{|bn| puts "#{new_release}/#{bn}" }' \
#     -- \
#     "/home_local/vorontsovie/greco-motifs/release_7c_motifs_2020-10-31"  \
#     "/home_local/vorontsovie/greco-motifs/release_7d_motifs_2021-12-21" \
#   | xargs -n1 -I{} cp {} $MOTIFS_FOLDER_TMP/
# MOTIFS_FOLDER="${MOTIFS_FOLDER_TMP}" # Attention!!!

##############
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/reads_0.1/ --fraction 0.1
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/reads_0.25/ --fraction 0.25
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/reads_0.5/ --fraction 0.5

ruby postprocessing/motif_metrics_peaks_VIGG.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/vigg_peaks
ruby postprocessing/motif_metrics_peaks_centrimo.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/centrimo_peaks/
ruby postprocessing/motif_metrics_peaks.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/pwmeval_peaks/

ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/pbm/
cat ~/greco-benchmark/release_8c_for_8c_pack2/pbm/prepare_all.sh | parallel -j 100
##############
for DATATYPE in  reads_0.1 reads_0.25 reads_0.5  vigg_peaks centrimo_peaks pwmeval_peaks  pbm; do
  echo $DATATYPE
  date
  time cat ~/greco-benchmark/release_8c_for_8c_pack2/${DATATYPE}/run_all.sh | parallel -j 100 | pv -l > ~/greco-benchmark/release_8c_for_8c_pack2/${DATATYPE}.tsv
done

##############

# ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/run_all_pbm_8c_on_8c_pack1.sh
# ruby postprocessing/motif_metrics_peaks_VIGG.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/pwmeval_peaks_8c_on_8c_pack1/
# ruby postprocessing/motif_metrics_peaks_centrimo.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/centrimo_peaks_8c_on_8c_pack1/
# ruby postprocessing/motif_metrics_peaks.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/pwmeval_peaks_8c_on_8c_pack1/
# ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/reads_0.25_8c_on_8c_pack1/ --fraction 0.25
# ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/reads_0.5_8c_on_8c_pack1/ --fraction 0.5
# ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ./run_benchmarks_release_8/reads_0.1_8c_on_8c_pack1/ --fraction 0.1

# for SUFFIX in "" "_7a+7c"  "_7a+7c_upd" "_7a+7_upd_d" "_7a+7_upd_e"; do # calculation was multistaged
for SUFFIX in "_8c_on_8c_pack1"; do # calculation was multistaged
  # cat run_benchmarks_release_8/run_all_pbm${SUFFIX}.sh | parallel > run_benchmarks_release_8/pbm${SUFFIX}.tsv
  # cat run_benchmarks_release_8/run_all_VIGG_peaks${SUFFIX}.sh | parallel > run_benchmarks_release_8/VIGG_peaks${SUFFIX}.tsv
  # cat run_benchmarks_release_8/run_all_centrimo${SUFFIX}.sh | parallel > run_benchmarks_release_8/centrimo${SUFFIX}.tsv
  # cat run_benchmarks_release_8/run_all_pwmeval_peaks${SUFFIX}.sh | parallel > run_benchmarks_release_8/pwmeval_peaks${SUFFIX}.tsv
  time cat run_benchmarks_release_8/reads_0.25${SUFFIX}/run_all.sh | parallel | pv -l > run_benchmarks_release_8/reads_0.25${SUFFIX}.tsv
  time cat run_benchmarks_release_8/reads_0.5${SUFFIX}/run_all.sh  | parallel | pv -l > run_benchmarks_release_8/reads_0.5${SUFFIX}.tsv
  time cat run_benchmarks_release_8/reads_0.1${SUFFIX}/run_all.sh  | parallel | pv -l > run_benchmarks_release_8/reads_0.1${SUFFIX}.tsv
done

for SUFFIX in "_7b+7_upd_e"; do
  # cat run_benchmarks_release_8/run_all_pbm${SUFFIX}.sh | parallel >> run_benchmarks_release_8/pbm${SUFFIX}.tsv
  cat run_benchmarks_release_8/run_all_pbm${SUFFIX}.sh | parallel > run_benchmarks_release_8/pbm${SUFFIX}.tsv
done

# rm "${MOTIFS_FOLDER_TMP}" -r
# MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_7e_motifs_2022-06-02/'

find ~/greco-motifs/release_7d_motifs_2021-12-21/ -xtype f | xargs -n1 -I{} cp {} ~/greco-motifs/release_7e_motifs_2022-06-02/

ruby postprocessing/reformat_metrics.rb
bash ./postprocessing/filter_motif_in_flanks.sh # be cautious

ruby postprocessing/motif_ranking.rb \
    benchmarks/release_8c/metrics_7e+8c_pack_1+2.json \
    benchmarks/release_8c/ranks_7e+8c_pack_1+2.json \
    --metadata  /home_local/vorontsovie/greco-data/release_8c.2022-06-01/metadata_release_8c.json \
    --filter-sticky-flanks  HTS_flanks_hits.tsv \
    --filter-sticky-flanks  AFS_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
    --flank-threshold 4.0 \
  2> benchmarks/release_8c/ranking.log \
  && echo ok || echo fail

time ruby postprocessing/motif_ranking.rb \
    benchmarks/release_8c/metrics_curated_7e+8c_pack_1+2.json \
    benchmarks/release_8c/ranks_curated_7e+8c_pack_1+2.json \
    --metadata  /home_local/vorontsovie/greco-data/release_8c.2022-06-01/metadata_release_8c.json \
    --filter-sticky-flanks  HTS_flanks_hits.tsv \
    --filter-sticky-flanks  AFS_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
    --flank-threshold 4.0 \
    --curation  source_data_meta/shared/curations.tsv \
  2> benchmarks/release_8c/ranking_curated.log \
  && echo ok || echo fail
