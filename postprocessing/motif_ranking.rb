require 'fileutils'
require 'json'
require 'set'
require 'optparse'
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
  if !method_defined?(:tally)
    def tally
      self.each_with_object(Hash.new(0)){|v, hsh| hsh[v] += 1 }
    end
  end
end

class Symbol
  if !method_defined?(:start_with?)
    def start_with?(string_or_regexp)
      self.to_s.start_with?(string_or_regexp)
    end
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

# dataset name: SCML4.DBD@PBM.ME@PBM13821.5GTGAAATTGTTATCCGCTCT@SD.pretty-sangria-dalmatian.Train.tsv
#               ZNF708.FL@HTS.Lys@AAT_A_CC40NGACATG.5ACGACGCTCTTCCGATCTCC.3GACATGAGATCGGAAGAGCA.C1+C2+C3@Reads.chummy-turquoise-cow+leaky-seashell-walrus+surly-gold-toad.Val.fastq.gz
#               ANKZF1.FL@CHS@THC_0165@Peaks.fuzzy-orange-tapir.Train.peaks
#               ARID2.FL@CHS@THC_0409.Rep-DIANA_0293@Peaks.snazzy-taupe-rabbit.Train.peaks

def experiment_id(dataset_fullname)
  exp_id, *rest = dataset_fullname.split('@')[2].split('.')
  rep = rest[0]
  result = (rep && rep.start_with?('Rep-')) ? "#{exp_id}.#{rep}" : exp_id
  SINGLETON_STRINGS[result]
end

def experiment_fulltype(dataset_fullname) # PBM.HK, AFS.Lys etc
  dataset_fullname.split('@')[1].then{|val| SINGLETON_STRINGS[val] }
end

def experiment_processing_type(dataset_fullname) # Peaks
  dataset_fullname.split('@')[3].split('.')[0].then{|val| SINGLETON_STRINGS[val] }
end

def dataset_ids_for_dataset(dataset_fullname)
  dataset_fullname.split('@')[3].split('.')[1].split('+')
end

# motif name: ZNF687.DBD@AFS.IVT@bluesy-eggplant-shrimp+seedy-puce-hyrax+snappy-vermilion-sparrow+stealthy-blue-heron@autosome-ru.ChIPMunk@topk_cycle=C1+C2+C3+C4_k=5_top=10000.pcm

def dataset_ids_for_motif(motif_fullname)
  motif_fullname.split('@')[2].split('+')
end

def motif_tf(motif)
  motif.split('@').first.split('.').first.then{|val| SINGLETON_STRINGS[val] }
end


def experiment_for_motif(motif, experiment_by_dataset_id)
  dataset_ids_for_motif(motif).map{|ds_id| experiment_by_dataset_id[ds_id] }.uniq.take_the_only.then{|val| SINGLETON_STRINGS[val] }
end
def experiment_for_dataset(dataset, experiment_by_dataset_id)
  dataset_ids_for_dataset(dataset).map{|ds_id| experiment_by_dataset_id[ds_id] }.uniq.take_the_only.then{|val| SINGLETON_STRINGS[val] }
end

def processing_type_for_motif(motif, processing_type_by_dataset_id)
  dataset_ids_for_motif(motif).map{|ds_id| processing_type_by_dataset_id[ds_id] }.uniq.take_the_only.then{|val| SINGLETON_STRINGS[val] }
end
def processing_type_for_dataset(dataset, processing_type_by_dataset_id)
  dataset_ids_for_dataset(dataset).map{|ds_id| processing_type_by_dataset_id[ds_id] }.uniq.take_the_only.then{|val| SINGLETON_STRINGS[val] }
end

SINGLETON_STRINGS = Hash.new{|h,k| h[k] = k }

