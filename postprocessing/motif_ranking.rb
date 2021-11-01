require 'fileutils'
require 'json'
require_relative 'tree'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/utils'

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

def treat_vote(vote)
  case vote
  when 'good'
    1
  when 'bad'
    -1
  when 'dunno'
    0
  when '', 'None'
    nil
  else
    raise "Unknown vote `#{vote}`"
  end
end

# dataset name: SCML4.DBD@PBM.ME@PBM13821.5GTGAAATTGTTATCCGCTCT@SDQN.pretty-sangria-dalmatian.Train.tsv
#               ZNF708.FL@HTS.Lys@AAT_A_CC40NGACATG.5ACGACGCTCTTCCGATCTCC.3GACATGAGATCGGAAGAGCA.C1+C2+C3@Reads.chummy-turquoise-cow+leaky-seashell-walrus+surly-gold-toad.Val.fastq.gz

def experiment_id(dataset_fullname)
  dataset_fullname.split('@')[2].split('.')[0]
end

def experiment_fulltype(dataset_fullname) # PBM.HK, AFS.Lys etc
  dataset_fullname.split('@')[1]
end

def experiment_processing_type(dataset_fullname) # Peaks
  dataset_fullname.split('@')[3].split('.')[0]
end

def dataset_ids_for_dataset(dataset_fullname)
  dataset_fullname.split('@')[3].split('.')[1].split('+')
end

# motif name: ZNF687.DBD@AFS.IVT@bluesy-eggplant-shrimp+seedy-puce-hyrax+snappy-vermilion-sparrow+stealthy-blue-heron@autosome-ru.ChIPMunk@topk_cycle=C1+C2+C3+C4_k=5_top=10000.pcm

def dataset_ids_for_motif(motif_fullname)
  motif_fullname.split('@')[2].split('+')
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
      # experiment_type = experiment_fulltype(dataset)
      # experiment = experiment_id(dataset)
      values = values.map{|val| val && Float(val) }
      {
        dataset: dataset, motif: motif, tf: tf,
        # experiment_type: experiment_type, experiment: experiment,
        values: values, original_line: line, filename: File.basename(fn),
      }
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

def read_curation_info(filename)
  # curator
  # Exp name (can be empty)
  # vote (enum: good/bad/dunno, can be empty if comment is set)
  # tf (tf_name)
  # comment (if exp_name is empty this comment is not for dataset but for tf)
  File.readlines(filename).map(&:chomp).reject(&:empty?).map{|l|
    row = l.split("\t", 5)
    curator, exp_name, vote, tf, comment = *row.map{|x| x == '\N' ? '' : x}
    exp_name = exp_name.empty? ? nil : exp_name
    comment = comment.empty? ? nil : comment
    vote = treat_vote(vote)
    {curator: curator, exp_name: exp_name, vote: vote, tf: tf, comment: comment}
  }
end

def get_datasets_curation(curation_info)
  curation_info.select{|info|
    info[:exp_name] && info[:vote]
  }.group_by{|info|
    info[:exp_name]
  }.transform_values{|infos|
    infos.map{|info| info[:vote] }
  }.transform_values{|votes| votes.sum > 0 }
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

def make_metrics_hierarchy(infos, grouping_vars, &block)
  if grouping_vars.empty?
    block_given? ? infos.map(&block) : infos
  else
    grouping_var = grouping_vars[0]
    infos.group_by{|info|
      info[grouping_var]
    }.transform_values{|infos_subgroup|
      make_metrics_hierarchy(infos_subgroup, grouping_vars.drop(1), &block)
    }
  end
end

def take_ranks(hierarchy_of_ranked_metrics)
  case hierarchy_of_ranked_metrics
  when Array
    # transform [ {:metric_name=>:pbm_qnzs_asis, :value=>0.14, :rank=>9}, {:metric_name=>:pbm_qnzs_log, :value=>0.5, :rank=>7}, ... ]
    # into {pbm_qnzs_asis: 9, pbm_qnzs_log: 7, pbm_qnzs_roc: 9}
    vals = hierarchy_of_ranked_metrics.map{|info| [info[:metric_name], info[:rank]] }
    raise "Non-unique metric names `#{vals}`"  unless vals.map(&:first).yield_self{|ks| ks.size == ks.uniq.size }
    vals.to_h
  when Hash
    # {tf_1 => ..., tf_2 => ...}  -->  {tf_1 => take_ranks(...), tf_2 => take_ranks(...) }
    hierarchy_of_ranked_metrics.transform_values{|subhierarchy| take_ranks(subhierarchy) }
  else
    raise "Incorrect type"
  end
end

# deepest first
def all_paths_dfs(hierarchy, path: [], &block)
  return enum_for(:all_paths_dfs, hierarchy, path: path)  unless block_given?
  if hierarchy.is_a?(Hash)
    hierarchy.each{|k, subhierarchy|
      all_paths_dfs(subhierarchy, path: path + [k], &block)
    }
    yield({path: path, leaf: false})
  else
    yield({path: path, leaf: true})
  end
end

