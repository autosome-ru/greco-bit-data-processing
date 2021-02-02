require 'parallel'
require 'fileutils'
require_relative 'train_val_split'
require_relative 'dataset_naming'

module ReadsProcessing
  # processing_module = SMSPublished / SMSUnpublished
  def self.process!(processing_module, samples_glob, metadata_fn, barcode_proc, num_threads: 1)
    sample_filenames = Dir.glob(samples_glob)
    samples = sample_filenames.map{|fn| processing_module::Sample.from_filename(fn) }

    metadata = processing_module::SampleMetadata.each_in_file(metadata_fn).to_a

    sample_triples = ReadsProcessing.collect_sample_triples(samples, metadata)
    verify_sample_triples!(processing_module, sample_triples)

    ds_naming = ReadsProcessing::DatasetNaming.new("results_smileseq/published", barcode_proc: barcode_proc, metadata: metadata)
    ds_naming.create_folders!

    Parallel.each(sample_triples, in_processes: num_threads) do |experiment_id, sample, sample_metadata|
      train_val_split(sample.filename, ds_naming.train_filename(experiment_id), ds_naming.validation_filename(experiment_id))
    end

    ReadsProcessing.generate_samples_stats(processing_module::SampleMetadata, ds_naming, sample_triples)
  end

  def self.collect_sample_triples(samples, metadata)
    metadata_by_experiment_id = metadata.index_by(&:experiment_id)
    sample_by_experiment_id = samples.index_by(&:experiment_id)

    sample_triples = sample_by_experiment_id.map{|experiment_id, sample|
      sample_metadata = metadata_by_experiment_id[experiment_id]
      [experiment_id, sample, sample_metadata]
    }
  end

  # matcher is any object with `match_metadata?` method. E.g. SMSPublished / SMSUnpublished
  def self.verify_sample_triples!(matcher, sample_triples)
    sample_triples.each{|experiment_id, sample, sample_metadata|
      $stderr.puts("No metadata for `#{experiment_id}`")  if sample_metadata.nil?
      $stderr.puts("No sample for `#{experiment_id}`")  if sample.nil? # Impossible
      unless matcher.match_metadata?(sample, sample_metadata)
        $stderr.puts("Metadata for #{sample.experiment_id} doesn't match info in filename")
      end
    }
  end
end
