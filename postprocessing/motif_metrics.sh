#!/usr/bin/env bash

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

##############

DATA_FOLDER='/home_local/vorontsovie/greco-data/release_8d.2022-07-31/full/'
MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_8c.pack_8_fix/'
BENCHMARK_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/motif_batch_8c_pack_8_fix'
BENCHMARK_FORMATTED_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/final_formatted'

# DATA_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/freeze_recalc_for_benchmark/datasets_freeze/'
# MOTIFS_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/freeze_recalc_for_benchmark/all_motifs/'
# BENCHMARK_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/freeze_recalc_for_benchmark/benchmarks/'
# BENCHMARK_FORMATTED_FOLDER='/home_local/vorontsovie/greco-bit-data-processing/freeze_recalc_for_benchmark/benchmarks_formatted/'

ruby postprocessing/motif_metrics_peaks_VIGG.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/vigg_peaks
ruby postprocessing/motif_metrics_peaks_centrimo.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/centrimo_peaks
ruby postprocessing/motif_metrics_peaks.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/pwmeval_peaks
ruby postprocessing/motif_metrics_pbm.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/pbm
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/reads_0.5/ --fraction 0.5
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/reads_0.25/ --fraction 0.25
ruby postprocessing/motif_metrics_reads.rb ${DATA_FOLDER} ${MOTIFS_FOLDER} ${BENCHMARK_FOLDER}/reads_0.1/ --fraction 0.1

time cat ${BENCHMARK_FOLDER}/pbm/prepare_all.sh | parallel -j 30
for DATATYPE in  reads_0.1 reads_0.25 reads_0.5  vigg_peaks centrimo_peaks pwmeval_peaks  pbm; do
  time cat ${BENCHMARK_FOLDER}/${DATATYPE}/run_all.sh | parallel -j 20 | pv -l > ${BENCHMARK_FOLDER}/${DATATYPE}.tsv;
done


time bash calc_motif_similarities_pack.sh ${MOTIFS_FOLDER} ~/greco-motifs/hocomoco11_core_human_pwm | parallel -j 30 | pv -l > hocomoco_similarities_8c_pack9.tsv
cat hocomoco_similarities_7e.tsv hocomoco_similarities_8c_pack{1,2,3,4,5,6_wo_bad,8_fix,9}.tsv  \
  | grep -vw ZNF705E  \
  | grep -vPe $( cat source_data_meta/fixes/CODEGATE_DatasetsSwap.txt | tail -n+2 | cut -d $'\t' -f1,4 | tr $'\t' '\n' | sort -u | tr '\n' '|' | sed -re 's/^(.+)\|$/^(\1)\\./' )  \
  > hocomoco_similarities.tsv

# MOTIFS_FOLDER here is recalc folder
time bash calc_motif_similarities_pack.sh ${MOTIFS_FOLDER} ~/greco-motifs/hocomoco11_core_human_pwm | parallel -j 30 | pv -l > hocomoco_similarities_recalc.tsv
cat hocomoco_similarities_recalc.tsv >> hocomoco_similarities.tsv

# FOLDERS ARE HARDCODED!!!
# takes motifs from 'benchmarks/release_8d/motif_batch_8c_pack_8_fix'
# outputs them into 'benchmarks/release_8d/final_formatted'
mkdir -p freeze_recalc_integrated/benchmarks_formatted
ruby postprocessing/reformat_metrics.rb

bash ./postprocessing/filter_motif_in_flanks.sh # be cautious
bash ./calculate_artifact_similarities.sh # be cautious

# hocomoco_similarities.tsv → hocomoco_similarities_recalc.tsv
# artifact_sims_precise → artifact_sims_precise_recalc
# {AFS,HTS,SMS_[un]published}_flanks_hits.tsv → *_flanks_hits_recalc.tsv
ruby postprocessing/fix_tf_names_codebook_bug-stage-3.rb

##################

METADATA_FN='freeze_recalc_integrated/datasets_metadata.full.json'
BENCHMARK_RANKS_FOLDER='benchmarks/release_8d_prefreeze/'
FLANKS_OPTIONS='
    --filter-sticky-flanks  HTS_flanks_hits_recalc.tsv
    --filter-sticky-flanks  AFS_flanks_hits_recalc.tsv
    --filter-sticky-flanks  SMS_unpublished_flanks_hits_recalc.tsv
    --filter-sticky-flanks  SMS_published_flanks_hits_recalc.tsv
    --flank-threshold 4.0
