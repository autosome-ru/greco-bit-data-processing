require_relative 'process_reads_HTS_SMS_AFS/reads_processing'
require_relative 'process_reads_HTS_SMS_AFS/sms_published'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'process_reads_HTS_SMS_AFS/hts'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/match_metadata'

def process_sms_unpublished!
  $stderr.puts "Process unpublished SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/unpublished/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
  barcodes_fn = "source_data_meta/SMS/unpublished/smileseq_barcode_file.txt"
  samples_glob = "source_data/SMS/reads/unpublished/*.fastq"
  results_folder = "source_data_prepared/SMS/reads/"

  barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }

  samples = Dir.glob(samples_glob).map{|fn| SMSUnpublished::Sample.from_filename(fn) }
  metadata = SMSUnpublished::SampleMetadata.each_in_file(metadata_fn).to_a
  samples = unique_samples(samples)
  metadata = unique_metadata_by(metadata){|meta| [meta.experiment_id, metadata.barcode_index] }

  sample_triples = left_join_by(samples, metadata,
                                key_proc_1: ->(sample){ [sample.experiment_id.split('-')[0,2].join('-'), sample.barcode_index] },
                                key_proc_2: ->(meta){ [meta.experiment_id, metadata.barcode_index] })

  ReadsProcessing.process!(SMSUnpublished, results_folder, sample_triples, barcode_proc, num_threads: 20)
end

def process_sms_published!
  $stderr.puts "Process published SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/published/SMS_published.tsv"
  barcodes_fn = "source_data_meta/SMS/published/Barcode_sequences.txt"
  samples_glob = "source_data/SMS/reads/published/*.fastq"
  results_folder = "source_data_prepared/SMS.published/reads/"

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
  results_folder = "source_data_prepared/HTS/reads/"

  barcode_proc = ->(sample_metadata){ sample_metadata.barcode }

  samples = Dir.glob(samples_glob).map{|fn| Selex::Sample.from_filename(fn) }
  metadata = Selex::SampleMetadata.each_in_file(metadata_fn).to_a

  sample_triples = match_triples_by_filenames(
    samples, metadata,
    ['cycle_1_filename', 'cycle_2_filename', 'cycle_3_filename']
  )
  report_unmatched!(samples, sample_triples)

  ReadsProcessing.process!(Selex, results_folder, sample_triples, barcode_proc, num_threads: 20)
end

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

process_sms_unpublished!
process_sms_published!
process_hts!
