#!/usr/bin/env bash

(
  echo -e 'dataset_id\tdataset_name\ttf\tconstruct_type\texperiment_type\texperiment_subtype\texperiment_id\treplicate\tprocessing_type\tslice_type\textension';
  cat metadata_release_8d.patch2.json \
    | jq -r '[.dataset_id, .dataset_name, .tf, .construct_type, .experiment_type, .experiment_subtype, .experiment_id, .experiment_params.replica, .processing_type, .slice_type, .extension] | @tsv' \
) > metadata_release_8d.patch2.tsv


find '/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7/' -xtype f \
  | ruby -e '$stdin.each_line{|l| puts File.basename(l.chomp) }' \
  | sort \
  > '/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7_list.txt'

ruby postprocessing/fix_metadata_8d_patch2.rb
ruby postprocessing/final_motif_list.rb
