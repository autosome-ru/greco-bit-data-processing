require_relative 'process_reads_HTS_SMS_AFS/reads_processing'
require_relative 'process_reads_HTS_SMS_AFS/sms_published'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'process_reads_HTS_SMS_AFS/hts'

def process_sms_unpublished!
  $stderr.puts "Process unpublished SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/unpublished/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
  barcodes_fn = "source_data_meta/SMS/unpublished/smileseq_barcode_file.txt"
  samples_glob = "source_data/SMS/reads/unpublished/*.fastq"
  results_folder = "source_data_prepared/SMS/unpublished/reads/"

  barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }
  ReadsProcessing.process!(SMSUnpublished, results_folder, samples_glob, metadata_fn, barcode_proc, num_threads: 20)
end

def process_sms_published!
  $stderr.puts "Process published SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/published/SMiLE_seq_metadata_temp_17DEC2020_publishedData.tsv"
  barcodes_fn = "source_data_meta/SMS/published/Barcode_sequences.txt"
  samples_glob = "source_data/SMS/reads/published/*.fastq"
  results_folder = "source_data_prepared/SMS/published/reads/"

  barcodes = SMSPublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }
  ReadsProcessing.process!(SMSPublished, results_folder, samples_glob, metadata_fn, barcode_proc, num_threads: 20)
end

def process_hts!
  $stderr.puts "Process HT-SELEX data"
  metadata_fn = "source_data_meta/HTS/HTS.tsv"
  samples_glob = "source_data/HTS/reads/*.fastq.gz"
  results_folder = "source_data_prepared/HTS/reads/"

  barcode_proc = ->(sample_metadata){ sample_metadata.barcode }
  ReadsProcessing.process!(Selex, results_folder, samples_glob, metadata_fn, barcode_proc, num_threads: 20)
end

plasmids_metadata = PlasmidMetadata.each_in_file('shared/source_data/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

process_sms_unpublished!
process_sms_published!
process_hts!
