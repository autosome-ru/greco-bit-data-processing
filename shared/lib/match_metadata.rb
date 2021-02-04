require_relative 'index_by'

def unique_samples(samples, warnings: true)
  bad_samples = samples.reject_unique_by(&:experiment_id)
  if warnings && !bad_samples.empty?
    $stderr.puts("Rejected sample not unique by experiment_id:")  if !bad_samples.empty?
    bad_samples.sort_by(&:experiment_id).each{|sample| $stderr.puts(sample) }
  end
  samples.select_unique_by(&:experiment_id)
end

def unique_metadata(metadata, warnings: true)
  bad_metadata = metadata.reject_unique_by(&:experiment_id)
  if warnings && !bad_metadata.empty?
    $stderr.puts("Rejected sample metadata not unique by experiment_id:")  if !bad_metadata.empty?
    bad_metadata.sort_by(&:experiment_id).each{|sample_metadata| $stderr.puts(sample_metadata) }
  end
  metadata.select_unique_by(&:experiment_id)
end

def match_triples_by_filenames(samples, metadata, metadata_keys)
  sample_triples = metadata_keys.flat_map{|meta_key|
    inner_join_by(
      samples, metadata,
      key_proc_1: ->(smp){ File.basename(smp.filename) },
      key_proc_2: ->(meta){ meta.send(meta_key)}
    )
  }
end

def report_unmatched!(samples, sample_triples)
  unmatched_samples = samples - sample_triples.map{|key, sample, sample_meta| sample }
  unmatched_samples.each{|sample|
    $stderr.puts "There is no metadata for `#{sample}`"
  }
end