def read_metrics(metrics_readers_configs)
  metrics_readers_configs.flat_map do |fn, fn_parsers|
    infos = File.open(fn){|f|
      f.each_line.drop(1).map do |line|
        line.chomp!
        dataset, motif, *values = line.split("\t")
        dataset_tf = dataset.split('.')[0]
        motif_tf = motif.split('.')[0]
        raise  unless dataset_tf == motif_tf
        tf = dataset_tf
        # experiment_type = experiment_fulltype(dataset)
        # experiment = experiment_id(dataset)
        values = values.map{|val| val == '' ? nil : (val && Float(val)) }
        {
          dataset: SINGLETON_STRINGS[dataset], motif: SINGLETON_STRINGS[motif], tf: SINGLETON_STRINGS[tf],
          # experiment_type: experiment_type, experiment: experiment,
          values: values,
        }
      rescue
        $stderr.puts "read metrics failed on line `#{line}`"
        raise
      end
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
  rescue
    $stderr.puts "read of file `#{fn}` failed"
    raise
  end
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

def get_experiment_verdicts(filename)
  File.readlines('source_data_meta/shared/experiment_verdicts.tsv').drop(1).map{|l|
    l.chomp.split("\t")
  }.map{|num, tf, exp_type, exp_id, verdict|
    [exp_id, verdict]
  }.to_h.transform_values{|verdict| verdict == 'good' }
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
    # {tf_1 => {...}, tf_2 => {...}} or {"PBM.HK" => {...}, "AFS.Lys" => {...}} or {"QNZS" => {...}, "SD" => {...}} etc
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
    chipseq_peaks: {
        chipseq_pwmeval: [:chipseq_pwmeval_ROC, :chipseq_pwmeval_PR],
        chipseq_vigg: [:chipseq_vigg_ROC, :chipseq_vigg_PR],
        chipseq_centrimo_neglog_evalue: [:chipseq_centrimo_neglog_evalue],
      },
    affiseq_IVT: {
      affiseq_IVT_peaks: {
        affiseq_IVT_pwmeval: [:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_pwmeval_PR],
        affiseq_IVT_vigg: [:affiseq_IVT_vigg_ROC, :affiseq_IVT_vigg_PR],
        affiseq_IVT_centrimo_neglog_evalue: [:affiseq_IVT_centrimo_neglog_evalue],
      },
      # affiseq_IVT_reads: {
      #   affiseq_10_IVT: [:affiseq_10_IVT_ROC, :affiseq_10_IVT_PR],
      #   affiseq_25_IVT: [:affiseq_25_IVT_ROC, :affiseq_25_IVT_PR],
      #   affiseq_50_IVT: [:affiseq_50_IVT_ROC, :affiseq_50_IVT_PR],
      # },
    },
    affiseq_GFPIVT: {
      affiseq_GFPIVT_peaks: {
        affiseq_GFPIVT_pwmeval: [:affiseq_GFPIVT_pwmeval_ROC, :affiseq_GFPIVT_pwmeval_PR],
        affiseq_GFPIVT_vigg: [:affiseq_GFPIVT_vigg_ROC, :affiseq_GFPIVT_vigg_PR],
        affiseq_GFPIVT_centrimo_neglog_evalue: [:affiseq_GFPIVT_centrimo_neglog_evalue],
      },
      # affiseq_GFPIVT_reads: {
      #   affiseq_10_GFPIVT: [:affiseq_10_GFPIVT_ROC, :affiseq_10_GFPIVT_PR],
      #   affiseq_25_GFPIVT: [:affiseq_25_GFPIVT_ROC, :affiseq_25_GFPIVT_PR],
      #   affiseq_50_GFPIVT: [:affiseq_50_GFPIVT_ROC, :affiseq_50_GFPIVT_PR],
      # },
    },
    affiseq_Lysate: {
      affiseq_Lysate_peaks: {
        affiseq_Lysate_pwmeval: [:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_pwmeval_PR],
        affiseq_Lysate_vigg: [:affiseq_Lysate_vigg_ROC, :affiseq_Lysate_vigg_PR],
        affiseq_Lysate_centrimo_neglog_evalue: [:affiseq_Lysate_centrimo_neglog_evalue],
      },
      # affiseq_Lysate_reads: {
      #   affiseq_10_Lysate: [:affiseq_10_Lysate_ROC, :affiseq_10_Lysate_PR],
      #   affiseq_25_Lysate: [:affiseq_25_Lysate_ROC, :affiseq_25_Lysate_PR],
      #   affiseq_50_Lysate: [:affiseq_50_Lysate_ROC, :affiseq_50_Lysate_PR],
      # },
    },
    selex_IVT: {
      selex_10_IVT: [:selex_10_IVT_ROC, :selex_10_IVT_PR],
      selex_25_IVT: [:selex_25_IVT_ROC, :selex_25_IVT_PR],
      selex_50_IVT: [:selex_50_IVT_ROC, :selex_50_IVT_PR],
    },
    selex_GFPIVT: {
      selex_10_GFPIVT: [:selex_10_GFPIVT_ROC, :selex_10_GFPIVT_PR],
      selex_25_GFPIVT: [:selex_25_GFPIVT_ROC, :selex_25_GFPIVT_PR],
      selex_50_GFPIVT: [:selex_50_GFPIVT_ROC, :selex_50_GFPIVT_PR],
    },
    selex_Lysate: {
      selex_10_Lysate: [:selex_10_Lysate_ROC, :selex_10_Lysate_PR],
      selex_25_Lysate: [:selex_25_Lysate_ROC, :selex_25_Lysate_PR],
      selex_50_Lysate: [:selex_50_Lysate_ROC, :selex_50_Lysate_PR],
    },
    pbm: {
      pbm_sd: [:pbm_sd_roc, :pbm_sd_pr],
      pbm_qnzs: [:pbm_qnzs_roc, :pbm_qnzs_pr],
    },
    smileseq: {
      smileseq_10: [:smileseq_10_ROC, :smileseq_10_PR],
      smileseq_25: [:smileseq_25_ROC, :smileseq_25_PR],
      smileseq_50: [:smileseq_50_ROC, :smileseq_50_PR],
    },
  },
}

