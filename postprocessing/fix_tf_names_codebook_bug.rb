require 'csv'
require 'json'
require 'fileutils'
require 'set'
require_relative 'fix_tf_names_codebook_bug_utils.rb'

FileUtils.rm_rf('freeze_recalc')
FileUtils.rm_rf('freeze_recalc_integrated')
FileUtils.mkdir_p('freeze_recalc')
FileUtils.mkdir_p('freeze_recalc_integrated')

renames = CSV.foreach('source_data_meta/fixes/CODEGATE_DatasetsSwap.txt', col_sep: "\t", headers: true).map(&:to_h).map{|row|
  #  "THC_0361.Rep-DIANA_0293,THC_0361.Rep-MICHELLE_0314" → THC_0361
  id = row['MEX Dataset ID(s)'].split(',').map{|v| v.split('.').first }.uniq.take_the_only
  [id, row]
}.to_h_safe

affected_tfs = renames.flat_map{|exp_id, rename_info| rename_info.values_at('Original TF label', 'NEW TF label') }.uniq

# copy affected TF-related files from `datasets_freeze` and `all_motifs` into corresponding folders in `freeze_recalc`
copy_files(rename_pairs_to_recalc(affected_tfs))

datasets_freeze   = File.readlines('freeze/datasets_metadata.freeze.json').map{|l| JSON.parse(l) }
datasets_full     = File.readlines('freeze/datasets_metadata.full.json').map{|l| JSON.parse(l) }
datasets_approved = File.readlines('freeze/datasets_metadata.freeze-approved.json').map{|l| JSON.parse(l) }

# inside freeze_recalc folder move datasets with wrong TF names (they will reside in the same folder)
datasets_freeze_renamed = multiple_datasets_renamed(datasets_freeze, renames, move_files: true, base_folder: "freeze_recalc/datasets_freeze")

# we don't collect files for non-freeze datasets, only metadata, so no copying
datasets_full_renamed = multiple_datasets_renamed(datasets_full, renames)

# we collect files for new `freeze-approved` by copying from new `freeze` folder
# (not from old `freeze-approved` because some datasets were re-approved)
datasets_approved_renamed = [
  *multiple_datasets_renamed(datasets_approved, renames, skip_not_approved: true),
  *multiple_datasets_renamed_reapproved(datasets_freeze, renames),
]

approved_datasets_rename_pairs = datasets_approved_renamed.select{|dataset_info|
  affected_tfs.include?( dataset_info['tf'] )
}.map{|dataset_info|
  folder = dataset_folder(dataset_info, "freeze_recalc/datasets_freeze")
  new_folder = dataset_folder(dataset_info, "freeze_recalc/datasets_freeze_approved")
  dataset_name = dataset_info['dataset_name']
  [File.join(folder, dataset_name), File.join(new_folder, dataset_name)]
}

copy_files(approved_datasets_rename_pairs)

# Finalize metadata
in_freeze_ids = datasets_full_renamed.map{|dataset_info| dataset_info['dataset_id'] }.to_set
approved_ids = datasets_approved_renamed.map{|dataset_info| dataset_info['dataset_id'] }.to_set

[*datasets_approved_renamed, *datasets_freeze_renamed, *datasets_full_renamed].each do |dataset_info|
  dataset_info['in_freeze'] = in_freeze_ids.include?(dataset_info['dataset_id'])
  dataset_info['approved'] = approved_ids.include?(dataset_info['dataset_id'])
end

store_jsonl('freeze_recalc_integrated/datasets_metadata.freeze.json', datasets_freeze_renamed)
store_jsonl('freeze_recalc_integrated/datasets_metadata.freeze-approved.json', datasets_approved_renamed)
store_jsonl('freeze_recalc_integrated/datasets_metadata.full.json', datasets_full_renamed)

# Rename motifs in freeze_recalc
motif_pack_rename('freeze_recalc/all_motifs', datasets_freeze, renames) # freeze and freeze_approved motifs will be generated later

# Integrate datasets and motifs from freeze and freeze_recalc folders into freeze_recalc_integrated
copy_files(recalc_integration_rename_pairs(affected_tfs), symlink: true)
