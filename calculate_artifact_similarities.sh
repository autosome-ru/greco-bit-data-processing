mkdir -p artifacts_pcm artifacts_ppm
cp artifacts/*.pcm artifacts_pcm
cp artifacts/*.ppm artifacts_ppm

ruby -rjson -e 'puts File.readlines("list_of_artifacts.txt").map(&:strip).reject(&:empty?).slice_before(/Artifact/).map{|h,*rest| [h,rest] }.to_h.to_json' > artifacts/artifacts.json

mkdir -p artifact_sims_precise
time for ARTIFACT_MOTIF_TYPE in pcm ppm ; do
    for MOTIF_TYPE in pcm ppm; do
        # for FN in $(find ~/greco-motifs/release_8c.pack_7/ -xtype f -iname "*.${MOTIF_TYPE}"); do
        for FN in $(find ~/greco-motifs/release_8c.pack_9/ -xtype f -iname "*.${MOTIF_TYPE}"); do
        # for FN in $(find release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7/ -xtype f -iname "*.${MOTIF_TYPE}"); do
            BN=$(basename "$FN")
            echo java -Xmx2G -cp ape.jar ru.autosome.macroape.ScanCollection \
                ${FN} ~/greco-bit-data-processing/artifacts_${ARTIFACT_MOTIF_TYPE} \
            --query-${MOTIF_TYPE} --collection-${ARTIFACT_MOTIF_TYPE} --all \
            --rough-discretization 10 --precise 100500" | fgrep -v '#' " '>>' artifact_sims_precise/${BN}
        done | pv -l | parallel -j 200
    done
done

mv  heatmaps_weightedTau+cross-PBM+allow-artifacts_no-afs-reads  heatmaps_weightedTau+cross-PBM+allow-artifacts_no-afs-reads_old_p8
mv  heatmaps_weightedTau+cross-PBM+dropped-artifacts_no-afs-reads  heatmaps_weightedTau+cross-PBM+dropped-artifacts_no-afs-reads_old_p8
time python3 generate_heatmaps.py  heatmaps_weightedTau+cross-PBM+allow-artifacts_no-afs-reads  benchmarks/release_8d/ranks_7e+8c_pack_1-6_wo_bad_crosspbm_allow-artifact_no-afs-reads.json
time python3 generate_heatmaps.py  heatmaps_weightedTau+cross-PBM+dropped-artifacts_no-afs-reads  benchmarks/release_8d/ranks_7e+8c_pack_1-6_wo_bad_crosspbm_artifact_no-afs-reads.json

time ruby mark_artifact_datasets.rb benchmarks/release_8d/dataset_artifact_metrics_min_quantile_crosspbm_allow-artifact_no-afs-reads.json \
									benchmarks/release_8d/dataset_artifact_metrics_num_in_q25_crosspbm_allow-artifact_no-afs-reads.json \
									benchmarks/release_8d/ranks_7e+8c_pack_1+2+3+4+5+6_wo_bad_crosspbm_allow-artifact_no-afs-reads.json

# ruby mark_artifact_datasets.rb  benchmarks/release_8d/dataset_artifact_metrics_min_quantile_crosspbm_artifact_no-afs-reads.json  benchmarks/release_8d/dataset_artifact_metrics_num_in_q25_crosspbm_artifact_no-afs-reads.json  benchmarks/release_8d/ranks_7e+8c_pack_1+2+3+4+5_crosspbm_artifact_no-afs-reads.json

# time ruby postprocessing/correct_ranks_and_metrics_restore_dropped_artifacts.rb
time ruby dataset_pvalues_new.rb
