require 'fileutils'
require 'json'
require_relative 'tree'

module Enumerable
  def mean
    empty? ? nil : sum(0.0) / size
  end

  def stddev
    return nil  if size < 2
    m = mean
    (self.map{|x| (x-m) ** 2 }.sum(0.0) / (size - 1)) ** 0.5
  end

  def rank_by(start_with: 1, order: :large_better, &block)
    raise  unless block_given?
    raise  unless [:large_better, :small_better].include?(order)
    compactified_collection = self.select(&block)
    sorted_collection = compactified_collection.sort_by(&block).yield_self{|coll| (order == :large_better) ? coll.reverse : coll }
    sorted_collection.each_with_index.map{|obj, idx|
      [(idx + start_with), obj]
    }
  end

  # analog for ruby 2.7+
  def tally
    self.each_with_object(Hash.new(0)){|v, hsh| hsh[v] += 1 }
  end
end

def product_mean(values)
  values = values.compact
  values.size == 0 ? nil : values.inject(1.0, &:*) ** (1.0 / values.size)
end

def basic_stats(vals)
  vals = vals.compact
  (vals.size >= 2) ? "#{vals.mean&.round(2)} ± #{vals.stddev&.round(2)}" : vals.mean&.round(2)
end

def treat_status(status)
  case status
  when '-'
    nil
  when /^Nay/
    false
  when /^Yay/
    true
  when 'TBD', 'Borderline'
    true  ## To fix
  else
    raise 'Unknown status'
  end
end

def experiment_id(dataset)
  dataset.split('@')[2].split('.')[0]
end

def motif_tf(motif)
  motif.split('@').first.split('.').first
end

def read_metrics(metrics_readers_configs)
  metrics_readers_configs.flat_map{|fn, fn_parsers|
    infos = File.readlines(fn).drop(1).map{|line|
      line.chomp!
      dataset, motif, *values = line.split("\t")
      dataset_tf = dataset.split('.')[0]
      motif_tf = motif.split('.')[0]
      raise  unless dataset_tf == motif_tf
      tf = dataset_tf
      values = values.map{|val| val && Float(val) }
      {dataset: dataset, motif: motif, tf: tf, values: values, original_line: line, filename: File.basename(fn)}
    }

    fn_parsers.flat_map{|metric_names, dataset_condition|
      infos.select{|info|
          dataset_condition.call(info[:dataset])
      }.flat_map{|info|
        common_info = info.reject{|k,v| k == :values }
        metric_names.zip(info[:values]).map{|metric_name, value|
          common_info.merge({value: value, metric_name: metric_name})
        }
      }
    }
  }
end

def read_tfs_curration(filename)
  File.readlines(filename).drop(1).each_with_object(Hash.new){|l, result|
    row = l.chomp.split("\t")
    tf, motifs_count, *verdicts, reason = *row

    chipseq_verdict, pbm_verdict, \
        affiseq_IVT_verdict, affiseq_Lysate_verdict, \
        selex_IVT_verdict, selex_Lysate_verdict, \
        final_verdict = verdicts.map{|val| treat_status(val) }
    result[tf] = {
      verdicts: { # If datasets of a certain type passed curration
        chipseq: chipseq_verdict,
        affiseq_IVT: affiseq_IVT_verdict,
        affiseq_Lysate: affiseq_Lysate_verdict,
        selex_IVT: selex_IVT_verdict,
        selex_Lysate: selex_Lysate_verdict,
        pbm: pbm_verdict,
        final: final_verdict,
      },
      motifs_count: Integer(motifs_count),
      reason: reason,
    }
  }
end

def get_motif_ranks(motif_infos, metric_combinations)
  basic_ranks = motif_infos.map{|info|
    [info[:metric_name], info[:rank]]
  }.to_h

  ranks_tree = Node.construct_tree(metric_combinations)
  ranks_tree.each_node_upwards do |node|
    metric_name = node.key
    if node.leaf?
      node.value = basic_ranks[metric_name]
    else
      children_ranks = node.children.map{|k, child| child.value }
      node.value = product_mean(children_ranks.compact)
    end
  end
  ranks_tree.each_node.reject(&:root?).map{|node| [node.key, node.value] }.to_h
end

def get_motif_values(motif_infos, metric_combinations)
  basic_values = motif_infos.map{|info|
    [info[:metric_name], info[:rank_infos].map{|rank_info| rank_info[:value] }]
  }.to_h

  values_tree = Node.construct_tree(metric_combinations)
  values_tree.each_node_upwards do |node|
    metric_name = node.key
    if node.leaf?
      node.value = basic_values[metric_name]
    else
      children_values = node.children.map{|k, child| child.value }
      node.value = children_values.flatten.compact
    end
  end

  values_tree.each_node.map{|node| [node.key, node.value] }.to_h
end