# paths lying in any of motif hierarchies, from longest to shortest
def possible_inner_paths(motif_ranks_hierarchies)
  possible_paths = motif_ranks_hierarchies.flat_map{|motif, hierarchy|
    all_paths_dfs(hierarchy).to_a
  }.uniq

  possible_paths.select{|path_info|
    !path_info[:leaf]
  }.map{|info| info[:path] }.sort_by(&:size).reverse
end

def combine_ranks(hierarchy_of_metrics, metric_path: nil)
  ranks = hierarchy_of_metrics.reject{|k,v| k == :combined }.values.compact

  if ranks.all?(Numeric)
    # {:pbm_qnzs_asis=>97, :pbm_qnzs_log=>97,:pbm_qnzs_exp=>84, :pbm_qnzs_roc=>83, :pbm_qnzs_pr=>59}
    hierarchy_of_metrics.merge(combined: product_mean(ranks))
    # TODO:  rearrange !!!
  else
    # {tf_1 => {...}, tf_2 => {...}} or {"PBM.HK" => {...}, "AFS.Lys" => {...}} or {"QNZS" => {...}, "SDQN" => {...}} etc
    # Smth like {tf_1 => {...}, tf_2 => {...}, combined: 42} is also accepted. In this case key `combined` will be recalculated
    augmented_hierarchy_of_metrics = hierarchy_of_metrics.transform_values{|subhierarchy| combine_ranks(subhierarchy) }
    ranks = augmented_hierarchy_of_metrics.map{|_, subhierarchy| subhierarchy[:combined] }.compact
    augmented_hierarchy_of_metrics.merge({combined: product_mean(ranks)})
  end
end

def read_metadata(metadata_fn)
  File.readlines(metadata_fn).map{|l| JSON.parse(l.chomp) }
end

