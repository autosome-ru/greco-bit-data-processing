require 'parallel'
require 'fileutils'
require_relative 'train_val_split'
require_relative '../shared/lib/index_by'

module ReadsProcessing::SMSUnpublished
  # The library is designed as follows:
  # TCGTCGGCAGCGTCAGATGTGTATAAGAGACAG -[BC 1-12, 10bp e.g. CGTATGAATC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - CTGTCTCTTATACACATCTCCGAGCCCA
  ADAPTER_5 = 'TCGTCGGCAGCGTCAGATGTGTATAAGAGACAG'
  ADAPTER_3 = 'CTGTCTCTTATACACATCTCCGAGCCCA'

  def self.read_barcodes(filename)
    File.readlines(filename).map{|l|
      barcode_index, barcode_seq = l.chomp.split("\t")
      [barcode_index, {flank_5: barcode_seq, flank_3: ''}]
    }.to_h
  end

  Sample = Struct.new(*[:experiment_id, :tf, :construct_type, :barcode_index, :domain, :sequencing_id, :filename], keyword_init: true) do
    # UT380-185_SETBP1_DBD_1_AT_hook_SS018_BC07.fastq
    def self.from_filename(filename)
      basename = File.basename(filename, '.fastq')
      experiment_id_match = basename.match(/^(UT\d\d\d)[-_]?(\d\d\d)_/)
      basename_wo_experiment_id = basename[experiment_id_match[0].length..-1]
      experiment_id = experiment_id_match[1] + '-' + experiment_id_match[2] # UT380_501 --> UT380-501, UT380408 --> UT380-408
      # ['SETBP1', 'DBD', ['1', 'AT', 'hook'], 'SS018', 'BC07']
      tf, dbd_or_fl, *domain_parts, sequencing_id, barcode_index = basename_wo_experiment_id.split('_')
      barcode_index = barcode_index.sub(/^BC0*(\d+)$/, 'BC\1') # BC07 --> BC7
      self.new(experiment_id: experiment_id, tf: tf, construct_type: dbd_or_fl,
        barcode_index: barcode_index, domain: domain_parts.join('_'), sequencing_id: sequencing_id,
        filename: filename)
    end
  end

  SampleMetadata = Struct.new(*[:experiment_id, :tf, :construct_type, :barcode_index, :hughes_id, :tf_family, :ssid], keyword_init: true) do
    def self.header_row; ['Experiment ID', 'TF', 'Construct type', 'Barcode', 'Hughes ID', 'TF family', 'SSID']; end
    def data_row; to_h.values_at(*[:experiment_id, :tf, :construct_type, :barcode_index, :hughes_id, :tf_family, :ssid]); end
    def experiment_type; 'SMS'; end

    def self.from_string(line)
      # Example:
      ## BBI_ID  Hughes_ID TF_family SSID  Barcode
      ## UT380-009 AHCTF1.DBD  AT hook SS001 BC01
      bbi_id, hughes_id, tf_family, ssid, barcode_index = line.chomp.split("\t")
      tf, *rest = hughes_id.split('.')  # hughes_id examples: `MBD4`, `BHLHA9.FL`, `CASZ1.DBD.1`
      construct_type = (rest.size >= 1) ? rest[0] : 'NA'
      self.new(experiment_id: bbi_id, tf: tf, construct_type: construct_type,
        barcode_index: barcode_index.sub(/^BC0*(\d+)$/, 'BC\1'), # BC07 --> BC7
        hughes_id: hughes_id, tf_family: tf_family, ssid: ssid)
    end

    def self.each_in_file(filename)
      return enum_for(:each_in_file, filename)  unless block_given?
      File.readlines(filename).drop(1).map{|line|
        yield self.from_string(line)
      }
    end
  end

  def self.match_metadata?(sample, sample_metadata)
    fields = [:experiment_id, :tf, :construct_type, :barcode_index]
    sample.to_h.values_at(*fields) == sample_metadata.to_h.values_at(*fields)
  end
end

source_folder = 'source_data_smileseq/unpublished'
barcodes = SMSUnpublished.read_barcodes("#{source_folder}/smileseq_barcode_file.txt")

sample_filenames = Dir.glob("#{source_folder}/smileseq_raw/*.fastq")
samples = sample_filenames.map{|fn| SMSUnpublished::Sample.from_filename(fn) }

metadata_fn = "#{source_folder}/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
metadata = SMSUnpublished::SampleMetadata.each_in_file(metadata_fn).to_a

metadata_by_experiment_id = metadata.index_by(&:experiment_id)
sample_by_experiment_id = samples.index_by(&:experiment_id)

sample_triples = sample_by_experiment_id.map{|experiment_id, sample|
  sample_metadata = metadata_by_experiment_id[experiment_id]
  [experiment_id, sample, sample_metadata]
}

sample_triples.each{|experiment_id, sample, sample_metadata|
  $stderr.puts("No metadata for `#{experiment_id}`")  if sample_metadata.nil?
  $stderr.puts("No sample for `#{experiment_id}`")  if sample.nil? # Impossible
  unless SMSUnpublished.match_metadata?(sample, sample_metadata)
    $stderr.puts("Metadata for #{sample.experiment_id} doesn't match info in filename")
  end
}

ds_naming = ReadsProcessing::DatasetNaming.new("results_smileseq/unpublished", barcodes: barcodes, metadata: metadata)
ds_naming.create_folders!

Parallel.each(sample_triples, in_processes: 20) do |experiment_id, sample, sample_metadata|
  train_val_split(sample.filename, ds_naming.train_filename(experiment_id), ds_naming.validation_filename(experiment_id))
end

ReadsProcessing.generate_samples_stats(SMSUnpublished::SampleMetadata, ds_naming, sample_triples)