## pbm_roclog and pbm_prlog are roughly equivalent to pbm_roc and pbm_log
METRIC_NAMES_BY_TYPE = {
  chipseq: [:chipseq_pwmeval_ROC, :chipseq_vigg_ROC], #, :chipseq_vigg_logROC],
  affiseq_IVT: [
    # :affiseq_IVT_vigg_logROC,
    :affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, # peak metrics
    :affiseq_10_IVT_ROC, :affiseq_50_IVT_ROC,        # read metrics
  ],
  affiseq_Lysate: [
    # :affiseq_Lysate_vigg_logROC,
    :affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, # peak metrics
    :affiseq_10_Lysate_ROC, :affiseq_50_Lysate_ROC,        # read metrics
  ],
  selex_IVT: [:selex_10_IVT_ROC, :selex_50_IVT_ROC],
  selex_Lysate: [:selex_10_Lysate_ROC, :selex_50_Lysate_ROC],
  pbm: [
    :pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_roc, :pbm_qnzs_pr,
    :pbm_qnzs_mers, :pbm_qnzs_logmers,
    :pbm_sdqn_asis, :pbm_sdqn_log, :pbm_sdqn_exp, :pbm_sdqn_roc, :pbm_sdqn_pr,
    :pbm_sdqn_mers, :pbm_sdqn_logmers,
  ],
  smileseq: [:smileseq_10_ROC, :smileseq_50_ROC],
}

METRIC_TYPE_BY_NAME = METRIC_NAMES_BY_TYPE.flat_map{|metric_type, metric_names|
  metric_names.map{|metric_name| [metric_name, metric_type] }
}.to_h

METRIC_COMBINATIONS = {
  combined: {
    chipseq: [:chipseq_pwmeval_ROC, :chipseq_vigg_ROC, :chipseq_centrimo_concentration_30nt],
    affiseq: {
      affiseq_IVT: {
        affiseq_IVT_peaks: [:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, :affiseq_IVT_centrimo_concentration_30nt],
        affiseq_IVT_reads: [:affiseq_10_IVT_ROC, :affiseq_50_IVT_ROC],
      },
      affiseq_Lysate: {
        affiseq_Lysate_peaks: [:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, :affiseq_Lysate_centrimo_concentration_30nt],
        affiseq_Lysate_reads: [:affiseq_10_Lysate_ROC, :affiseq_50_Lysate_ROC],
      },
    },
    selex: {
      selex_IVT: [:selex_10_IVT_ROC, :selex_50_IVT_ROC],
      selex_Lysate: [:selex_10_Lysate_ROC, :selex_50_Lysate_ROC],
    },
    pbm: {
      pbm_sdqn: [:pbm_sdqn_roc, :pbm_sdqn_pr],
      pbm_qnzs: [:pbm_qnzs_roc, :pbm_qnzs_pr],
    },
    smileseq: [:smileseq_10_ROC, :smileseq_50_ROC],
  },
  dropped: {
    dropped_peak_metrics: [:chipseq_vigg_logROC, :affiseq_IVT_vigg_logROC, :affiseq_Lysate_vigg_logROC],
    dropped_pbm_qnzs: [:pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_mers, :pbm_qnzs_logmers],
    dropped_pbm_sdqn: [:pbm_sdqn_asis, :pbm_sdqn_log, :pbm_sdqn_exp, :pbm_sdqn_mers, :pbm_sdqn_logmers],
    pbm_roc: [:pbm_sdqn_roc, :pbm_qnzs_roc],
    pbm_pr:  [:pbm_sdqn_pr,  :pbm_qnzs_pr],
  }
}

METRICS_ORDER = Node.construct_tree(METRIC_COMBINATIONS).each_node_bfs.map(&:key).reject(&:nil?)
DERIVED_METRICS_ORDER = Node.construct_tree(METRIC_COMBINATIONS).each_node_bfs.reject(&:leaf?).map(&:key).reject(&:nil?)

# tfs_curration = read_tfs_curration('source_data_meta/shared/curation_tfs_vigg.tsv')
tfs_curration = {}

