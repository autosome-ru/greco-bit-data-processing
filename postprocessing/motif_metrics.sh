#!/usr/bin/env bash
# mkdir -p results

# MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_7e_motifs_2022-06-02/'
# DATA_FOLDER='/home_local/vorontsovie/greco-data/release_8c.2022-06-01/full/'

# ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} > run_benchmarks_release_8/run_all_pbm_7b+7e.sh

# # run on new motifs only
# # MOTIFS_FOLDER_TMP='./motifs_tmp/7d_minus_7c'
# # mkdir -p $MOTIFS_FOLDER_TMP
# # ruby -e \
# #     'old_release = ARGV[0]; new_release = ARGV[1]; current = Dir.glob("#{new_release}/*").map{|fn| File.basename(fn) }; old = Dir.glob("#{old_release}/*").map{|fn| File.basename(fn) }; (current - old).each{|bn| puts "#{new_release}/#{bn}" }' \
# #     -- \
# #     "/home_local/vorontsovie/greco-motifs/release_7c_motifs_2020-10-31"  \
# #     "/home_local/vorontsovie/greco-motifs/release_7d_motifs_2021-12-21" \
# #   | xargs -n1 -I{} cp {} $MOTIFS_FOLDER_TMP/
# # MOTIFS_FOLDER="${MOTIFS_FOLDER_TMP}" # Attention!!!

# ##############
# ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/reads_0.1/ --fraction 0.1
# ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/reads_0.25/ --fraction 0.25
# ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/reads_0.5/ --fraction 0.5

# ruby postprocessing/motif_metrics_peaks_VIGG.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/vigg_peaks
# ruby postprocessing/motif_metrics_peaks_centrimo.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/centrimo_peaks/
# ruby postprocessing/motif_metrics_peaks.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/pwmeval_peaks/

# ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ~/greco-benchmark/release_8c_for_8c_pack2/pbm/
# cat ~/greco-benchmark/release_8c_for_8c_pack2/pbm/prepare_all.sh | parallel -j 100
# ##############
# for DATATYPE in  reads_0.1 reads_0.25 reads_0.5  vigg_peaks centrimo_peaks pwmeval_peaks  pbm; do
#   echo $DATATYPE
#   date
#   time cat ~/greco-benchmark/release_8c_for_8c_pack2/${DATATYPE}/run_all.sh | parallel -j 100 | pv -l > ~/greco-benchmark/release_8c_for_8c_pack2/${DATATYPE}.tsv
# done

##############

DATA_FOLDER='/home_local/vorontsovie/greco-data/release_8d.2022-07-31/full/'
MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_8c.pack_8_fix/'
BENCHMARK_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/motif_batch_8c_pack_8_fix'

time ruby postprocessing/motif_metrics_peaks_VIGG.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/vigg_peaks
time ruby postprocessing/motif_metrics_peaks_centrimo.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/centrimo_peaks
time ruby postprocessing/motif_metrics_peaks.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/pwmeval_peaks
time ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/pbm
time ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/reads_0.5/ --fraction 0.5
time ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/reads_0.25/ --fraction 0.25
time ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/reads_0.1/ --fraction 0.1

time cat ${BENCHMARK_FOLDER}/pbm/prepare_all.sh | parallel -j 30
for DATATYPE in  reads_0.1 reads_0.25 reads_0.5  vigg_peaks centrimo_peaks pwmeval_peaks  pbm; do
  time cat ${BENCHMARK_FOLDER}/${DATATYPE}/run_all.sh | parallel -j 20 | pv -l > ${BENCHMARK_FOLDER}/${DATATYPE}.tsv;
done


time bash calc_motif_similarities_pack.sh ${MOTIFS_FOLDER} ~/greco-motifs/hocomoco11_core_human_pwm | parallel -j 30 | pv -l > hocomoco_similarities_8c_pack8_fix.tsv
cat hocomoco_similarities_7e.tsv hocomoco_similarities_8c_pack{1,2,3,4,5,6_wo_bad,7,8_fix}.tsv | grep -vw ZNF705E > hocomoco_similarities.tsv


ruby postprocessing/reformat_metrics.rb
bash ./postprocessing/filter_motif_in_flanks.sh # be cautious
bash ./calculate_artifact_similarities.sh # be cautious

# ruby postprocessing/motif_ranking.rb \
#     benchmarks/release_8d/metrics_7e+8c_pack_1-5.json \
#     benchmarks/release_8d/ranks_7e+8c_pack_1-5.json \
#     --metadata  /home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.json \
#     --filter-sticky-flanks  HTS_flanks_hits.tsv \
#     --filter-sticky-flanks  AFS_flanks_hits.tsv \
#     --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
#     --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
#     --flank-threshold 4.0 \
#   2> benchmarks/release_8d/ranking.log \
#   && echo ok || echo fail

time ruby postprocessing/motif_ranking.rb \
    benchmarks/release_8d/metrics_7e+8c_pack_1-7_disallow-artifacts.json \
    benchmarks/release_8d/ranks_7e+8c_pack_1-7_disallow-artifacts.json \
    --metadata  /home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.patch1.json \
    --filter-sticky-flanks  HTS_flanks_hits.tsv \
    --filter-sticky-flanks  AFS_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
    --flank-threshold 4.0 \
    --artifact-similarities ./artifact_sims_precise --artifact-similarity-threshold 0.15 \
    2> benchmarks/release_8d/ranking_artifact.7e+8c1-7_disallow-artifacts.log   && echo ok || echo fail

time ruby postprocessing/motif_ranking.rb \
    benchmarks/release_8d/metrics_7e+8c_pack_1-7_allow-artifacts.json \
    benchmarks/release_8d/ranks_7e+8c_pack_1-7_allow-artifacts.json \
    --metadata  /home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.patch1.json \
    2> benchmarks/release_8d/ranking_allow-artifacts.7e+8c1-7.log   && echo ok || echo fail


time ruby postprocessing/motif_ranking.rb \
    benchmarks/release_8d/metrics_curated_7e+8c_pack_1-7_disallow-artifacts.json \
    benchmarks/release_8d/ranks_curated_7e+8c_pack_1-7_disallow-artifacts.json \
    --metadata  /home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.patch1.json \
    --filter-sticky-flanks  HTS_flanks_hits.tsv \
    --filter-sticky-flanks  AFS_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv \
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv \
    --flank-threshold 4.0 \
    --curation  source_data_meta/shared/experiment_verdicts.tsv \
  2> benchmarks/release_8d/ranking_curated.7e+8c1-7_disallow-artifacts.log \
  && echo ok || echo fail

time ruby postprocessing/motif_ranking.rb \
    benchmarks/release_8d/metrics_curated_7e+8c_pack_1-7_allow-artifacts.json \
    benchmarks/release_8d/ranks_curated_7e+8c_pack_1-7_allow-artifacts.json \
    --metadata  /home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.patch1.json \
    --curation  source_data_meta/shared/experiment_verdicts.tsv \
  2> benchmarks/release_8d/ranking_curated_allow-artifacts.7e+8c1-7.log \
  && echo ok || echo fail

time ruby correct_ranks_and_metrics_restore_dropped_artifacts.rb