'
ARTIFACTS_OPTIONS='--artifact-similarities ./artifact_sims_precise_recalc  --artifact-similarity-threshold 0.15'
ETS_ONLY='--selected-tfs ELF3,FLI1,GABPA'
ALLOW_ETS_ARTIFACTS='--ignore-artifact-motifs ZNF827.FL@CHS@whiny-puce-turkey@HughesLab.Homer@Motif1,ZNF827.FL@CHS@stuffy-mustard-rat@HughesLab.Streme@Motif3,ZNF827.FL@CHS@stuffy-mustard-rat@HughesLab.MEME@Motif2'

FREEZE_OPTIONS='
    --datasets-curation  freeze_recalc_integrated/datasets_metadata.freeze.tsv
    --motifs-curation  freeze_recalc_integrated/motif_infos.freeze.tsv
'
APPROVED_FREEZE_OPTIONS='
    --datasets-curation  freeze_recalc_integrated/datasets_metadata.freeze_approved.tsv
    --motifs-curation  freeze_recalc_integrated/motif_infos.freeze_approved.tsv
'
PREFIX='7e+8c_pack_1-9'

mkdir -p ${BENCHMARK_RANKS_FOLDER}

#################

make_ranks() {
  NAME="$1"
  shift
  # $@ will be expanded to all the rest options
  time ruby postprocessing/motif_ranking.rb \
      ${BENCHMARK_FORMATTED_FOLDER} \
      ${BENCHMARK_RANKS_FOLDER}/metrics@${NAME}@disallow-artifacts.json \
      ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts.json \
      --metadata  ${METADATA_FN} \
      ${FLANKS_OPTIONS} ${ARTIFACTS_OPTIONS} \
      "$@" \
    2> ${BENCHMARK_RANKS_FOLDER}/${NAME}@disallow-artifacts.log \
    && echo ok || echo fail

  time ruby postprocessing/motif_ranking.rb \
      ${BENCHMARK_FORMATTED_FOLDER} \
      ${BENCHMARK_RANKS_FOLDER}/metrics@${NAME}@disallow-artifacts_ETS-only.json \
      ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts_ETS-only.json \
      --metadata  ${METADATA_FN} \
      ${FLANKS_OPTIONS} ${ARTIFACTS_OPTIONS} \
      ${ETS_ONLY} ${ALLOW_ETS_ARTIFACTS} \
      "$@" \
    2> ${BENCHMARK_RANKS_FOLDER}/${NAME}@disallow-artifacts_ETS-only.log \
    && echo ok || echo fail

  # combines @allow-artifacts and @disallow-artifacts into @disallow-artifacts_include-dropped-motifs
  time ruby postprocessing/correct_ranks_and_metrics_restore_dropped_artifacts.rb  ${BENCHMARK_RANKS_FOLDER}  ${NAME}
  source .venv/bin/activate
  time python3 generate_heatmaps.py  ${BENCHMARK_FORMATTED_FOLDER}/heatmaps@${NAME}@disallow-artifacts_ETS-refined/  ${BENCHMARK_RANKS_FOLDER}/ranks@${NAME}@disallow-artifacts_ETS-refined.json
  deactivate
}

#################

make_ranks  "${PREFIX}.core.freeze"  ${FREEZE_OPTIONS}
make_ranks  "${PREFIX}.core.freeze-approved"  ${APPROVED_FREEZE_OPTIONS}

make_ranks  "${PREFIX}.invivo.freeze"  ${FREEZE_OPTIONS}  --dataset-types CHS
make_ranks  "${PREFIX}.invivo.freeze-approved"  ${APPROVED_FREEZE_OPTIONS}  --dataset-types CHS

make_ranks  "${PREFIX}.invitro.freeze"  ${FREEZE_OPTIONS}  --dataset-types HTS.Lys,HTS.IVT,HTS.GFPIVT,AFS.Lys,AFS.IVT,AFS.GFPIVT,SMS,PBM.ME,PBM.HK
make_ranks  "${PREFIX}.invitro.freeze-approved"  ${APPROVED_FREEZE_OPTIONS}  --dataset-types HTS.Lys,HTS.IVT,HTS.GFPIVT,AFS.Lys,AFS.IVT,AFS.GFPIVT,SMS,PBM.ME,PBM.HK
