#!/usr/bin/env bash
set -euo pipefail

function metadata_tsv {
  INPUT="$1"
  (
    echo -e 'dataset_id\tdataset_name\ttf\tconstruct_type\texperiment_type\texperiment_subtype\texperiment_id\treplicate\tprocessing_type\tslice_type\textension';
    cat "$INPUT"  \
      | jq -r '[.dataset_id, .dataset_name, .tf, .construct_type, .experiment_type, .experiment_subtype, .experiment_id, .experiment_params.replica, .processing_type, .slice_type, .extension] | @tsv' \
  ) | ruby -e '$stdin.each_line{|l| row = l.chomp.split("\t"); row[-2] = "Test"  if row[-2] == "Val"; row[4] = "GHTS"  if row[4] == "AFS"; puts row.join("\t") }'
}


rm -rf  metadata_release_8d.patch2{,.freeze,.freeze_approved}.{json,tsv}
rm -rf  motif_infos{,.freeze,.freeze_approved}.tsv
rm -rf  /home_local/vorontsovie/greco-motifs/motifs_{freeze,freeze_approved}
rm -rf  /home_local/vorontsovie/greco-data/datasets_{freeze,freeze_approved}

ruby postprocessing/fix_metadata_8d_patch2.rb > metadata_release_8d.patch2.json

metadata_tsv metadata_release_8d.patch2.json > metadata_release_8d.patch2.tsv

ruby postprocessing/final_motif_list.rb  /home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+8_fix+9/  metadata_release_8d.patch2.tsv > motif_infos.tsv

##############################

ruby postprocessing/metadata_freeze.rb  source_data_meta/shared/explicit_freeze1.tsv  metadata_release_8d.patch2.json > metadata_release_8d.patch2.freeze.json
metadata_tsv metadata_release_8d.patch2.freeze.json > metadata_release_8d.patch2.freeze.tsv

ruby postprocessing/motifs_freeze.rb  \
    source_data_meta/shared/explicit_freeze1.tsv  motif_infos.tsv \
    /home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+8_fix+9/ \
    /home_local/vorontsovie/greco-motifs/motifs_freeze \
  > motif_infos.freeze.tsv

ruby postprocessing/datasets_freeze.rb source_data_meta/shared/explicit_freeze1.tsv  /home_local/vorontsovie/greco-data/datasets_freeze

##############################

ruby postprocessing/metadata_freeze.rb  source_data_meta/shared/explicit_freeze1_approved.tsv  metadata_release_8d.patch2.json > metadata_release_8d.patch2.freeze_approved.json
metadata_tsv metadata_release_8d.patch2.freeze_approved.json > metadata_release_8d.patch2.freeze_approved.tsv

ruby postprocessing/motifs_freeze.rb  \
    source_data_meta/shared/explicit_freeze1_approved.tsv  motif_infos.tsv \
    '/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+8_fix+9/' \
    '/home_local/vorontsovie/greco-motifs/motifs_freeze_approved' \
  > motif_infos.freeze_approved.tsv

ruby postprocessing/datasets_freeze.rb source_data_meta/shared/explicit_freeze1_approved.tsv  /home_local/vorontsovie/greco-data/datasets_freeze_approved

