require 'parallel'
require 'fileutils'
require_relative 'train_val_split'
require_relative '../shared/lib/index_by'

module ReadsProcessing::SMSPublished
  # Library composition:
  # ACACTCTTTCCCTACACGACGCTCTTCCGATCT - [BC-half1, 7bp e.g. BC1=CATGCTC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - [BC-half2, 7bp e.g. BC1=GAGCATG] - GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG'

  def self.read_barcodes(filename)
    File.readlines(filename).map{|l|
      barcode_index, barcode_seq_flank5, barcode_seq_flank3 = l.chomp.split("\t")
      [barcode_index, {flank_5: barcode_seq_flank5, flank_3: barcode_seq_flank3}]
    }.to_h
  end

  Sample = Struct.new(*[:experiment_id, :tf_non_normalized, :barcode_index, :filename], keyword_init: true) do
    # SRR3405054_CEBPb_BC15.fastq or SRR3405138_cJUN_FOSL2_2_BC11.fastq
    def self.from_filename(filename)
      basename = File.basename(filename, '.fastq')
      # ['SRR3405138', ['cJUN', 'FOSL2', '2'], 'BC11']
      experiment_id, *tf_parts, barcode_index = basename.split('_')
      self.new(experiment_id: experiment_id, tf_non_normalized: tf_parts.join('_'), barcode_index: barcode_index, filename: filename)
    end
  end

  SampleMetadata = Struct.new(*[:tfs, :construct_type, :experiment_id, :barcode_index, :tf_non_normalized], keyword_init: true) do
    def self.header_row; ['Experiment ID', 'TF(s)', 'Construct type', 'Barcode', 'TF non-normalized name']; end
    def data_row; to_h.values_at(*[:experiment_id, :tf_normalized, :construct_type, :barcode_index, :tf_non_normalized]); end
    def tf_normalized; tfs.join(';'); end
    def experiment_type; 'SMS'; end

    def self.from_string(line)
      # Example:
      ## SRR_ID  Barcode TF_name_(replicate) tf_normalized
      ## SRR3405054  BC15  CEBPb CEBPB
      srr_id, barcode_index, tf_non_normalized, tf_normalized = l.chomp.split("\t")
      tfs = tf_normalized.split(';')
      self.new(tfs: tfs, construct_type: 'NA', experiment_id: srr_id, barcode_index: barcode_index, tf_non_normalized: tf_non_normalized)
    end

    def self.each_in_file(filename)
      return enum_for(:each_in_file, filename)  unless block_given?
      File.readlines(filename).drop(1).map{|line|
        yield self.from_string(line)
      }
    end
  end

  def self.match_metadata?(sample, sample_metadata)
    fields = [:experiment_id, :tf_non_normalized, :barcode_index]
    sample.to_h.values_at(*fields) == sample_metadata.to_h.values_at(*fields)
  end
end

source_folder = 'source_data_smileseq/published'
barcodes = SMSPublished.read_barcodes("#{source_folder}/Barcode_sequences.txt")

sample_filenames = Dir.glob("#{source_folder}/smileseq_raw/*.fastq")
samples = sample_filenames.map{|fn| SMSPublished::Sample.from_filename(fn) }

metadata_fn = "#{source_folder}/SMiLE_seq_metadata_temp_17DEC2020_publishedData.tsv"
metadata = SMSPublished::SampleMetadata.each_in_file(metadata_fn).to_a

metadata_by_experiment_id = metadata.index_by(&:experiment_id)
sample_by_experiment_id = samples.index_by(&:experiment_id)

sample_triples = sample_by_experiment_id.map{|experiment_id, sample|
  sample_metadata = metadata_by_experiment_id[experiment_id]
  [experiment_id, sample, sample_metadata]
}

sample_triples.each{|experiment_id, sample, sample_metadata|
  $stderr.puts("No metadata for `#{experiment_id}`")  if sample_metadata.nil?
  $stderr.puts("No sample for `#{experiment_id}`")  if sample.nil? # Impossible
  unless SMSPublished.match_metadata?(sample, sample_metadata)
    $stderr.puts("Metadata for #{sample.experiment_id} doesn't match info in filename")
  end
}

ds_naming = ReadsProcessing::DatasetNaming.new("results_smileseq/published", barcodes: barcodes, metadata: metadata)
ds_naming.create_folders!

Parallel.each(sample_triples, in_processes: 20) do |experiment_id, sample, sample_metadata|
  train_val_split(sample.filename, ds_naming.train_filename(experiment_id), ds_naming.validation_filename(experiment_id))
end

ReadsProcessing.generate_samples_stats(SMSPublished::SampleMetadata, ds_naming, sample_triples)
