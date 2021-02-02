require_relative 'process_reads_HTS_SMS_AFS/reads_processing'
require_relative 'process_reads_HTS_SMS_AFS/sms_published'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'process_reads_HTS_SMS_AFS/hts'

def unique_samples(samples, warnings: true)
  bad_samples = samples.reject_unique_by(&:experiment_id)
  if warnings && !bad_sample.empty?
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

def process_sms_unpublished!
  $stderr.puts "Process unpublished SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/unpublished/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
  barcodes_fn = "source_data_meta/SMS/unpublished/smileseq_barcode_file.txt"
  samples_glob = "source_data/SMS/reads/unpublished/*.fastq"
  results_folder = "source_data_prepared/SMS/unpublished/reads/"

  barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }

  samples = Dir.glob(samples_glob).map{|fn| SMSUnpublished::Sample.from_filename(fn) }
  metadata = SMSUnpublished::SampleMetadata.each_in_file(metadata_fn).to_a
  samples = unique_samples(samples)
  metadata = unique_metadata(metadata)

  ReadsProcessing.process!(SMSUnpublished, results_folder, samples, metadata, barcode_proc, num_threads: 20)
end

def process_sms_published!
  $stderr.puts "Process published SMiLE-seq data"

  metadata_fn = "source_data_meta/SMS/published/SMS_published.tsv"
  barcodes_fn = "source_data_meta/SMS/published/Barcode_sequences.txt"
  samples_glob = "source_data/SMS/reads/published/*.fastq"
  results_folder = "source_data_prepared/SMS/published/reads/"

  barcodes = SMSPublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }

  samples = Dir.glob(samples_glob).map{|fn| SMSPublished::Sample.from_filename(fn) }
  metadata = SMSPublished::SampleMetadata.each_in_file(metadata_fn).to_a
  samples = unique_samples(samples)
  metadata = unique_metadata(metadata)

  ReadsProcessing.process!(SMSPublished, results_folder, samples, metadata, barcode_proc, num_threads: 20)
end

def process_hts!
  $stderr.puts "Process HT-SELEX data"
  metadata_fn = "source_data_meta/HTS/HTS.tsv"
  samples_glob = "source_data/HTS/reads/*.fastq.gz"
  results_folder = "source_data_prepared/HTS/reads/"

  barcode_proc = ->(sample_metadata){ sample_metadata.barcode }

  samples = Dir.glob(samples_glob).map{|fn| Selex::Sample.from_filename(fn) }
  metadata = Selex::SampleMetadata.each_in_file(metadata_fn).to_a

  ReadsProcessing.process!(Selex, results_folder, samples, metadata, barcode_proc, num_threads: 20)
end

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

process_sms_unpublished!
process_sms_published!
process_hts!
