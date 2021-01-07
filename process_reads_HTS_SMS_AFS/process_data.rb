require_relative 'reads_processing'
require_relative 'sms_published'
require_relative 'sms_unpublished'

def process_sms_unpublished!
  $stderr.puts "Process unpublished SMiLE-seq data"
  source_folder = 'source_data_smileseq/unpublished'
  metadata_fn = "#{source_folder}/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
  barcodes_fn = "#{source_folder}/smileseq_barcode_file.txt"
  samples_glob = "#{source_folder}/smileseq_raw/*.fastq"

  ReadsProcessing.process!(SMSUnpublished, samples_glob, metadata_fn, barcodes_fn, num_threads: 20)
end

def process_sms_published!
  $stderr.puts "Process published SMiLE-seq data"
  source_folder = 'source_data_smileseq/published'
  metadata_fn = "#{source_folder}/SMiLE_seq_metadata_temp_17DEC2020_publishedData.tsv"
  barcodes_fn = "#{source_folder}/Barcode_sequences.txt"
  samples_glob = "#{source_folder}/smileseq_raw/*.fastq"

  ReadsProcessing.process!(SMSPublished, samples_glob, metadata_fn, barcodes_fn, num_threads: 20)
end

process_sms_unpublished!
process_sms_published!
