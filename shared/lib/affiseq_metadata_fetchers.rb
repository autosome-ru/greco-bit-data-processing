require 'mysql2'
require_relative 'affiseq_metadata'
require_relative 'index_by'
require_relative 'afs_peaks_biouml_meta'
require_relative '../../process_peaks_CHS_AFS/experiment_info_afs'

class ExperimentInfoAFSFetcher
  def initialize(experiment_infos)
    @experiment_infos = experiment_infos
  end

  def self.read_metrics_file(metrics_fn)
    metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
    experiment_infos = ExperimentInfoAFS.each_from_file(metrics_fn, metadata).to_a

    experiment_infos = experiment_infos.reject{|info|
      info.type == 'control'
    }.to_a

    experiment_infos.each{|info|
      info.confirmed_peaks_folder = "./results_databox_afs_#{info.type}/complete_data"
    }
    experiment_infos
  end
end

# the first pack of AFS metrics can be matched to a file by tuple (tf, exp_subtype, cycle, batch)
class ExperimentInfoAFSFetcherPack1 < ExperimentInfoAFSFetcher
  def initialize(experiment_infos)
    super
    # keys like ["GLI4", "Lys", "Cycle1", "YWDB"]
    @experiment_by_tf_and_cycle = @experiment_infos.index_by{|exp|
      [exp.tf, exp.type[0,3], exp.cycle_number, exp.batch]
    }
  end

  def self.load(metrics_fn)
    self.new(self.read_metrics_file(metrics_fn))
  end

  def fetch(dataset_info)
    exp_key = dataset_info.yield_self{|d| [d[:tf], d[:experiment_subtype], "Cycle#{d[:experiment_params][:cycle]}", d[:experiment_meta][:batch]] }
    @experiment_by_tf_and_cycle[exp_key]&.to_h
  end
end

# the second pack of AFS metrics can be matched to a file by biouml id which is loaded from DB based on (exp_id, cycle)
class ExperimentInfoAFSFetcherPack2 < ExperimentInfoAFSFetcher
  def initialize(experiment_infos, biouml_id_by_experiment_id_and_cycle)
    super(experiment_infos)
    @experiment_info_by_biouml_id = experiment_infos.index_by(&:experiment_id)
    @biouml_id_by_experiment_id_and_cycle = biouml_id_by_experiment_id_and_cycle
  end

  def self.load(metrics_fn, mysql_config)
    client = Mysql2::Client.new(mysql_config)
    self.new(self.read_metrics_file(metrics_fn), load_biouml_id_by_experiment_id_and_cycle(client))
  end

  def fetch(dataset_info)
    exp_id = dataset_info[:experiment_id]
    tf = dataset_info[:tf]
    exp_id = exp_id.sub(/[-._]((FL|DBD|DBDwLinker|AThook)[-._]?\d?)?$/, "")

    cycle = dataset_info[:experiment_params][:cycle]
    exp_key = [exp_id, cycle]
    biouml_exp_id = @biouml_id_by_experiment_id_and_cycle[exp_key]
    @experiment_info_by_biouml_id[biouml_exp_id]&.to_h
  end
end


# How to obtain peak-reads files for an experiment by biouml id
class ReadFilenamesFetcher
  def initialize(reads_by_experiment, alignment_by_experiment, source_folder:, allow_broken_symlinks:)
    @reads_by_experiment = reads_by_experiment
    @alignment_by_experiment = alignment_by_experiment
    @source_folder = source_folder
    @allow_broken_symlinks = allow_broken_symlinks
  end

  def self.load(mysql_config, source_folder:, allow_broken_symlinks:)
    client = Mysql2::Client.new(mysql_config)
    records = get_experiment_infos(client)
    _experiments, alignment_by_experiment, reads_by_experiment = infos_by_alignment(records)
    self.new(reads_by_experiment, alignment_by_experiment, source_folder: source_folder, allow_broken_symlinks: allow_broken_symlinks)
  end

  def fetch(biouml_experiment_id)
    @reads_by_experiment[biouml_experiment_id]
  end

  def fetch_alignment(biouml_experiment_id)
    @alignment_by_experiment[biouml_experiment_id]
  end

  def fetch_validated_abspaths!(biouml_experiment_id)
    fetch(biouml_experiment_id).map{|reads_fn|
      ds_filename = File.absolute_path("#{@source_folder}/trimmed/#{reads_fn}.fastq.gz")
      if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && @allow_broken_symlinks))
        raise "Missing file #{ds_filename} for #{biouml_experiment_id}"
      end
      ds_filename
    }
  end

  def fetch_alignment_validated_abspaths!(biouml_experiment_id)
    alignment_fn = @alignment_by_experiment[biouml_experiment_id]
    alignment_fn = File.absolute_path("#{@source_folder}/aligns-sorted/#{alignment_fn}.bam")
    if ! (File.exist?(alignment_fn) || (File.symlink?(alignment_fn) && @allow_broken_symlinks))
      raise "Missing file #{alignment_fn} for #{biouml_experiment_id}"
    end
    alignment_fn
  end
end
