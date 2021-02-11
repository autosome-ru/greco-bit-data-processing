require 'parallel'
require 'fileutils'
require_relative 'train_val_split'
require_relative 'dataset_naming'

module ReadsProcessing
  # processing_module = SMSPublished / SMSUnpublished
  def self.process!(processing_module, results_folder, sample_triples, barcode_proc, num_threads: 1)
    verify_sample_triples!(processing_module, sample_triples)

    ds_naming = ReadsProcessing::DatasetNaming.new(results_folder, barcode_proc: barcode_proc)
    ds_naming.create_folders!

    Parallel.each(sample_triples, in_processes: num_threads) do |experiment_id, sample, sample_metadata|
      train_fn = ds_naming.train_filename(sample_metadata, uuid: take_dataset_name!, cycle: sample.cycle)
      val_fn = ds_naming.validation_filename(sample_metadata, uuid: take_dataset_name!, cycle: sample.cycle)
      train_val_split(sample.filename, train_fn, val_fn)
    end

    ReadsProcessing.generate_samples_stats(processing_module::SampleMetadata, ds_naming, sample_triples)
  end

  # matcher is any object with `match_metadata?` method. E.g. SMSPublished / SMSUnpublished
  def self.verify_sample_triples!(matcher, sample_triples)
    sample_triples.each{|key, sample, sample_metadata|
      $stderr.puts("No metadata for `#{key}`")  if sample_metadata.nil?
      $stderr.puts("No sample for `#{key}`")  if sample.nil? # Impossible
      unless matcher.match_metadata?(sample, sample_metadata)
        $stderr.puts("Sample #{sample} doesn't match metadata #{sample_metadata}")
      end
    }
  end
end
