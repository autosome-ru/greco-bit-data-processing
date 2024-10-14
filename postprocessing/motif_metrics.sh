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
BENCHMARK_FORMATTED_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/final_formatted'

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


time bash calc_motif_similarities_pack.sh ${MOTIFS_FOLDER} ~/greco-motifs/hocomoco11_core_human_pwm | parallel -j 30 | pv -l > hocomoco_similarities_8c_pack9.tsv
cat hocomoco_similarities_7e.tsv hocomoco_similarities_8c_pack{1,2,3,4,5,6_wo_bad,8_fix,9}.tsv | grep -vw ZNF705E > hocomoco_similarities.tsv

# TODO: add 8_fix to a common folder
# filter_motifs_in_flanks
# calculate_artifact_similarities


# FOLDERS ARE HARDCODED!!!
# takes motifs from 'benchmarks/release_8d/motif_batch_8c_pack_8_fix'
# outputs them into 'benchmarks/release_8d/final_formatted'
ruby postprocessing/reformat_metrics.rb

bash ./postprocessing/filter_motif_in_flanks.sh # be cautious
bash ./calculate_artifact_similarities.sh # be cautious

##################

METADATA_FN='/home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.patch2.json'
BENCHMARK_RANKS_FOLDER='benchmarks/release_8d_prefreeze/'
FLANKS_OPTIONS='
    --filter-sticky-flanks  HTS_flanks_hits.tsv
    --filter-sticky-flanks  AFS_flanks_hits.tsv
    --filter-sticky-flanks  SMS_unpublished_flanks_hits.tsv
    --filter-sticky-flanks  SMS_published_flanks_hits.tsv
    --flank-threshold 4.0
'
ARTIFACTS_OPTIONS='--artifact-similarities ./artifact_sims_precise  --artifact-similarity-threshold 0.15'
ETS_ONLY='--selected-tfs ELF3,FLI1,GABPA'
ALLOW_ETS_ARTIFACTS='--ignore-artifact-motifs ZNF827.FL@CHS@whiny-puce-turkey@HughesLab.Homer@Motif1,ZNF827.FL@CHS@stuffy-mustard-rat@HughesLab.Streme@Motif3,ZNF827.FL@CHS@stuffy-mustard-rat@HughesLab.MEME@Motif2'

FREEZE_OPTIONS='
    --datasets-curation  prefreeze/metadata_release_8d.patch2.freeze.tsv
    --motifs-curation  prefreeze/motif_infos.freeze.tsv
'
APPROVED_FREEZE_OPTIONS='
    --datasets-curation  prefreeze/metadata_release_8d.patch2.freeze_approved.tsv
    --motifs-curation  prefreeze/motif_infos.freeze_approved.tsv
'
PREFIX='7e+8c_pack_1-9'

mkdir -p ${BENCHMARK_RANKS_FOLDER}

#################
SECOND_PREFIX=''
DATATYPES_OPTIONS=''

SECOND_PREFIX='.invivo'
DATATYPES_OPTIONS='--dataset-types CHS'

SECOND_PREFIX='.invitro'
DATATYPES_OPTIONS='--dataset-types HTS.Lys,HTS.IVT,HTS.GFPIVT,AFS.Lys,AFS.IVT,AFS.GFPIVT,SMS,PBM.ME,PBM.HK'

#################

NAME="${PREFIX}${SECOND_PREFIX}.freeze"

time ruby postprocessing/motif_ranking.rb \
    ${BENCHMARK_FORMATTED_FOLDER} \
    ${BENCHMARK_RANKS_FOLDER}/metrics@${NAME}@disallow-artifacts.json \
    ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts.json \
    --metadata  ${METADATA_FN} \
    ${FREEZE_OPTIONS} \
    ${FLANKS_OPTIONS} ${ARTIFACTS_OPTIONS} \
  2> ${BENCHMARK_RANKS_FOLDER}/${NAME}@disallow-artifacts.log \
  && echo ok || echo fail

time ruby postprocessing/motif_ranking.rb \
    ${BENCHMARK_FORMATTED_FOLDER} \
    ${BENCHMARK_RANKS_FOLDER}/metrics@${NAME}@disallow-artifacts_ETS-only.json \
    ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts_ETS-only.json \
    --metadata  ${METADATA_FN} \
    ${FREEZE_OPTIONS} \
    ${FLANKS_OPTIONS} ${ARTIFACTS_OPTIONS} \
    ${ETS_ONLY} ${ALLOW_ETS_ARTIFACTS} \
  2> ${BENCHMARK_RANKS_FOLDER}/${NAME}@disallow-artifacts_ETS-only.log \
  && echo ok || echo fail

# combines @allow-artifacts and @disallow-artifacts into @disallow-artifacts_include-dropped-motifs
time ruby postprocessing/correct_ranks_and_metrics_restore_dropped_artifacts.rb  ${BENCHMARK_RANKS_FOLDER}  ${NAME}
time python3 generate_heatmaps.py  ${BENCHMARK_FORMATTED_FOLDER}/heatmaps@${NAME}@disallow-artifacts_ETS-refined/  ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts_ETS-refined.json

#################

NAME="${PREFIX}${SECOND_PREFIX}.freeze-approved"

time ruby postprocessing/motif_ranking.rb \
    ${BENCHMARK_FORMATTED_FOLDER} \
    ${BENCHMARK_RANKS_FOLDER}/metrics@${NAME}@disallow-artifacts.json \
    ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts.json \
    --metadata  ${METADATA_FN} \
    ${APPROVED_FREEZE_OPTIONS} \
    ${FLANKS_OPTIONS} ${ARTIFACTS_OPTIONS} \
  2> ${BENCHMARK_RANKS_FOLDER}/${NAME}@disallow-artifacts.log \
  && echo ok || echo fail


time ruby postprocessing/motif_ranking.rb \
    ${BENCHMARK_FORMATTED_FOLDER} \
    ${BENCHMARK_RANKS_FOLDER}/metrics@${NAME}@disallow-artifacts_ETS-only.json \
    ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts_ETS-only.json \
    --metadata  ${METADATA_FN} \
    ${APPROVED_FREEZE_OPTIONS} \
    ${FLANKS_OPTIONS} ${ARTIFACTS_OPTIONS} \
    ${ETS_ONLY} ${ALLOW_ETS_ARTIFACTS} \
  2> ${BENCHMARK_RANKS_FOLDER}/${NAME}@disallow-artifacts_ETS-only.log \
  && echo ok || echo fail

time ruby postprocessing/correct_ranks_and_metrics_restore_dropped_artifacts.rb  ${BENCHMARK_RANKS_FOLDER}  ${NAME}
time python3 generate_heatmaps.py  ${BENCHMARK_FORMATTED_FOLDER}/heatmaps@${NAME}@disallow-artifacts_ETS-refined/  ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts_ETS-refined.json

#################

