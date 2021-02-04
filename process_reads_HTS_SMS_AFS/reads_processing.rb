require 'parallel'
require 'fileutils'
require_relative 'train_val_split'
require_relative 'dataset_naming'

def left_join_by(collection_1, collection_2, key_proc_1: nil, key_proc_2: nil, &key_proc)
  key_proc_1 ||= key_proc
  key_proc_2 ||= key_proc
  collection_1_by_key = collection_1.index_by(&key_proc_1)
  collection_2_by_key = collection_2.index_by(&key_proc_2)
  collection_1_by_key.map{|obj_1, key|
    obj_2 = collection_2_by_key[key]
    [key, obj_1, obj_2]
  }
end

module ReadsProcessing
  # processing_module = SMSPublished / SMSUnpublished
  def self.process!(processing_module, results_folder, samples, metadata, barcode_proc, num_threads: 1)
    sample_triples = left_join_by(samples, metadata, &:experiment_id)
    verify_sample_triples!(processing_module, sample_triples)

    ds_naming = ReadsProcessing::DatasetNaming.new(results_folder, barcode_proc: barcode_proc, metadata: metadata)
    ds_naming.create_folders!

    Parallel.each(sample_triples, in_processes: num_threads) do |experiment_id, sample, sample_metadata|
      train_fn = ds_naming.train_filename(experiment_id, uuid: take_dataset_name!)
      val_fn = ds_naming.validation_filename(experiment_id, uuid: take_dataset_name!)
      train_val_split(sample.filename, train_fn, val_fn)
    end

    ReadsProcessing.generate_samples_stats(processing_module::SampleMetadata, ds_naming, sample_triples)
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
