require 'csv'
require 'json'
require 'fileutils'
require 'set'

module Enumerable
  def take_the_only
    raise "Should be one element in a collection"  unless self.size == 1
    self.first
  end

  def to_h_safe
    raise "non-unique keys"  if self.size != self.map(&:first).size
    self.to_h
  end
end

def deep_copy(obj)
  Marshal.load(Marshal.dump(obj))
end

def tf_by_filename(fn)
  File.basename(fn).split('.', 2).first
end

def dataset_and_experiment_type(dataset_info)
  exp_type = dataset_info['experiment_type']
  extension = dataset_info['extension']
  processing_type = dataset_info['processing_type']
  case exp_type
  when 'CHS'
    case extension
    when 'peaks'
      dataset_type = 'intervals'
    when 'fa'
      dataset_type = 'sequences'
    else
      raise "Unknown extension #{extension}"
    end
  when 'AFS'
    exp_type = "GHTS.#{processing_type}"
    case extension
    when 'peaks'
      dataset_type = 'intervals'
    when 'fa', 'fastq'
      dataset_type = 'sequences'
    else
      raise "Unknown extension #{extension}"
    end
  when 'HTS'
    dataset_type = 'reads'
  when 'PBM'
    exp_type = "PBM.#{processing_type}"
    case extension
    when 'tsv'
      dataset_type = 'intensities'
    when 'fa'
      dataset_type = 'sequences'
    else
      raise "Unknown extension #{extension}"
    end
  when 'SMS'
    exp_type = dataset_info['source_files'][0]['filename'].match?('/old_smlseq_raw/') ? 'SMS.published' : 'SMS'
    dataset_type = 'reads'
  else
    raise "Unknown exp_type #{exp_type}"
  end
  [dataset_type, exp_type]
end

def dataset_folder(dataset_info, base_folder)
  slice_type = dataset_info['slice_type'].then{|v| (v == 'Val') ? 'Test' : v }
  dataset_type, exp_type = dataset_and_experiment_type(dataset_info)
  "#{base_folder}/#{exp_type}/#{slice_type}_#{dataset_type}"
end

def dataset_renamed(dataset_info, rename_info, move_files: false, base_folder: nil)
  dataset_info = deep_copy(dataset_info)

  dataset_info['experiment_meta']['plasmid'] = nil
  dataset_info['experiment_meta']['plasmid_id'] = 'unknown'

  old_dataset_name = dataset_info['dataset_name']
  old_tf, rest_name = old_dataset_name.split('.', 2)
  raise 'Old TF name mismatch'  unless rename_info['Original TF label'] == old_tf
  new_tf = rename_info['NEW TF label']
  new_dataset_name = "#{new_tf}.#{rest_name}"
  dataset_info['dataset_name'] = new_dataset_name
  dataset_info['tf'] = new_tf

  if move_files
    folder = dataset_folder(dataset_info, base_folder)
    old_filename = "#{folder}/#{old_dataset_name}"
    new_filename = "#{folder}/#{new_dataset_name}"

    if (new_filename != old_filename)
      raise "#{old_filename} not exists" if !File.exist?(old_filename)
      raise "#{new_filename} already exists" if File.exist?(new_filename)
      FileUtils.mv(old_filename, new_filename)
    end
  end

  dataset_info
end

def multiple_datasets_renamed(datasets, renames, move_files: false, base_folder: nil, skip_not_approved: false)
  datasets.map{|dataset_info|
    rename_info = renames[ dataset_info['experiment_meta']['experiment_id'] ]
    if !rename_info
      dataset_info
    else
      if skip_not_approved && rename_info['NEW CURATION'] == 'Not approved'
        nil
      else
        dataset_renamed(dataset_info, rename_info, move_files: move_files, base_folder: base_folder)
      end
    end
  }.compact
end

def multiple_datasets_renamed_reapproved(datasets, renames)
  datasets.map{|dataset_info|
    rename_info = renames[ dataset_info['experiment_meta']['experiment_id'] ]
    if rename_info && (rename_info['OLD CURATION'] == 'Not approved') && (rename_info['NEW CURATION'] == 'Approved')
      dataset_renamed(dataset_info, rename_info)
    else
      nil
    end
  }.compact
