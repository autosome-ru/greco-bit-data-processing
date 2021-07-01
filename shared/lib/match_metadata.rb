require_relative 'index_by'

def unique_samples_by(samples, warnings: true, &block)
  bad_samples = samples.reject_unique_by(&block)
  if warnings && !bad_samples.empty?
    $stderr.puts("Rejected sample not unique by experiment_id:")  if !bad_samples.empty?
    bad_samples.sort_by(&block).each{|sample| $stderr.puts(sample) }
  end
  samples.select_unique_by(&block)
end

def unique_samples(samples, warnings: true)
  unique_samples_by(samples, warnings: true, &:experiment_id)
end

def unique_metadata_by(metadata, warnings: true, &block)
  bad_metadata = metadata.reject_unique_by(&block)
  if warnings && !bad_metadata.empty?
    $stderr.puts("Rejected not unique sample metadata:")  if !bad_metadata.empty?
    bad_metadata.sort_by(&block).each{|sample_metadata| $stderr.puts(sample_metadata) }
  end
  metadata.select_unique_by(&block)
end


def unique_metadata(metadata, warnings: true)
  bad_metadata = unique_metadata_by(metadata, warnings: warnings, &:experiment_id)
end

def report_mismatches_triples_by_filenames(samples, metadata, metadata_keys)
  sample_keyproc = ->(smp){ File.basename(smp.filename) }

  samples_wo_meta = metadata_keys.map{|meta_key|
    meta_keyproc = ->(meta){ meta.send(meta_key) }
    left_unjoined_by(samples, metadata, key_proc_1: sample_keyproc, key_proc_2: meta_keyproc).map{|k, sample| sample }
  }.reduce(&:&)

  samples_wo_meta.each{|sample|
    $stderr.puts "Sample `#{sample}` has no metadata"
  }
  ######
  meta_wo_samples = metadata_keys.flat_map{|meta_key|
    meta_keyproc = ->(meta){ meta.send(meta_key) }
    right_unjoined_by(samples, metadata, key_proc_1: sample_keyproc, key_proc_2: meta_keyproc).map{|k,meta| {meta: meta, meta_key: meta_key, key: k} }
  }

  meta_wo_samples.each{|info|
    $stderr.puts "Metadata `#{info[:meta].experiment_id}` has no matching file for key #{info[:meta_key]} = `#{info[:key]}`"
  }
  ######
  {samples_wo_meta: samples_wo_meta, meta_wo_samples: meta_wo_samples}
end

def match_triples_by_filenames(samples, metadata, metadata_keys)
  sample_keyproc = ->(smp){ File.basename(smp.filename) }

  metadata_keys.flat_map{|meta_key|
    meta_keyproc = ->(meta){ meta.send(meta_key) }
    inner_join_by(samples, metadata, key_proc_1: sample_keyproc, key_proc_2: meta_keyproc)
  }
end

def report_unmatched!(samples, sample_triples)
  unmatched_samples = samples - sample_triples.map{|key, sample, sample_meta| sample }
  unmatched_samples.each{|sample|
    $stderr.puts "There is no metadata for `#{sample}`"
  }
end
