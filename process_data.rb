require_relative 'process_reads_HTS_SMS_AFS/reads_processing'
require_relative 'process_reads_HTS_SMS_AFS/sms_published'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'process_reads_HTS_SMS_AFS/hts'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/match_metadata'

require_relative 'shared/lib/dataset_name_parsers'

OLD_RELEASE = '/home_local/vorontsovie/greco-data/release_7a.2021-10-14/full/'

def process_sms_unpublished!
  $stderr.puts "Process unpublished SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/unpublished/SMS.tsv"
  barcodes_fn = "source_data_meta/SMS/unpublished/smileseq_barcode_file.txt"
  samples_glob = "source_data/SMS/reads/unpublished/*.fastq"
  results_folder = "source_data_prepared/SMS/"

  barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ sample_metadata.barcode_change || barcodes[sample_metadata.barcode_index] }

  samples = Dir.glob(samples_glob).map{|fn| SMSUnpublished::Sample.from_filename(fn) }
  metadata = SMSUnpublished::SampleMetadata.each_in_file(metadata_fn).to_a

  # first key to be transformed: "UT380-502-1" --> "UT380-502". Barcode and SSID help to distinguish samples
  sample_key = ->(sample){ [sample.experiment_id.split('-')[0,2].join('-'), sample.barcode_index, sample.sequencing_id] }
  meta_key = ->(meta){ [meta.experiment_id.split('-')[0,2].join('-'), meta.barcode_index, meta.ssid] }
  samples = unique_samples_by(samples, &sample_key)
  metadata = unique_metadata_by(metadata, &meta_key)
  sample_triples = left_join_by(samples, metadata,
                                key_proc_1: sample_key,
                                key_proc_2: meta_key)

  old_datasets_glob = "#{OLD_RELEASE}/SMS/{Train,Val}_reads/*.fastq.gz"
  parser = DatasetNameParser::SMSParser.new
  old_datasets = Dir.glob(old_datasets_glob).map{|fn| parser.parse(fn) }
  old_experiments = old_datasets.map{|s| s[:experiment_id] }.uniq

  novel_sample_triples = sample_triples.reject{|k, sample, meta| old_experiments.include?(meta.experiment_id) }

  ReadsProcessing.process!(SMSUnpublished, results_folder, novel_sample_triples, barcode_proc, num_threads: 20)
end

def process_sms_published!
  $stderr.puts "Process published SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/published/SMS_published.tsv"
  barcodes_fn = "source_data_meta/SMS/published/Barcode_sequences.txt"
  samples_glob = "source_data/SMS/reads/published/*.fastq"
  results_folder = "source_data_prepared/SMS.published/"

  barcodes = SMSPublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }

  samples = Dir.glob(samples_glob).map{|fn| SMSPublished::Sample.from_filename(fn) }
  metadata = SMSPublished::SampleMetadata.each_in_file(metadata_fn).to_a
  metadata = metadata.reject{|m| m.tfs.size != 1 }
  samples = unique_samples(samples)
  metadata = unique_metadata(metadata)

  sample_triples = left_join_by(samples, metadata, &:experiment_id)

  ReadsProcessing.process!(SMSPublished, results_folder, sample_triples, barcode_proc, num_threads: 20)
end

def process_hts!
  $stderr.puts "Process HT-SELEX data"
  metadata_fn = "source_data_meta/HTS/HTS.tsv"
  samples_glob = "source_data/HTS/reads/*.fastq.gz"
  results_folder = "source_data_prepared/HTS/"

  barcode_proc = ->(sample_metadata){ sample_metadata.barcode }

  samples = Dir.glob(samples_glob).map{|fn| Selex::Sample.from_filename(fn) }
  metadata = Selex::SampleMetadata.each_in_file(metadata_fn).to_a

  metadata_keys = ['cycle_1_filename', 'cycle_2_filename', 'cycle_3_filename', 'cycle_4_filename']
  report_mismatches_triples_by_filenames(samples, metadata, metadata_keys)

  old_datasets_glob = "#{OLD_RELEASE}/HTS/{Train,Val}_reads/*.fastq.gz"
  parser = DatasetNameParser::HTSParser.new
  old_datasets = Dir.glob(old_datasets_glob).map{|fn| parser.parse(fn) }
  old_experiments = old_datasets.map{|s| s[:experiment_id] }.uniq

  sample_triples = match_triples_by_filenames(samples, metadata, metadata_keys)
  novel_sample_triples = sample_triples.reject{|k, sample, meta| old_experiments.include?(meta.experiment_id) }

  ReadsProcessing.process!(Selex, results_folder, novel_sample_triples, barcode_proc, num_threads: 20)
end

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

process_sms_unpublished!
#process_sms_published!
process_hts!
