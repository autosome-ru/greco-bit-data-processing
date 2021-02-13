require_relative '../shared/lib/index_by'
require_relative '../shared/lib/random_names'
require_relative 'fastq'

module ReadsProcessing
  class DatasetNaming
    attr_reader :results_folder, :barcode_proc
    def initialize(results_folder, barcode_proc:)
      @results_folder = results_folder
      @barcode_proc = barcode_proc
    end

    def create_folders!
      FileUtils.mkdir_p "#{results_folder}/Train_reads"
      FileUtils.mkdir_p "#{results_folder}/Val_reads"
    end

    def basename(sample_metadata, cycle:)
      barcode = barcode_proc.call(sample_metadata)
      flank_5 = (sample_metadata.adapter_5 + barcode[:flank_5])[-20,20]
      flank_3 = (barcode[:flank_3] + sample_metadata.adapter_3)[0,20]
      procedure = 'Reads'
      if cycle # AFS/HTS
        "#{sample_metadata.tf}.#{sample_metadata.construct_type}@#{sample_metadata.experiment_type}@#{sample_metadata.experiment_id}.C#{cycle}.5#{flank_5}.3#{flank_3}@#{procedure}"
      else # SMS
        "#{sample_metadata.tf}.#{sample_metadata.construct_type}@#{sample_metadata.experiment_type}@#{sample_metadata.experiment_id}.5#{flank_5}.3#{flank_3}@#{procedure}"
      end
    end

    def train_filename(sample_metadata, uuid:, cycle:); "#{results_folder}/Train_reads/#{basename(sample_metadata, cycle: cycle)}.#{uuid}.Train.fastq.gz"; end
    def validation_filename(sample_metadata, uuid:, cycle:); "#{results_folder}/Val_reads/#{basename(sample_metadata, cycle: cycle)}.#{uuid}.Val.fastq.gz"; end
    def stats_filename; "#{results_folder}/stats.tsv"; end
    def find_train_filename(sample_metadata, cycle:); Dir.glob("#{results_folder}/Train_reads/#{basename(sample_metadata, cycle: cycle)}.*.Train.fastq.gz").first; end
    def find_validation_filename(sample_metadata, cycle:); Dir.glob("#{results_folder}/Val_reads/#{basename(sample_metadata, cycle: cycle)}.*.Val.fastq.gz").first; end
  end

  def self.generate_samples_stats(metadata_class, ds_naming, sample_triples)
    File.open(ds_naming.stats_filename, 'w') do |fw|
      header = [*metadata_class.header_row, 'train/validation', 'filename', 'number of reads', 'original filename']
      fw.puts(header.join("\t"))
      sample_triples.each{|experiment_id, sample, sample_metadata|
        column_infos = sample_metadata.data_row

        train_fn = ds_naming.find_train_filename(sample_metadata, cycle: sample.cycle)
        val_fn = ds_naming.find_validation_filename(sample_metadata, cycle: sample.cycle)

        info_train = [*column_infos, 'train', train_fn, num_reads_in_fastq(train_fn), sample.filename]
        info_val   = [*column_infos, 'validation', val_fn, num_reads_in_fastq(val_fn), sample.filename]
        fw.puts(info_train.join("\t"))
        fw.puts(info_val.join("\t"))
      }
    end
  end
end