##############################
rm freeze/benchmarks/*.log
rm freeze/benchmarks/*@disallow-artifacts.json
rm freeze/benchmarks/*@disallow-artifacts_ETS-only.json
mv freeze/benchmarks/metrics@7e+8c_pack_1-9.freeze-approved@disallow-artifacts_ETS-refined.json freeze/benchmarks/metrics.freeze-approved.json
mv freeze/benchmarks/metrics@7e+8c_pack_1-9.freeze@disallow-artifacts_ETS-refined.json freeze/benchmarks/metrics.freeze.json
mv freeze/benchmarks/ranks@7e+8c_pack_1-9.freeze-approved@disallow-artifacts_ETS-refined.json freeze/benchmarks/ranks.freeze-approved.json
mv freeze/benchmarks/ranks@7e+8c_pack_1-9.freeze@disallow-artifacts_ETS-refined.json freeze/benchmarks/ranks.freeze.json
mv /home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/final_formatted/heatmaps@7e+8c_pack_1-8.freeze-approved@disallow-artifacts_ETS-refined/  /home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/final_formatted/heatmaps.freeze-approved/
mv /home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/final_formatted/heatmaps@7e+8c_pack_1-8.freeze@disallow-artifacts_ETS-refined/  /home_local/vorontsovie/greco-bit-data-processing/benchmarks/release_8d/final_formatted/heatmaps.freeze/
mv freeze/metadata_release_8d.patch2.freeze.json freeze/datasets_metadata.freeze.json
mv freeze/metadata_release_8d.patch2.freeze_approved.json freeze/datasets_metadata.freeze-approved.json
mv freeze/metadata_release_8d.patch2.freeze.tsv freeze/datasets_metadata.freeze.tsv
mv freeze/metadata_release_8d.patch2.freeze_approved.tsv freeze/datasets_metadata.freeze-approved.tsv
mv freeze/metadata_release_8d.patch2.json freeze/datasets_metadata.full.json
mv freeze/metadata_release_8d.patch2.tsv freeze/datasets_metadata.full.tsv

##############################

ln --no-target-directory -s /home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+8_fix+9/ freeze/all_motifs

ruby postprocessing/fix_tf_names_codebook_bug.rb

# mkdir -p freeze_recalc_backups/
# mv freeze_recalc/ freeze_recalc_for_benchmark freeze_recalc_integrated/ freeze_recalc_backups/

mkdir -p freeze_recalc_for_benchmark/all_motifs
for TF in TIGD4 TIGD5; do
  for FN in $(find freeze_recalc/all_motifs -xtype f -name "${TF}.*"); do
    ln -s $(readlink -m $FN) freeze_recalc_for_benchmark/all_motifs/
  done
done

mkdir -p freeze_recalc_for_benchmark/datasets_freeze
for DATATYPE in CHS GHTS.Peaks GHTS.Reads HTS PBM.QNZS PBM.SD PBM.SDQN SMS; do
  DATATYPE_FOR_BENCHMARK=${DATATYPE/GHTS/AFS}
  mkdir -p freeze_recalc_for_benchmark/datasets_freeze/${DATATYPE_FOR_BENCHMARK}
  for SLICE in $(find freeze_recalc/datasets_freeze/${DATATYPE}/ -maxdepth 1 -mindepth 1 -xtype d -print0 | xargs -0 -n1 basename ); do
    SLICE_FOR_BENCHMARK=${SLICE/Test_/Val_}
    mkdir -p freeze_recalc_for_benchmark/datasets_freeze/${DATATYPE_FOR_BENCHMARK}/${SLICE_FOR_BENCHMARK}
    for TF in TIGD4 TIGD5; do
      for FN in $(find freeze_recalc/datasets_freeze/${DATATYPE}/${SLICE} -xtype f -name "${TF}.*"); do
        ln -s $(readlink -m $FN) freeze_recalc_for_benchmark/datasets_freeze/${DATATYPE_FOR_BENCHMARK}/${SLICE_FOR_BENCHMARK}
      done
    done
  done
done

mkdir -p freeze_recalc_for_benchmark/benchmarks
# here one should run benchmarks for missing datasets (see motif_metrics.sh)
mv freeze_recalc_for_benchmark/benchmarks freeze_recalc_for_benchmark/benchmarks_1

mkdir -p freeze_recalc_for_benchmark/benchmarks
ruby postprocessing/fix_tf_names_codebook_bug-stage-2.rb  # rename motifs/datasets in benchmark + collect TFs to recalc once again
# here one should run benchmarks for the rest of the missing datasets (see motif_metrics.sh)
mv freeze_recalc_for_benchmark/benchmarks freeze_recalc_for_benchmark/benchmarks_2

###

# here one can (and should) run reformat_metrics and so on (see motif_metrics.sh)

##############################

metadata_tsv freeze_recalc_integrated/datasets_metadata.full.json > freeze_recalc_integrated/datasets_metadata.full.tsv
metadata_tsv freeze_recalc_integrated/datasets_metadata.freeze.json > freeze_recalc_integrated/datasets_metadata.freeze.tsv
metadata_tsv freeze_recalc_integrated/datasets_metadata.freeze-approved.json > freeze_recalc_integrated/datasets_metadata.freeze-approved.tsv

ruby postprocessing/final_motif_list.rb  \
    freeze_recalc_integrated/all_motifs  \
    freeze_recalc_integrated/datasets_metadata.full.tsv  \
  > freeze_recalc_integrated/motif_infos.tsv

ruby postprocessing/motifs_freeze.rb  \
    source_data_meta/shared/explicit_freeze1.tsv  \
    freeze_recalc_integrated/motif_infos.tsv \
    freeze_recalc_integrated/all_motifs/ \
    freeze_recalc_integrated/motifs_freeze/ \
  > freeze_recalc_integrated/motif_infos.freeze.tsv

ruby postprocessing/motifs_freeze.rb  \
    source_data_meta/shared/explicit_freeze1_approved.tsv  \
    freeze_recalc_integrated/motif_infos.tsv \
    freeze_recalc_integrated/all_motifs/ \
    freeze_recalc_integrated/motifs_freeze_approved/ \
  > freeze_recalc_integrated/motif_infos.freeze_approved.tsv

##############################
time ruby postprocessing/make_artifacts_annotation.rb \
                freeze_recalc_integrated/motif_artifacts_annotation.freeze.tsv \
                freeze_recalc_integrated/motif_infos.freeze.tsv \
                benchmarks/prerelease_recalc/ranks@prerelease_recalc.core.freeze@disallow-artifacts_ETS-refined.json


# # Error: ↓ here we should use full ranks file (with artifacts retained)
# time ruby postprocessing/mark_artifact_datasets.rb \
#                   freeze/benchmarks/dataset_artifact_metrics_min_quantile.freeze.json \
#                   freeze/benchmarks/dataset_artifact_metrics_num_in_q25.freeze.json \
#                   freeze/benchmarks/ranks.freeze.json

# # # Error: ↓ here we should use full ranks file (with artifacts retained)
# time ruby postprocessing/mark_artifact_datasets.rb \
#                   freeze/benchmarks/dataset_artifact_metrics_min_quantile.freeze-approved.json \
#                   freeze/benchmarks/dataset_artifact_metrics_num_in_q25.freeze-approved.json \
#                   freeze/benchmarks/ranks.freeze-approved.json

# time ruby dataset_pvalues_new.rb

ruby postprocessing/motif_basic_stats.rb freeze_recalc_integrated/motifs_freeze > freeze_recalc_integrated/motif_stats.tsv

######################################

rm -r freeze_recalc_final/
mkdir -p freeze_recalc_final/{metadata,ranks,metrics,benchmarks_formatted,heatmaps,heatmap_precursors}
ln -s $(readlink -m freeze_recalc_integrated/*.{tsv,json}) --target-directory freeze_recalc_final/metadata/
ln -s $(readlink -m freeze_recalc_integrated/{all_motifs,motifs_freeze,motifs_freeze_approved}) --target-directory freeze_recalc_final/
ln -s $(readlink -m freeze_recalc_integrated/{datasets_freeze,datasets_freeze_approved}) --target-directory freeze_recalc_final/
ln -s $(readlink -m hocomoco_similarities_recalc.tsv) --target-directory freeze_recalc_final/
ln -s $(readlink -m freeze_recalc_integrated/motif_artifacts_annotation.freeze.tsv) --target-directory freeze_recalc_final/

ln -s $(readlink -m freeze_recalc_integrated/benchmarks_formatted/heatmaps*) --target-directory freeze_recalc_final/heatmap_precursors/
ln -s /home_local/ivavlakul/mexrebuild2025/heatmaps.{freeze,freeze-approved} --target-directory freeze_recalc_final/heatmaps/

ln -s $(readlink -m freeze_recalc_integrated/benchmarks_formatted/*.tsv) --target-directory freeze_recalc_final/benchmarks_formatted/

ln -s $(readlink -m benchmarks/prerelease_recalc/ranks*.json) --target-directory freeze_recalc_final/ranks/
ln -s $(readlink -m benchmarks/prerelease_recalc/metrics*.json) --target-directory freeze_recalc_final/metrics/

ln -s metrics/metrics@prerelease_recalc.core.freeze-approved@disallow-artifacts_ETS-refined.json freeze_recalc_final/metrics.freeze-approved.json
ln -s metrics/metrics@prerelease_recalc.core.freeze@disallow-artifacts_ETS-refined.json freeze_recalc_final/metrics.freeze.json
ln -s ranks/ranks@prerelease_recalc.core.freeze-approved@disallow-artifacts_ETS-refined.json freeze_recalc_final/ranks.freeze-approved.json
ln -s ranks/ranks@prerelease_recalc.core.freeze@disallow-artifacts_ETS-refined.json freeze_recalc_final/ranks.freeze.json