METRICS_ORDER         = Node.construct_tree(METRIC_COMBINATIONS).each_node_bfs.map(&:key).reject(&:nil?)
BASIC_METRICS         = Node.construct_tree(METRIC_COMBINATIONS).each_node_bfs.select(&:leaf?).map(&:key).reject(&:nil?)
DERIVED_METRICS_ORDER = Node.construct_tree(METRIC_COMBINATIONS).each_node_bfs.reject(&:leaf?).map(&:key).reject(&:nil?)

curation_fn = nil
metadata_fn = nil
filter_out_curated_datasets = false
filter_out_pbm_motif_dataset_matches = false
flank_threshold = 4.0
flank_filters = []
artifacts_folder = nil
artifact_similarity_threshold = 2.0  # 1.0 is maximum possible similarity

option_parser = OptionParser.new{|opts|
  opts.on('--curation FILE', 'Specify dataset curation file. It will bew used to filter out bad datasets'){|fn|
    # 'source_data_meta/shared/curations.tsv'
    curation_fn = fn
    filter_out_curated_datasets = true
  }
  opts.on('--metadata FILE',  'Specify dataset metadata file. It will be used to recognize experiment_id by dataset_id\n' +
                              'and to filter out PBM benchmarks where motif and dataset use the same experiment'){|fn|
    # 'results/metadata_release_7a.json'
    metadata_fn = fn
    filter_out_pbm_motif_dataset_matches = true
  }
  opts.on('--flank-threshold VALUE', 'logpvalue threshold for motif occurrences in flanks to be classified as sticky flanks'){|val|
    flank_threshold = Float(val)
  }
  opts.on('--filter-sticky-flanks FILE', 'Add a file with a list of motif occurrences in flanks'){|fn|
    flank_filters << fn
  }
  opts.on('--artifact-similarities FOLDER', 'Add a folder with a list of motif similarities to artifacts'){|folder|
    artifacts_folder = folder
  }
  opts.on('--artifact-similarity-threshold VALUE', 'Minimal similarity to treat motif as an artifact'){|value|
    artifact_similarity_threshold = Float(value)
  }
}

option_parser.parse!(ARGV)
raise 'Specify resulting metrics file'  unless results_metrics_fn = ARGV[0]  # 'results/metrics.json'
raise 'Specify resulting ranks file'  unless results_ranks_fn = ARGV[1]  # 'results/ranks.json'

if curation_fn
  # dataset_curation = get_datasets_curation(read_curation_info(curation_fn))
  dataset_curation = get_experiment_verdicts(curation_fn)
else
  dataset_curation = nil
  $stderr.puts('Warning: no curation is used')
end

if metadata_fn
  metadata_full = read_metadata(metadata_fn)
  metadata_by_dataset_id = metadata_full.index_by{|info| info['dataset_id'] }
  experiment_by_dataset_id = metadata_by_dataset_id.transform_values{|info|
    rep = info.dig('experiment_params', 'replica')
    [info['experiment_id'], (rep ? "Rep-#{rep}" : nil)].compact.join('.')
  }
  processing_type_by_dataset_id = metadata_by_dataset_id.transform_values{|info| info['processing_type'] }
else
  experiment_by_dataset_id = nil
  processing_type_by_dataset_id = nil
  $stderr.puts('Warning: no metadata is used, thus there can be PBM motifs benchmarked on the same datasets which were used for training')
end

artifact_motifs = [].to_set
if artifacts_folder
  artifact_motifs = Dir.glob("#{artifacts_folder}/*").select{|motif_fn|
    sims = File.readlines(motif_fn).map{|l|
      artifact_motif, sim_to_artifact, *rest = l.chomp.split("\t")
      [artifact_motif, Float(sim_to_artifact)]
    }.map{|artifact_motif, sim|
      sim
    }
    sims.max >= artifact_similarity_threshold
  }.map{|fn|
    File.basename(fn)
  }.to_set
end

