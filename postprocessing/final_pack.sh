#!/usr/bin/env bash

(
  echo -e 'dataset_name\ttf\tconstruct_type\texperiment_type\texperiment_subtype\texperiment_id\treplicate\tprocessing_type\tdataset_id\tslice_type\textension';
  cat metadata_release_8d.patch1.json \
    | jq -r '[.dataset_name, .tf, .construct_type, .experiment_type, .experiment_subtype, .experiment_id, .experiment_params.replica, .processing_type, .dataset_id, .slice_type, .extension] | @tsv' \
) > metadata_release_8d.patch1.tsv
