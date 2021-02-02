require_relative '../shared/lib/index_by'
require_relative '../shared/lib/random_names'
require_relative 'fastq'

module ReadsProcessing
  class DatasetNaming
    attr_reader :results_folder, :barcode_proc, :metadata, :metadata_by_experiment_id
    def initialize(results_folder, barcode_proc:, metadata:)
      @results_folder = results_folder
      @barcode_proc = barcode_proc
      @metadata = metadata
      @metadata_by_experiment_id = @metadata.index_by(&:experiment_id)
    end

    def create_folders!
      FileUtils.mkdir_p "#{results_folder}/train_reads"
      FileUtils.mkdir_p "#{results_folder}/validation_reads"
    end

    def basename(experiment_id)
      sample_metadata = metadata_by_experiment_id[experiment_id]
      barcode = barcode_proc.call(sample_metadata)
      flank_5 = (sample_metadata.adapter_5 + barcode[:flank_5])[-20,20]
      flank_3 = (barcode[:flank_3] + sample_metadata.adapter_3)[0,20]
      "#{sample_metadata.tf}.#{sample_metadata.construct_type}@#{sample_metadata.experiment_type}@#{experiment_id}.5#{flank_5}.3#{flank_3}@Reads"
    end

    def train_filename(experiment_id, uuid:); "#{results_folder}/train_reads/#{basename(experiment_id)}.#{uuid}.Train.fastq.gz"; end
    def validation_filename(experiment_id, uuid:); "#{results_folder}/validation_reads/#{basename(experiment_id)}.#{uuid}.Val.fastq.gz"; end
    def stats_filename; "#{results_folder}/stats.tsv"; end
    def find_train_filename(experiment_id); Dir.glob("#{results_folder}/train_reads/#{basename(experiment_id)}.*.Train.fastq.gz").first; end
    def find_validation_filename(experiment_id); Dir.glob("#{results_folder}/validation_reads/#{basename(experiment_id)}.*.Val.fastq.gz").first; end
  end

  def self.generate_samples_stats(metadata_class, ds_naming, sample_triples)
    File.open(ds_naming.stats_filename, 'w') do |fw|
      header = [*metadata_class.header_row, 'train/validation', 'filename', 'number of reads', 'original filename']
      fw.puts(header.join("\t"))
      sample_triples.each{|experiment_id, sample, sample_metadata|
        column_infos = sample_metadata.data_row

        train_fn = ds_naming.find_train_filename(experiment_id)
        val_fn = ds_naming.find_validation_filename(experiment_id)

        info_train = [*column_infos, 'train', train_fn, num_reads_in_fastq(train_fn), sample.filename]
        info_val   = [*column_infos, 'validation', val_fn, num_reads_in_fastq(val_fn), sample.filename]
        fw.puts(info_train.join("\t"))
        fw.puts(info_val.join("\t"))
      }
    end
  end
end