metrics_readers_configs = {
  'benchmarks/release_8d/final_formatted/pwmeval_peaks.tsv' => [
    [[:chipseq_pwmeval_ROC, :chipseq_pwmeval_PR], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_pwmeval_PR], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_GFPIVT_pwmeval_ROC, :affiseq_GFPIVT_pwmeval_PR], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
    [[:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_pwmeval_PR], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'benchmarks/release_8d/final_formatted/vigg_peaks.tsv' => [
    [[:chipseq_vigg_ROC, :chipseq_vigg_logROC], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_vigg_ROC, :affiseq_IVT_vigg_logROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_GFPIVT_vigg_ROC, :affiseq_GFPIVT_vigg_logROC], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
    [[:affiseq_Lysate_vigg_ROC, :affiseq_Lysate_vigg_logROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'benchmarks/release_8d/final_formatted/centrimo_peaks.tsv' => [
    [[:chipseq_centrimo_neglog_evalue, :chipseq_centrimo_concentration_30nt], ->(x){ x.match?(/@CHS@/) }],
    [[:affiseq_IVT_centrimo_neglog_evalue, :affiseq_IVT_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.IVT@/) }],
    [[:affiseq_GFPIVT_centrimo_neglog_evalue, :affiseq_GFPIVT_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
    [[:affiseq_Lysate_centrimo_neglog_evalue, :affiseq_Lysate_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.Lys@/) }],
  ],
  'benchmarks/release_8d/final_formatted/pbm.tsv' => [
    [[:pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_roc, :pbm_qnzs_pr, :pbm_qnzs_roclog, :pbm_qnzs_prlog, :pbm_qnzs_mers,  :pbm_qnzs_logmers], ->(x){ x.match?(/@QNZS\./) }],
    [[:pbm_sd_asis, :pbm_sd_log, :pbm_sd_exp, :pbm_sd_roc, :pbm_sd_pr, :pbm_sd_roclog, :pbm_sd_prlog, :pbm_sd_mers, :pbm_sd_logmers], ->(x){ x.match?(/@SD\./) }],
  ],
}

[['0.1', '10'], ['0.25', '25'], ['0.5', '50']].each{|fraction, percent|
  metrics_readers_configs["benchmarks/release_8d/final_formatted/reads_#{fraction}.tsv"] = [
    [[:"selex_#{percent}_IVT_ROC", :"selex_#{percent}_IVT_PR"], ->(x){ x.match?(/@HTS\.IVT@/) }],
    [[:"selex_#{percent}_GFPIVT_ROC", :"selex_#{percent}_GFPIVT_PR"], ->(x){ x.match?(/@HTS\.GFPIVT@/) }],
    [[:"selex_#{percent}_Lysate_ROC", :"selex_#{percent}_Lysate_PR"], ->(x){ x.match?(/@HTS\.Lys@/) }],
    # [[:"affiseq_#{percent}_IVT_ROC", :"affiseq_#{percent}_IVT_PR"], ->(x){ x.match?(/@AFS\.IVT@/) }],
    # [[:"affiseq_#{percent}_GFPIVT_ROC", :"affiseq_#{percent}_GFPIVT_PR"], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
    # [[:"affiseq_#{percent}_Lysate_ROC", :"affiseq_#{percent}_Lysate_PR"], ->(x){ x.match?(/@AFS\.Lys@/) }],
    [[:"smileseq_#{percent}_ROC", :"smileseq_#{percent}_PR"], ->(x){ x.match?(/@SMS@/) }],
  ]
}

basic_metrics_set = BASIC_METRICS.to_set
all_metric_infos = read_metrics(metrics_readers_configs).select{|info| basic_metrics_set.include?(info[:metric_name]) }
all_metric_infos.each{|info|
  raise unless info.has_key?(:value)
  info[:value] = info[:value]&.round(3)
}

# reject motif benchmark values calculated over datasets which were used for training
# (there shouldn't be any)
all_metric_infos.each{|info|
  ds_and_motif_common_ids = dataset_ids_for_dataset(info[:dataset]) & dataset_ids_for_motif(info[:motif])
  if !ds_and_motif_common_ids.empty?
    raise "#{info[:dataset]} and #{info[:motif]} are derived from the same datasets"
  end
}

if filter_out_curated_datasets
  all_metric_infos.select!{|info|
    exp_for_motif         = experiment_for_motif(info[:motif], experiment_by_dataset_id)
    exp_for_bench_dataset = experiment_for_dataset(info[:dataset], experiment_by_dataset_id)
    if dataset_curation.has_key?(exp_for_bench_dataset)
      if dataset_curation[exp_for_bench_dataset]
        true
      else
        info = ["discarded after curation", info[:dataset], exp_for_bench_dataset, info[:motif], exp_for_motif, info[:metric_name]]
        $stderr.puts(info.join("\t"))
        false
      end
    else
      info = ["discarded as non-currated", info[:dataset], exp_for_bench_dataset, info[:motif], exp_for_motif, info[:metric_name]]
      $stderr.puts(info.join("\t"))
      false # non-curated are dropped
    end
  }
end


if filter_out_pbm_motif_dataset_matches
  all_metric_infos.select!{|info|
    # PBM experiments are used both in train and validation datasets so we should manually exclude such cases. But we allow to train on SD and validate on QNZS
    if info[:metric_name].start_with?('pbm_'.freeze)
      exp_for_motif         = experiment_for_motif(info[:motif], experiment_by_dataset_id)
      exp_for_bench_dataset = experiment_for_dataset(info[:dataset], experiment_by_dataset_id)
      mot_processing_type   = processing_type_for_motif(info[:motif], processing_type_by_dataset_id)
      exp_processing_type   = processing_type_for_dataset(info[:dataset], processing_type_by_dataset_id)
      if (exp_for_motif == exp_for_bench_dataset) && (exp_processing_type == mot_processing_type)
        info = ["discarded because motif and dataset from the same experiment", info[:dataset], exp_for_bench_dataset, info[:motif], exp_for_motif, info[:metric_name]]
        $stderr.puts(info.join("\t"))
        false
      else
        true
      end
    else
      true
    end
  }
end


filter_out_benchmarks = flank_filters.flat_map{|filter_fn|
  File.readlines(filter_fn).map{|l|
    motif_wo_ext, tf, exp_id, flank_type, logpval, pos, strand = l.chomp.split("\t")
    raise "Can't handle non-dataset ids"  if exp_id == 'all'
    {motif_wo_ext: motif_wo_ext, exp_id: exp_id, logpval: Float(logpval)}
  }
}.select{|filter_info|
  filter_info[:logpval] >= flank_threshold
}

filter_out_motifs = filter_out_benchmarks.map{|filter_info|
  filter_info[:motif_wo_ext]
}.to_set

possible_file_extensions = ['.pcm', '.ppm', '.pwm'].map(&:freeze)
all_metric_infos.select!{|info|
  motif_wo_ext = possible_file_extensions.inject(info[:motif]){|fn, ext| File.basename(fn, ext) }
  if filter_out_motifs.include?(motif_wo_ext)
    info = ["discarded motif due to sticky flanks",  info[:motif]]
    $stderr.puts(info.join("\t"))
    false
  else
    true
  end
}


all_metric_infos.select!{|info|
  if artifact_motifs.include?(info[:motif])
    info = ["discarded motif due to high similarity with an artifact motif",  info[:motif]]
    $stderr.puts(info.join("\t"))
    false
  else
    true
  end
}

pbm_types = ['PBM.ME', 'PBM.HK'].map(&:freeze)
all_metric_infos.each{|info|
  dataset = info[:dataset]
  exp_type = experiment_fulltype(dataset)
  exp_type = SINGLETON_STRINGS['PBM']  if pbm_types.include?(exp_type) # distinct chip types are not too different to distinguish them
  additional_info = {
    processing_type: experiment_processing_type(dataset),
    experiment: experiment_id(dataset),
    experiment_type: exp_type,
  }
  info.merge!(additional_info)
}

# what is called a dataset here is actually a validation group
ranked_motif_metrics = all_metric_infos.group_by{|info|
  [info[:tf], info[:dataset], info[:metric_name]]
}.flat_map{|(tf, dataset, metric_name), tf_metrics|
  tf_metrics.rank_by(order: :large_better, start_with: 1){|info|
    info[:value]
  }.map{|rank, info|
    info.merge!(rank: rank)
  }
}


hierarchy_of_metrics = make_metrics_hierarchy(ranked_motif_metrics, [:tf, :motif, :experiment_type, :experiment, :processing_type, :dataset]){|info|
  {metric_name: info[:metric_name], value: info[:value]}
}

augmented_rank_hierarchy = ranked_motif_metrics.group_by{|info| info[:tf] }.transform_values{|tf_infos|
  tf_infos.group_by{|info|
    info[:motif]
  }.transform_values{|motif_infos|
    motif_metrics_hierarchy = make_metrics_hierarchy(motif_infos, [:experiment_type, :experiment, :processing_type, :dataset])
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
File.write(results_metrics_fn, hierarchy_of_metrics.to_json)
File.write(results_ranks_fn, augmented_rank_hierarchy.to_json)
