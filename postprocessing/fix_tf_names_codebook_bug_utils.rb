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

def basename_wo_ext(fn)
  File.basename(fn, File.extname(fn))
end

def rename_motif(src_filename, dst_filename, transpose: false)
  new_motif_name = basename_wo_ext(dst_filename)
  lines = File.readlines(src_filename).map(&:chomp)
  if lines[0].start_with?('>')
    old_header = lines[0]
    lines.shift
    old_name, additional_info = old_header[1..-1].strip.split(/\s+/, 2)
    header = ">#{new_motif_name} #{additional_info}"
  else
    header = ">#{new_motif_name}"
  end

  matrix = lines.map{|l| l.strip.split(/\s+/) }
  matrix = matrix.transpose  if transpose

  write_motif(dst_filename, header, matrix)
end

def write_motif(dst_filename, header, matrix)
  File.open(dst_filename, 'w') {|fw|
    fw.puts header
    fw.puts matrix.map{|row| row.map{|x| Float(x) }.map{|x| '%.16f' % x }.join("\t") }.join("\n")
  }
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
  new_tf = rename_info['NEW TF label']

  dataset_info['experiment_meta']['plasmid'] = nil
  dataset_info['experiment_meta']['plasmid_id'] = 'unknown'
  dataset_info['construct_type'] = 'NA'

  # sometimes .experiment_meta.gene_name and .experiment_info.tf not specified
  # in these cases, we prefer not to set them
  dataset_info['experiment_meta']['gene_name'] = new_tf  if dataset_info.dig('experiment_meta', 'gene_name')
  dataset_info['experiment_info']['tf'] = new_tf  if dataset_info.dig('experiment_info', 'tf')

  old_dataset_name = dataset_info['dataset_name']
  old_tf_construct, rest_name = old_dataset_name.split('@', 2)
  old_tf, old_construct = old_tf_construct.split('.', 2)
  raise 'Old TF name mismatch'  unless rename_info['Original TF label'] == old_tf

  new_dataset_name = "#{new_tf}.NA@#{rest_name}"
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
    rename_info = renames[ dataset_info['experiment_id'] ]
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
    rename_info = renames[ dataset_info['experiment_id'] ]
    if rename_info && (rename_info['OLD CURATION'] == 'Not approved') && (rename_info['NEW CURATION'] == 'Approved')
      dataset_renamed(dataset_info, rename_info)
    else
      nil
    end
  }.compact
end

def renamed_motif_basename_by_info(motif_fn, rename_info)
  motif_bn = File.basename(motif_fn)
  old_tf_construct, rest_name = motif_bn.split('@', 2)
  old_tf, old_construct = old_tf_construct.split('.', 2)
  raise 'TF name mismatch'  unless old_tf == rename_info['Original TF label']
  new_tf = rename_info['NEW TF label']
  "#{new_tf}.NA@#{rest_name}"
end

def renamed_motif_filename_by_info(motif_fn, rename_info)
  File.join(File.dirname(motif_fn), renamed_motif_basename_by_info(motif_fn, rename_info))
end

def rename_motif_by_info(motif_fn, rename_info)
  new_motif_fn = renamed_motif_filename_by_info(motif_fn, rename_info)
  if new_motif_fn != motif_fn
    raise "#{motif_fn} not exists" if !File.exist?(motif_fn)
    raise "#{new_motif_fn} already exists" if File.exist?(new_motif_fn)
    rename_motif(motif_fn, new_motif_fn)
    FileUtils.rm(motif_fn)
  end
end

def get_dataset_ids_renames(datasets, renames)
  datasets.map{|dataset_info|
    rename_info = renames[ dataset_info['experiment_id'] ]
    [dataset_info['dataset_id'], rename_info]
  }.select{|dataset_id, rename_info|
    rename_info
  }.to_h_safe
end

# It doesn't matter if datasets is original or renamed (because we take TF name from renames, not from datasets)
def motif_pack_rename(motif_folder, datasets, renames)
  dataset_ids_renames = get_dataset_ids_renames(datasets, renames)

  motif_renames = Dir.glob("#{motif_folder}/*").map{|fn|
    renames_for_motif = dataset_ids_by_motif_fn(fn).map{|dataset_id| dataset_ids_renames[dataset_id] }.compact.uniq
    if renames_for_motif.size > 1
      raise "Mismatch in motif renames"
    elsif renames_for_motif.size == 0
      nil
    else
      [fn, renames_for_motif.take_the_only]
    end
  }.compact

  motif_renames.each{|motif_fn, rename_info| rename_motif_by_info(motif_fn, rename_info) }
end

def dataset_ids_by_motif_fn(motif_fn)
  File.basename(motif_fn).split('@')[2].split('+')
end

def store_jsonl(filename, records)
  File.open(filename, 'w'){|fw| records.each{|record| fw.puts(record.to_json) } }
end

def copy_files(rename_pairs, symlink: false)
  rename_pairs.map{|old_fn, new_fn| File.dirname(new_fn) }.uniq.each{|dn| FileUtils.mkdir_p(dn) }

  rename_pairs.each{|old_fn, new_fn|
    if symlink
      old_fn_resolved = (File.symlink?(old_fn) ? File.readlink(old_fn) : old_fn).then{|fn| File.realpath(fn) }
      FileUtils.ln_s(old_fn_resolved, new_fn)
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
