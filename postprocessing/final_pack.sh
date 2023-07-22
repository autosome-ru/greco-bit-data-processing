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


# require 'csv'
# motifs = File.readlines("release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7_list.txt").map(&:chomp)
# motif_datasets = motifs.map{|m| m.split('@') }.map{|tf, exp_type, datasets, tool, name| datasets }.flat_map{|ds| ds.split("+") }.uniq
# dataset_infos = CSV.readlines('metadata_release_7b+8d.patch1.tsv', headers: true, col_sep: "\t").map(&:to_h)
# dataset_infos_by_id = dataset_infos.map{|h| [h["dataset_id"], h] }.to_h
