require 'parallel'
require 'fileutils'
require_relative 'fastq'
require_relative 'train_val_split'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/random_names'

module SMSUnpublished
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

  class DatasetNaming
    attr_reader :results_folder, :barcodes
    def initialize(results_folder, barcodes:)
      @results_folder = results_folder
      @barcodes = barcodes
    end

    def self.create_folders!
      FileUtils.mkdir_p "#{results_folder}/train_reads"
      FileUtils.mkdir_p "#{results_folder}/validation_reads"
    end

    def basename(sample)
      experiment_id = sample.experiment_id
      barcode = barcodes[barcode_index]
      flank_5 = (ADAPTER_5 + barcode[:flank_5])[-20,20]
      flank_3 = (barcode[:flank_3] + ADAPTER_3)[0,20]
      uuid = take_dataset_name!
      "#{sample.tf}.#{sample.construct_type}@SMS@#{experiment_id}.5#{flank_5}.3#{flank_3}@Reads.#{uuid}"
    end

    def train_filename(sample); "#{results_folder}/train_reads/#{basename(sample)}.Train.fastq"; end
    def validation_filename(sample); "#{results_folder}/validation_reads/#{basename(sample)}.Val.fastq"; end
    def stats_filename; "#{results_folder}/stats.tsv"; end
  end

  Sample = Struct.new(*[:experiment_id, :tf, :construct_type, :barcode_index, :domain, :sequencing_id, :filename], keyword_init: true) do
    # UT380-185_SETBP1_DBD_1_AT_hook_SS018_BC07.fastq
    def self.from_filename(filename)
      basename = File.basename(filename, '.fastq')
      # ['UT380-185', 'SETBP1', 'DBD', ['1', 'AT', 'hook'], 'SS018', 'BC07']
      experiment_id_match = basename.match(/^(UT\d\d\d)[-_]?(\d\d\d)_/)
      experiment_id = experiment_id_match[1] + '-' + experiment_id_match[2] # UT380_501 --> UT380-501, UT380408 --> UT380-408
      tf, dbd_or_fl, *domain_parts, sequencing_id, barcode_index = basename[experiment_id_match[0].length..-1].split('_')
      barcode_index = barcode_index.sub(/^BC0*(\d+)$/, 'BC\1') # BC07 --> BC7
      self.new(experiment_id: experiment_id, tf: tf, construct_type: dbd_or_fl,
        barcode_index: barcode_index, domain: domain_parts.join('_'), sequencing_id: sequencing_id,
        filename: filename)
    end
  end

  SampleMetadata = Struct.new(*[:experiment_id, :tf, :construct_type, :barcode_index, :hughes_id, :tf_family, :ssid], keyword_init: true) do
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

def generate_samples_stats(ds_naming, samples)
  File.open(ds_naming.stats_filename, 'w') do |fw|
    header = ['experiment_id', 'tf', 'construct_type', 'domain', 'sequencing_id', 'barcode_index', 'train/validation', 'filename', 'num_reads']
    fw.puts(header.join("\t"))
    samples.each{|sample|
      column_infos = sample.to_h.values_at(:experiment_id, :tf, :construct_type, :domain, :sequencing_id, :barcode_index)

      train_fn = ds_naming.train_filename(sample)
      val_fn = ds_naming.validation_filename(sample)

      info_train = [*column_infos, 'train', train_fn, num_reads_in_fastq(train_fn)]
      info_val   = [*column_infos, 'validation', val_fn, num_reads_in_fastq(val_fn)]
      fw.puts(info_train.join("\t"))
      fw.puts(info_val.join("\t"))
    }
  end
end


SOURCE_FOLDER = 'source_data_smileseq/unpublished'
barcodes = SMSUnpublished.read_barcodes("#{SOURCE_FOLDER}/smileseq_barcode_file.txt")

sample_filenames = Dir.glob("#{SOURCE_FOLDER}/smileseq_raw/*.fastq")
samples = sample_filenames.map{|fn| SMSUnpublished::Sample.from_filename(fn) }

metadata_fn = "#{SOURCE_FOLDER}/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv"
metadata = SMSUnpublished::SampleMetadata.each_in_file(metadata_fn).to_a

metadata_by_experiment_id = metadata.index_by(&:experiment_id)
sample_by_experiment_id = samples.index_by(&:experiment_id)

sample_meta_pairs = []
sample_meta_pairs += samples.map{|sample|  [sample, metadata_by_experiment_id[sample.experiment_id]]  }
sample_meta_pairs += metadata.map{|sample_metadata|  [sample_by_experiment_id[sample_metadata.experiment_id], sample_metadata]  }

sample_meta_pairs.each{|sample, sample_metadata|
  unless SMSUnpublished.match_metadata?(sample, sample_metadata)
    raise "Metadata for #{sample.experiment_id} doesn't match info in filename"
  end
}

ds_naming = SMSUnpublished::DatasetNaming.new("results_smileseq", barcodes: barcodes, metadata: metadata)
ds_naming.create_folders!

Parallel.each(samples, in_processes: 20) do |sample|
  train_val_split(sample.filename, ds_naming.train_filename(sample), ds_naming.validation_filename(sample))
end

generate_samples_stats(ds_naming, samples)