metrics_readers_configs = {
  'release_6_metrics/formatted_peaks.tsv' => [
    [[:chipseq_pwmeval_ROC], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_pwmeval_ROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_Lysate_pwmeval_ROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'release_6_metrics/formatted_vigg_peaks.tsv' => [
    [[:chipseq_vigg_ROC, :chipseq_vigg_logROC], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_vigg_ROC, :affiseq_IVT_vigg_logROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_Lysate_vigg_ROC, :affiseq_Lysate_vigg_logROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'release_6_metrics/formatted_peaks_centrimo.tsv' => [
    [[:chipseq_centrimo_neglog_evalue, :chipseq_centrimo_concentration_30nt], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_centrimo_neglog_evalue, :affiseq_IVT_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_Lysate_centrimo_neglog_evalue, :affiseq_Lysate_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'release_6_metrics/formatted_reads_0.1.tsv' => [
    [[:selex_10_IVT_ROC], ->(x){ x.match?(/@HTS\.IVT@/) }],
    [[:selex_10_Lysate_ROC], ->(x){ x.match?(/@HTS\.Lys@/) }],
    [[:affiseq_10_IVT_ROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_10_Lysate_ROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
    [[:smileseq_10_ROC], ->(x){ x.match?(/@SMS@/) }],
  ],
  'release_6_metrics/formatted_reads_0.5.tsv' => [
    [[:selex_50_IVT_ROC], ->(x){ x.match?(/@HTS\.IVT@/) }],
    [[:selex_50_Lysate_ROC], ->(x){ x.match?(/@HTS\.Lys@/) }],
    [[:affiseq_50_IVT_ROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_50_Lysate_ROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
    [[:smileseq_50_ROC], ->(x){ x.match?(/@SMS@/) }],
  ],
  'release_6_metrics/formatted_pbm.tsv' => [
    [[:pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_roc, :pbm_qnzs_pr, :pbm_qnzs_mers,  :pbm_qnzs_logmers], ->(x){ x.match?(/@QNZS\./) }],
    [[:pbm_sdqn_asis, :pbm_sdqn_log, :pbm_sdqn_exp, :pbm_sdqn_roc, :pbm_sdqn_pr, :pbm_sdqn_mers, :pbm_sdqn_logmers], ->(x){ x.match?(/@SDQN\./) }],
  ],
}

all_metric_infos = read_metrics(metrics_readers_configs).select{|info|
  tf = info[:tf]
  metric_name = info[:metric_name]
  metric_type = METRIC_TYPE_BY_NAME[metric_name]
  tfs_curration[tf][:verdicts][metric_type] rescue true
}


# what is called a dataset here is actually a validation group
ranked_motif_metrics = all_metric_infos.group_by{|info|
  [info[:tf], info[:dataset], info[:metric_name]]
}.flat_map{|(tf, dataset, metric_name), tf_metrics|
  tf_metrics.rank_by(order: :large_better, start_with: 1){|info|
    info[:value]
  }.map{|rank, info|
    info.merge(rank: rank)
  }
}

extended_motif_metrics = ranked_motif_metrics.group_by{|info|
  info[:dataset] # validation group
}.flat_map{|dataset, dataset_infos|
  extended_infos = dataset_infos.group_by{|info|
    info[:motif]
  }.flat_map{|motif, motif_infos|
    raise "Some metrics has several values for dataset #{dataset}"  unless motif_infos.map{|info| info[:metric_name] }.tally.all?{|k,v| v == 1 }
    combination_pattern = {"val_group": METRIC_COMBINATIONS[:combined]}
    combined_ranks = get_motif_ranks(motif_infos, combination_pattern).compact
    {motif: motif, dataset: dataset, ranks: combined_ranks, metric_infos: motif_infos}
  }

  [*DERIVED_METRICS_ORDER, :val_group].each{|metric_name|
    extended_infos.rank_by{|info|
      info[:ranks][metric_name]
    }.each{|rank, info|
      info[:ranks][metric_name] = rank
    }
  }

  extended_infos
}

exp_extended_motif_metrics = extended_motif_metrics.group_by{|info|
  experiment_id(info[:dataset])
}.flat_map{|exp_id, experiment_infos|
  extended_infos = experiment_infos.group_by{|info|
    info[:motif]
  }.map{|motif, motif_infos|
    val_group_ranks = motif_infos.map{|info| info[:ranks][:val_group] }
    experimentwise_rank = product_mean(val_group_ranks)
    
    new_ranks = {experiment: experimentwise_rank}
    motif_infos.each{|info|
      # new_ranks = info[:ranks].map{|k,v| ["#{k}:#{info[:dataset]}", v] }.to_h
      new_ranks[ info[:dataset] ] = info[:ranks]
    }
    
    {motif: motif, experiment_id: exp_id, ranks: new_ranks}
  }

  [:experiment].each{|metric_name|
    extended_infos.rank_by{|info|
      info[:ranks][metric_name]
    }.each{|rank, info|
      info[:ranks][metric_name] = rank
    }
  }

  extended_infos
}


fully_extended_motif_metrics = exp_extended_motif_metrics.group_by{|info|
  motif_tf(info[:motif])
}.flat_map{|tf, tf_infos|
  extended_infos = tf_infos.group_by{|info|
    info[:motif]
  }.flat_map{|motif, motif_infos|
    experiment_ranks = motif_infos.map{|info| info[:ranks][:experiment] }
    combined_rank = product_mean(experiment_ranks)
    
    new_ranks = {combined: combined_rank}
    motif_infos.each{|info|
      # new_ranks = info[:ranks].map{|k,v| ["#{k}:#{info[:dataset]}", v] }.to_h
      new_ranks[ info[:experiment_id] ] = info[:ranks]
    }
    
    {motif: motif, ranks: new_ranks}
  }

  [:combined].each{|metric_name|
    extended_infos.rank_by{|info|
      info[:ranks][metric_name]
    }.each{|rank, info|
      info[:ranks][metric_name] = rank
    }
  }

  extended_infos
}

FileUtils.mkdir_p('results')
File.write('results/metrics.json', ranked_motif_metrics.to_json)
File.write('results/ranks.json', fully_extended_motif_metrics.to_json)
