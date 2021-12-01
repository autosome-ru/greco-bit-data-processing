require 'mysql2'

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
    @experiment_info_by_biouml_id = experiment_infos. index_by(&:experiment_id)
    @biouml_id_by_experiment_id_and_cycle = biouml_id_by_experiment_id_and_cycle
  end

  def self.load(metrics_fn, mysql_config)
    client = Mysql2::Client.new(mysql_config)
    self.new(self.read_metrics_file(metrics_fn), load_biouml_id_by_experiment_id_and_cycle(client))
  end

  def fetch(dataset_info)
    exp_id = dataset_info[:experiment_id]
    tf = dataset_info[:tf]
    exp_id.sub(/_#{tf}(_(FL|DBD|DBDwLinker))?(_\d)?$/, "")

    cycle = dataset_info[:experiment_params][:cycle]
    exp_key = [exp_id, cycle]
    biouml_exp_id = @biouml_id_by_experiment_id_and_cycle[exp_key]
    @experiment_info_by_biouml_id[biouml_exp_id]&.to_h
  end
end

# How to obtain read files for an experiment by biouml id
class ReadFilenamesFetcher
  def initialize(reads_by_experiment)
    @reads_by_experiment = reads_by_experiment
  end

  def self.load(mysql_config)
    client = Mysql2::Client.new(mysql_config)
    records = get_experiment_infos(client)
    _experiments, _alignment_by_experiment, reads_by_experiment = infos_by_alignment(records)
    self.new(reads_by_experiment)
  end

  def fetch(biouml_experiment_id)
    @reads_by_experiment[biouml_experiment_id]
  end
end
