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

def rename_dataset(dataset_info, rename_info, move_files: false, base_folder: )
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

  folder = dataset_folder(dataset_info, base_folder)
  old_filename = "#{folder}/#{old_dataset_name}"
  new_filename = "#{folder}/#{new_dataset_name}"

  if move_files && (new_filename != old_filename)
    raise "#{old_filename} not exists" if !File.exist?(old_filename)
    raise "#{new_filename} already exists" if File.exist?(new_filename)
    FileUtils.mv(old_filename, new_filename)
  end

  dataset_info
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

FileUtils.rm_rf('freeze_recalc')

renames = CSV.foreach('source_data_meta/fixes/CODEGATE_DatasetsSwap.txt', col_sep: "\t", headers: true).map(&:to_h).map{|row|
  #  "THC_0361.Rep-DIANA_0293,THC_0361.Rep-MICHELLE_0314" → THC_0361
  id = row['MEX Dataset ID(s)'].split(',').map{|v| v.split('.').first }.uniq.take_the_only
  [id, row]
}.to_h_safe


affected_tfs = renames.flat_map{|exp_id, rename_info| rename_info.values_at('Original TF label', 'NEW TF label') }.uniq
# copy files freeze → freeze_recalc

rename_pairs = []
rename_pairs += affected_tfs.flat_map{|tf|
  fns = Dir.glob("freeze/datasets_freeze/*/*/#{tf}.*")
  fns.map{|fn|
    new_fn = fn.sub(/^freeze/, 'freeze_recalc')
    [fn, new_fn]
  }
}
rename_pairs += affected_tfs.flat_map{|tf|
  fns = Dir.glob("freeze/motifs_freeze/#{tf}.*")
  fns.map{|fn|
    new_fn = fn.sub(/^freeze/, 'freeze_recalc')
    [fn, new_fn]
  }
}

rename_pairs.map{|old_fn, new_fn| File.dirname(new_fn) }.uniq.each{|dn| FileUtils.mkdir_p(dn) }

rename_pairs.each{|old_fn, new_fn|
  FileUtils.cp(old_fn, new_fn)
}

datasets          = File.readlines('freeze/datasets_metadata.freeze.json').map{|l| JSON.parse(l) }
datasets_approved = File.readlines('freeze/datasets_metadata.freeze-approved.json').map{|l| JSON.parse(l) }

datasets_renamed = datasets.map{|dataset_info|
  rename_info = renames[ dataset_info['experiment_meta']['experiment_id'] ]
  if !rename_info
    dataset_info
  else
    rename_dataset(dataset_info, rename_info, base_folder: "freeze_recalc/datasets_freeze", move_files: true)
  end
}


datasets_approved_renamed = datasets_approved.map{|dataset_info|
  rename_info = renames[ dataset_info['experiment_meta']['experiment_id'] ]
  if !rename_info
    dataset_info
  elsif rename_info['NEW CURATION'] == 'Not approved'
    nil
  else
    rename_dataset(dataset_info, rename_info, base_folder: "freeze_recalc/datasets_freeze_approved", move_files: false)
  end
}.compact

datasets_approved_addition = datasets.map{|dataset_info|
  rename_info = renames[ dataset_info['experiment_meta']['experiment_id'] ]
  if rename_info && (rename_info['OLD CURATION'] == 'Not approved') && (rename_info['NEW CURATION'] == 'Approved')
    rename_dataset(dataset_info, rename_info, base_folder: "freeze_recalc/datasets_freeze_approved", move_files: false)
  else
    nil
  end
}.compact

datasets_approved_renamed += datasets_approved_addition


datasets_approved_renamed.select{|dataset_info|
  affected_tfs.include?( dataset_info['tf'] )
}.each{|dataset_info|
  dataset_name = dataset_info['dataset_name']
  folder = dataset_folder(dataset_info, "freeze_recalc/datasets_freeze")
  new_folder = dataset_folder(dataset_info, "freeze_recalc/datasets_freeze_approved")
  filename = "#{folder}/#{dataset_name}"
  new_filename = "#{new_folder}/#{dataset_name}"
  FileUtils.cp(filename, new_filename)
}


approved_ids = datasets_approved_renamed.map{|dataset_info| dataset_info['dataset_id'] }.to_set

datasets_approved_renamed.each{|dataset_info|
  raise "Shouldn't be here"  unless approved_ids.include?(dataset_info['dataset_id'])
  dataset_info['approved'] = true
}
datasets_renamed.each{|dataset_info|
  dataset_info['approved'] = approved_ids.include?(dataset_info['dataset_id'])
}


File.open('freeze_recalc/datasets_metadata.freeze.json', 'w'){|fw|
  datasets_renamed.each{|dataset_info|
    fw.puts(dataset_info.to_json)
  }
}

File.open('freeze_recalc/datasets_metadata.freeze-approved.json', 'w'){|fw|
  datasets_approved_renamed.each{|dataset_info|
    fw.puts(dataset_info.to_json)
  }
}

# motif_pack_rename('freeze_recalc/motifs_freeze', datasets, renames)
# motif_pack_rename('freeze_recalc/motifs_freeze_approved', datasets_approved, renames)
