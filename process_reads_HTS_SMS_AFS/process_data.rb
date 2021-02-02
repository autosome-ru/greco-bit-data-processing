require_relative 'reads_processing'
require_relative 'sms_published'
require_relative 'sms_unpublished'
require_relative 'hts'

def process_sms_unpublished!
  $stderr.puts "Process unpublished SMiLE-seq data"
  source_folder = 'source_data/SMS/reads/unpublished'
  metadata_fn = "#{source_folder}/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
  barcodes_fn = "#{source_folder}/smileseq_barcode_file.txt"
  samples_glob = "#{source_folder}/smileseq_raw/*.fastq"

  barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }
  ReadsProcessing.process!(SMSUnpublished, "source_data_prepared/SMS/unpublished/reads/", samples_glob, metadata_fn, barcode_proc, num_threads: 20)
end

def process_sms_published!
  $stderr.puts "Process published SMiLE-seq data"
  source_folder = 'source_data/SMS/reads/published'
  metadata_fn = "#{source_folder}/SMiLE_seq_metadata_temp_17DEC2020_publishedData.tsv"
  barcodes_fn = "#{source_folder}/Barcode_sequences.txt"
  samples_glob = "#{source_folder}/smileseq_raw/*.fastq"

  barcodes = SMSPublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }
  ReadsProcessing.process!(SMSPublished, "source_data_prepared/SMS/published/reads/", samples_glob, metadata_fn, barcode_proc, num_threads: 20)
end

def process_hts!
  $stderr.puts "Process HT-SELEX data"
  metadata_fn = "shared/source_data_HTS/HTS.tsv"
  barcodes_fn = nil
  samples_glob = "source_data/HTS/reads/*.fastq.gz"

  barcode_proc = ->(sample_metadata){ sample_metadata.barcode }
  ReadsProcessing.process!(Selex, "source_data_prepared/HTS/reads/", samples_glob, metadata_fn, barcode_proc, num_threads: 20)
end

plasmids_metadata = PlasmidMetadata.each_in_file('shared/source_data/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

process_sms_unpublished!
process_sms_published!
process_hts!