METRIC_COMBINATIONS = {
  combined: {
    chipseq: [:chipseq_pwmeval_ROC, :chipseq_vigg_ROC, :chipseq_centrimo_concentration_30nt],
    affiseq_IVT: {
      affiseq_IVT_peaks: [:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, :affiseq_IVT_centrimo_concentration_30nt],
      affiseq_IVT_reads: [:affiseq_10_IVT_ROC, :affiseq_25_IVT_ROC, :affiseq_50_IVT_ROC],
    },
    affiseq_Lysate: {
      affiseq_Lysate_peaks: [:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, :affiseq_Lysate_centrimo_concentration_30nt],
      affiseq_Lysate_reads: [:affiseq_10_Lysate_ROC, :affiseq_25_Lysate_ROC, :affiseq_50_Lysate_ROC],
    },
    selex_IVT: [:selex_10_IVT_ROC, :selex_25_IVT_ROC, :selex_50_IVT_ROC],
    selex_Lysate: [:selex_10_Lysate_ROC, :selex_25_Lysate_ROC, :selex_50_Lysate_ROC],
    pbm: {
      pbm_sdqn: [:pbm_sdqn_roc, :pbm_sdqn_pr],
      pbm_qnzs: [:pbm_qnzs_roc, :pbm_qnzs_pr],
    },
    smileseq: [:smileseq_10_ROC, :smileseq_25_ROC, :smileseq_50_ROC],
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

raise 'Specify resulting metrics file'  unless results_metrics_fn = ARGV[0]  # 'results/metrics.json'
raise 'Specify resulting ranks file'  unless results_ranks_fn = ARGV[1]  # 'results/ranks.json'
raise 'Specify curation filename or `no`'  unless curation_fn = ARGV[2] # 'source_data_meta/shared/curations.tsv'
raise 'Specify metadata filename or `no`'  unless metadata_fn = ARGV[3] # 'results/metadata_release_7a.json'

if curation_fn == 'no'
  dataset_curation = nil
  $stderr.puts('Warning: no curation is used')
else
  curation_info = read_curation_info(curation_fn)
  dataset_curation = get_datasets_curation(curation_info)
end

if metadata_fn == 'no'
  experiment_by_dataset_id = nil
  $stderr.puts('Warning: no metadata is used, thus there can be PBM motifs benchmarked on the same datasets which were used for training')
else
  experiment_by_dataset_id = read_metadata(metadata_fn).index_by{|info| info['dataset_id'] }.transform_values{|info| info['experiment_id'] }
end

metrics_readers_configs = {
  'run_benchmarks_release_7/formatted_peaks_pwmeval.tsv' => [
    [[:chipseq_pwmeval_ROC], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_pwmeval_ROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_Lysate_pwmeval_ROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'run_benchmarks_release_7/formatted_peaks_vigg.tsv' => [
    [[:chipseq_vigg_ROC, :chipseq_vigg_logROC], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_vigg_ROC, :affiseq_IVT_vigg_logROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_Lysate_vigg_ROC, :affiseq_Lysate_vigg_logROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'run_benchmarks_release_7/formatted_peaks_centrimo.tsv' => [
    [[:chipseq_centrimo_neglog_evalue, :chipseq_centrimo_concentration_30nt], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_centrimo_neglog_evalue, :affiseq_IVT_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_Lysate_centrimo_neglog_evalue, :affiseq_Lysate_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  **[['0.1', '10'], ['0.25', '25'], ['0.5', '50']].map{|fraction, percent|
    {
      "run_benchmarks_release_7/formatted_reads_pwmeval_#{fraction}.tsv" => [
        [[:"selex_#{percent}_IVT_ROC"], ->(x){ x.match?(/@HTS\.IVT@/) }],
        [[:"selex_#{percent}_Lysate_ROC"], ->(x){ x.match?(/@HTS\.Lys@/) }],
        [[:"affiseq_#{percent}_IVT_ROC"], ->(x){ x.match?(/@AFS\.IVT@/) }],
        [[:"affiseq_#{percent}_Lysate_ROC"], ->(x){ x.match?(/@AFS\.Lys@/) }],
        [[:"smileseq_#{percent}_ROC"], ->(x){ x.match?(/@SMS@/) }],
      ],
    }
  }.inject(&:merge),
  'run_benchmarks_release_7/formatted_pbm.tsv' => [
    [[:pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_roc, :pbm_qnzs_pr, :pbm_qnzs_mers,  :pbm_qnzs_logmers], ->(x){ x.match?(/@QNZS\./) }],
    [[:pbm_sdqn_asis, :pbm_sdqn_log, :pbm_sdqn_exp, :pbm_sdqn_roc, :pbm_sdqn_pr, :pbm_sdqn_mers, :pbm_sdqn_logmers], ->(x){ x.match?(/@SDQN\./) }],
  ],
}

all_metric_infos = read_metrics(metrics_readers_configs)

# reject motif benchmark values calculated over datasets which were used for training
# (there shouldn't be any)
all_metric_infos.reject!{|info|
  ds_and_motif_common_ids = dataset_ids_for_dataset(info[:dataset]) & dataset_ids_for_motif(info[:motif])
  $stderr.puts "#{info[:dataset]} and #{info[:motif]} are derived from the same datasets"
  !ds_and_motif_common_ids.empty?
}

all_metric_infos.select!{|info|
  exp_for_motif = dataset_ids_for_motif(info[:motif]).map{|ds_id| experiment_by_dataset_id[ds_id] }.take_the_only
  exp_for_bench_dataset = dataset_ids_for_dataset(info[:dataset]).map{|ds_id| experiment_by_dataset_id[ds_id] }.take_the_only

  # We expect here a bunch of PBM datasets
  if (exp_for_motif == exp_for_bench_dataset) && info['experiment_type'] == 'PBM'
    $stderr.puts "Warning: #{info[:dataset]} and #{info[:motif]} are derived from the same experiment #{exp_for_motif} and will be skipped"
    false
  else
    true
  end
}

all_metric_infos.select!{|info|
  exp_id = experiment_id(info[:dataset])
  if dataset_curation
    dataset_curation.has_key?(exp_id) ? dataset_curation[exp_id] : false # non-curated are dropped
  else
    true  # without curation take everything
  end
}

all_metric_infos = all_metric_infos.map{|info|
  dataset = info[:dataset]
  additional_info = {
    processing_type: experiment_processing_type(dataset),
    experiment: experiment_id(dataset),
    experiment_type: experiment_fulltype(dataset),
  }
  info.merge(additional_info)
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


hierarchy_of_metrics = make_metrics_hierarchy(ranked_motif_metrics, [:tf, :motif, :experiment_type, :experiment, :dataset, :processing_type]){|info|
  {metric_name: info[:metric_name], value: info[:value], rank: info[:rank]}
}

hierarchy_of_metrics_wo_ranks = make_metrics_hierarchy(ranked_motif_metrics, [:tf, :motif, :experiment_type, :experiment, :dataset, :processing_type]){|info|
  {metric_name: info[:metric_name], value: info[:value]}
}

augmented_rank_hierarchy = ranked_motif_metrics.group_by{|info| info[:tf] }.transform_values{|tf_infos|
  tf_infos.group_by{|info|
    info[:motif]
  }.transform_values{|motif_infos|
    motif_metrics_hierarchy = make_metrics_hierarchy(motif_infos, [:experiment_type, :experiment, :dataset, :processing_type])
    take_ranks(motif_metrics_hierarchy)
  }
}.each{|_tf, motif_ranks_hierarchies|
  possible_inner_paths(motif_ranks_hierarchies).each{|path|
    motif_ranks_hierarchies.map{|motif, hierarchy|
      path.empty? ? hierarchy : hierarchy.dig(*path)
    }.compact.map{|node|
      vals = node.select{|k,v| k != :combined }.values.compact
      if vals.all?(Numeric)
        combined_rank = product_mean(vals)
      else
        combined_rank = product_mean(vals.map{|val| val[:combined] })
      end
      {node: node, combined_rank: combined_rank}
    }.sort_by{|node_info|
      node_info[:combined_rank]
    }.chunk{|node_info|
      node_info[:combined_rank]
    }.each_with_index{|(_val, node_infos), index|
      node_infos.each{|node_info|
        node_info[:node][:combined] = index + 1
      }
    }
  }
}

FileUtils.mkdir_p('results')
File.write(results_metrics_fn, hierarchy_of_metrics_wo_ranks.to_json)
File.write(results_ranks_fn, augmented_rank_hierarchy.to_json)
