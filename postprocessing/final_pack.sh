#!/usr/bin/env bash
function metadata_tsv {
  INPUT="$1"
  (
    echo -e 'dataset_id\tdataset_name\ttf\tconstruct_type\texperiment_type\texperiment_subtype\texperiment_id\treplicate\tprocessing_type\tslice_type\textension';
    cat "$INPUT"  \
      | jq -r '[.dataset_id, .dataset_name, .tf, .construct_type, .experiment_type, .experiment_subtype, .experiment_id, .experiment_params.replica, .processing_type, .slice_type, .extension] | @tsv' \
  ) | ruby -e '$stdin.each_line{|l| row = l.chomp.split("\t"); row[-2] = "Test"  if row[-2] == "Val"; puts row.join("\t") }'
}


ruby postprocessing/fix_metadata_8d_patch2.rb > metadata_release_8d.patch2.json

metadata_tsv metadata_release_8d.patch2.json > metadata_release_8d.patch2.tsv

find '/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7/' -xtype f \
  | ruby -e '$stdin.each_line{|l| puts File.basename(l.chomp) }' \
  | sort \
  > release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7_list.txt

ruby postprocessing/final_motif_list.rb  release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7_list.txt  metadata_release_8d.patch2.tsv > motif_infos.tsv

ruby postprocessing/metadata_freeze.rb  source_data_meta/shared/explicit_freeze1.tsv  metadata_release_8d.patch2.json > metadata_release_8d.patch2.freeze.json

ruby postprocessing/motifs_freeze.rb  \
    source_data_meta/shared/explicit_freeze1.tsv  motif_infos.tsv \
    '/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7/' \
    '/home_local/vorontsovie/greco-motifs/motifs_freeze' \
  > motif_infos.freeze.tsv

metadata_tsv metadata_release_8d.patch2.freeze.json > metadata_release_8d.patch2.freeze.tsv


# Dir.glob('/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7/*').select{|fn|
#   File.basename(fn)
# }