end

def rename_motif(motif_fn, rename_info)
  folder = File.dirname(motif_fn)
  motif_bn = File.basename(motif_fn)
  old_tf, rest_name = motif_bn.split('.', 2)
  raise 'TF name mismatch'  unless old_tf == rename_info['Original TF label']
  new_tf = rename_info['NEW TF label']
  new_motif_bn = "#{new_tf}.#{rest_name}"
  new_motif_fn = File.join(folder, new_motif_bn)
  if new_motif_fn != motif_fn
    raise "#{motif_fn} not exists" if !File.exist?(motif_fn)
    raise "#{new_motif_fn} already exists" if File.exist?(new_motif_fn)
    FileUtils.mv(motif_fn, new_motif_fn)
  end
end

# It doesn't matter if datasets is original or renamed (because we take TF name from renames, not from datasets)
def motif_pack_rename(motif_folder, datasets, renames)
  dataset_ids_renames = datasets.map{|dataset_info|
    rename_info = renames[ dataset_info['experiment_meta']['experiment_id'] ]
    [dataset_info['dataset_id'], rename_info]
  }.select{|dataset_id, rename_info|
    rename_info
  }.to_h_safe

  motif_renames = Dir.glob("#{motif_folder}/*").map{|fn|
    renames_for_motif = dataset_ids_by_motif(fn).map{|dataset_id| dataset_ids_renames[dataset_id] }.compact.uniq
    if renames_for_motif.size > 1
      raise "Mismatch in motif renames"
    elsif renames_for_motif.size == 0
      nil
    else
      [fn, renames_for_motif.take_the_only]
    end
  }.compact

  motif_renames.each{|motif_fn, rename_info| rename_motif(motif_fn, rename_info) }
end

def dataset_ids_by_motif(motif_fn)
  motif_fn.split('@')[2].split('+')
end

def store_jsonl(filename, records)
  File.open(filename, 'w'){|fw| records.each{|record| fw.puts(record.to_json) } }
end

def copy_files(rename_pairs, symlink: false)
  rename_pairs.map{|old_fn, new_fn| File.dirname(new_fn) }.uniq.each{|dn| FileUtils.mkdir_p(dn) }

  rename_pairs.each{|old_fn, new_fn|
    if symlink
      FileUtils.ln_s(old_fn, new_fn)
    else
      FileUtils.cp(old_fn, new_fn)
    end
  }
end

# info to copy files freeze → freeze_recalc
def rename_pairs_to_recalc(affected_tfs)
  rename_pairs = []
  rename_pairs += affected_tfs.flat_map{|tf|
    fns = Dir.glob("freeze/datasets_freeze/*/*/#{tf}.*")
    fns.map{|fn|
      new_fn = fn.sub(/^freeze/, 'freeze_recalc')
      [fn, new_fn]
    }
  }
  rename_pairs += affected_tfs.flat_map{|tf|
    fns = Dir.glob("freeze/all_motifs/#{tf}.*")
    fns.map{|fn|
      new_fn = fn.sub(/^freeze/, 'freeze_recalc')
      [fn, new_fn]
    }
  }
end

def recalc_integration_rename_pairs(affected_tfs)
  dataset_fns = Dir.glob("freeze/datasets_freeze/*/*/*")
  motif_fns = Dir.glob("freeze/all_motifs/*")
  fns = dataset_fns + motif_fns
  all_tfs = fns.map{|fn| tf_by_filename(fn) }.uniq

  rename_pairs = all_tfs.flat_map{|tf|
    base_folder = affected_tfs.include?(tf) ? 'freeze_recalc' : 'freeze'
    [
      *Dir.glob("#{base_folder}/datasets_freeze/*/*/#{tf}.*"),
      *Dir.glob("#{base_folder}/datasets_freeze_approved/*/*/#{tf}.*"),
      *Dir.glob("#{base_folder}/all_motifs/#{tf}.*"),
    ].map{|orig_fn|
      new_fn = orig_fn.sub(/^#{base_folder}/, 'freeze_recalc_integrated')
      [orig_fn, new_fn]
    }
  }
  rename_pairs
end


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
