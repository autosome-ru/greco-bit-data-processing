require 'fileutils'
require 'json'
require 'set'
require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/utils'

SINGLETON_STRINGS = Hash.new{|h,k| h[k] = k }

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

# Was used earliest. Now use get_list_of_good_datasets instead
def get_datasets_curation(curation_info)
  curation_info.select{|info|
    info[:exp_name] && info[:vote]
  }.group_by{|info|
    info[:exp_name]
  }.transform_values{|infos|
    infos.map{|info| info[:vote] }
  }.transform_values{|votes| votes.sum > 0 }
end

# Was used earlier. Now use get_list_of_good_datasets instead
def get_experiment_verdicts(filename)
  File.readlines(filename).drop(1).map{|l|
    l.chomp.split("\t")
  }.map{|num, tf, exp_type, exp_id, verdict|
    [exp_id, verdict]
  }.to_h.transform_values{|verdict| verdict == 'good' }
end

def get_list_of_good_datasets(filename)
  File.readlines(filename).drop(1).map{|l|
    l.chomp.split("\t")
  }.map{|dataset_id, *rest|
    [dataset_id, true]
  }.to_h
end

def get_list_of_good_motifs(filename)
  File.readlines(filename).drop(1).map{|l|
    motif = l.chomp.split("\t").first
    [motif, true]
  }.to_h
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

def read_metadata_subset(metadata_fn)
  File.open(metadata_fn){|f|
    f.each_line.map{|l|
      info = JSON.parse(l.chomp)
      {
        'dataset_id' => info['dataset_id'],
        'experiment_id' => info['experiment_id'],
        'replicate' => info.dig('experiment_params', 'replica'),
        'processing_type' => info['processing_type'],
      }
    }
  }
end

def load_exp_id_and_processing_type_by_dataset_id(metadata_fn)
  if metadata_fn
    metadata = read_metadata_subset(metadata_fn)
    metadata_by_dataset_id = metadata.index_by{|info| info['dataset_id'] }
    experiment_by_dataset_id = metadata_by_dataset_id.transform_values{|info|
      rep = info['replicate']
      [info['experiment_id'], (rep ? "Rep-#{rep}" : nil)].compact.join('.').then{|val| SINGLETON_STRINGS[val] }
    }
    processing_type_by_dataset_id = metadata_by_dataset_id.transform_values{|info| info['processing_type'].then{|val| SINGLETON_STRINGS[val] } }
  else
    experiment_by_dataset_id = nil
    processing_type_by_dataset_id = nil
    $stderr.puts('Warning: no metadata is used, thus there can be PBM motifs benchmarked on the same datasets which were used for training')
  end
  [experiment_by_dataset_id, processing_type_by_dataset_id]
end

def load_artifact_motifs(artifacts_folder, artifact_similarity_threshold, ignore_motifs: [])
  artifact_motifs = [].to_set
  if artifacts_folder
    artifact_motifs = Dir.glob("#{artifacts_folder}/*").select{|motif_fn|
      sims = File.readlines(motif_fn).map{|l|
        artifact_motif, sim_to_artifact, *rest = l.chomp.split("\t")
        [artifact_motif, Float(sim_to_artifact)]
      }.reject{|artifact_motif, sim|
        ignore_motifs.include?(artifact_motif)
      }.map{|artifact_motif, sim|
        sim
      }
      sims.max >= artifact_similarity_threshold
    }.map{|fn|
      File.basename(fn)
    }.to_set
  end
  artifact_motifs
end

def metrics_readers_configs(folder)
  result = {
    "#{folder}/pwmeval_peaks.tsv" => [
      [[:chipseq_pwmeval_ROC, :chipseq_pwmeval_PR], ->(x){ x.match?(/@CHS@/) }],
      [[:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_pwmeval_PR], ->(x){ x.match?(/@AFS\.IVT@/) }],
      [[:affiseq_GFPIVT_pwmeval_ROC, :affiseq_GFPIVT_pwmeval_PR], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
      [[:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_pwmeval_PR], ->(x){ x.match?(/@AFS\.Lys@/) }],
    ],
    "#{folder}/vigg_peaks.tsv" => [
      # logRoc not actually used
      [[:chipseq_vigg_ROC, :chipseq_vigg_logROC], ->(x){ x.match?(/@CHS@/) }],
      [[:affiseq_IVT_vigg_ROC, :affiseq_IVT_vigg_logROC], ->(x){ x.match?(/@AFS\.IVT@/) }],
      [[:affiseq_GFPIVT_vigg_ROC, :affiseq_GFPIVT_vigg_logROC], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
      [[:affiseq_Lysate_vigg_ROC, :affiseq_Lysate_vigg_logROC], ->(x){ x.match?(/@AFS\.Lys@/) }],
    ],
    "#{folder}/centrimo_peaks.tsv" => [
      # concentration not actually used
      [[:chipseq_centrimo_neglog_evalue, :chipseq_centrimo_concentration_30nt], ->(x){ x.match?(/@CHS@/) }],
      [[:affiseq_IVT_centrimo_neglog_evalue, :affiseq_IVT_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.IVT@/) }],
      [[:affiseq_GFPIVT_centrimo_neglog_evalue, :affiseq_GFPIVT_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
      [[:affiseq_Lysate_centrimo_neglog_evalue, :affiseq_Lysate_centrimo_concentration_30nt], ->(x){ x.match?(/@AFS\.Lys@/) }],
    ],
    "#{folder}/pbm.tsv" => [
      [[:pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_roc, :pbm_qnzs_pr, :pbm_qnzs_roclog, :pbm_qnzs_prlog, :pbm_qnzs_mers,  :pbm_qnzs_logmers], ->(x){ x.match?(/@QNZS\./) }],
      [[:pbm_sd_asis, :pbm_sd_log, :pbm_sd_exp, :pbm_sd_roc, :pbm_sd_pr, :pbm_sd_roclog, :pbm_sd_prlog, :pbm_sd_mers, :pbm_sd_logmers], ->(x){ x.match?(/@SD\./) }],
    ],
  }

  [['0.1', '10'], ['0.25', '25'], ['0.5', '50']].each{|fraction, percent|
    result["#{folder}/reads_#{fraction}.tsv"] = [
      [[:"selex_#{percent}_IVT_ROC", :"selex_#{percent}_IVT_PR"], ->(x){ x.match?(/@HTS\.IVT@/) }],
      [[:"selex_#{percent}_GFPIVT_ROC", :"selex_#{percent}_GFPIVT_PR"], ->(x){ x.match?(/@HTS\.GFPIVT@/) }],
      [[:"selex_#{percent}_Lysate_ROC", :"selex_#{percent}_Lysate_PR"], ->(x){ x.match?(/@HTS\.Lys@/) }],
      # [[:"affiseq_#{percent}_IVT_ROC", :"affiseq_#{percent}_IVT_PR"], ->(x){ x.match?(/@AFS\.IVT@/) }],
      # [[:"affiseq_#{percent}_GFPIVT_ROC", :"affiseq_#{percent}_GFPIVT_PR"], ->(x){ x.match?(/@AFS\.GFPIVT@/) }],
      # [[:"affiseq_#{percent}_Lysate_ROC", :"affiseq_#{percent}_Lysate_PR"], ->(x){ x.match?(/@AFS\.Lys@/) }],
      [[:"smileseq_#{percent}_ROC", :"smileseq_#{percent}_PR"], ->(x){ x.match?(/@SMS@/) }],
    ]
  }

  result
end

######################################################

curation_fn = nil
motifs_curation_fn = nil
metadata_fn = nil
filter_out_curated_datasets = false
filter_out_curated_motifs = false
filter_out_pbm_motif_dataset_matches = false
flank_threshold = 4.0
flank_filters = []
artifacts_folder = nil
artifact_similarity_threshold = 2.0  # 1.0 is maximum possible similarity
filter_by_tf = false
tf_list = nil
ignore_artifact_motifs = []

option_parser = OptionParser.new{|opts|
  # Now datasets, not experiments!
  opts.on('--datasets-curation FILE', 'Specify dataset curation file. It will bew used to filter out bad datasets'){|fn|
    curation_fn = fn  # 'metadata.tsv'
    filter_out_curated_datasets = true
  }
  opts.on('--motifs-curation FILE', 'Specify motifs curation file. It will be used to choose only relevant motifs'){|fn|
    motifs_curation_fn = fn  # 'motif_infos.tsv'
    filter_out_curated_motifs = true
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
  opts.on('--selected-tfs LIST', 'Calculate metrics only for TFs from a list. Separate TFs with commas.'){|value|
    filter_by_tf = true
    tf_list = value.split(',')
  }
  opts.on('--dataset-types LIST', 'Calculate metrics only for datasets of given datatypes (SMS, CHS, HTS.Lys, HTS.IVT, HTS.GFPIVT, AFS.Lys, AFS.IVT, AFS.GFPIVT, PBM.ME, PBM.HK). Separate datatypes with commas.'){|value|
    filter_by_dataset_datatypes = true
    acceptable_dataset_datatypes = value.split(',')
  }
  opts.on('--ignore-artifact-motifs LIST', "Don't take specified artfact motifs into account. Separate motifs with commas") {|value|
    ignore_artifact_motifs = value.split(',')
  }
}

option_parser.parse!(ARGV)
raise 'Specify benchmarks folder'  unless benchmarks_folder = ARGV[0]  # 'benchmarks/release_8d/final_formatted/'
raise 'Specify resulting metrics file'  unless results_metrics_fn = ARGV[1]  # 'results/metrics.json'
raise 'Specify resulting ranks file'  unless results_ranks_fn = ARGV[2]  # 'results/ranks.json'

######################################################

if curation_fn
  # dataset_curation = get_datasets_curation(read_curation_info(curation_fn))
  # dataset_curation = get_experiment_verdicts(curation_fn)
  dataset_curation = get_list_of_good_datasets(curation_fn)
else
  dataset_curation = nil
  $stderr.puts('Warning: no dataset curation is used')
end

if motifs_curation_fn
  motifs_curation = get_list_of_good_motifs(motifs_curation_fn)
else
  motifs_curation = nil
  $stderr.puts('Warning: no motifs curation is used')
end

puts "datasets curation #{dataset_curation.size}; motifs curation #{motifs_curation.size};"

experiment_by_dataset_id, processing_type_by_dataset_id = load_exp_id_and_processing_type_by_dataset_id(metadata_fn)
artifact_motifs = load_artifact_motifs(artifacts_folder, artifact_similarity_threshold, ignore_motifs: ignore_artifact_motifs)

######################################################

basic_metrics_set = [
  :chipseq_pwmeval_ROC, :chipseq_pwmeval_PR, :chipseq_vigg_ROC, :chipseq_centrimo_neglog_evalue,
  :selex_10_IVT_ROC, :selex_10_IVT_PR, :selex_25_IVT_ROC, :selex_25_IVT_PR, :selex_50_IVT_ROC, :selex_50_IVT_PR, :selex_10_GFPIVT_ROC,
  :selex_10_GFPIVT_PR, :selex_25_GFPIVT_ROC, :selex_25_GFPIVT_PR, :selex_50_GFPIVT_ROC, :selex_50_GFPIVT_PR, :selex_10_Lysate_ROC,
  :selex_10_Lysate_PR, :selex_25_Lysate_ROC, :selex_25_Lysate_PR, :selex_50_Lysate_ROC, :selex_50_Lysate_PR, :pbm_sd_roc,
  :pbm_sd_pr, :pbm_qnzs_roc, :pbm_qnzs_pr, :smileseq_10_ROC,
  :smileseq_10_PR, :smileseq_25_ROC, :smileseq_25_PR, :smileseq_50_ROC, :smileseq_50_PR, :affiseq_IVT_pwmeval_ROC,
  :affiseq_IVT_pwmeval_PR, :affiseq_IVT_vigg_ROC, :affiseq_IVT_centrimo_neglog_evalue, :affiseq_GFPIVT_pwmeval_ROC,
  :affiseq_GFPIVT_pwmeval_PR, :affiseq_GFPIVT_vigg_ROC, :affiseq_GFPIVT_centrimo_neglog_evalue,   :affiseq_Lysate_pwmeval_ROC,
  :affiseq_Lysate_pwmeval_PR, :affiseq_Lysate_vigg_ROC, :affiseq_Lysate_centrimo_neglog_evalue
].to_set
all_metric_infos = read_metrics(metrics_readers_configs(benchmarks_folder)).select{|info| basic_metrics_set.include?(info[:metric_name]) }

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

puts "initial size: #{all_metric_infos.size}"

if filter_by_dataset_datatypes
  all_metric_infos.select!{|info|
    dataset_datatype = info[:dataset].split('@')[1]
    acceptable_dataset_datatypes.include?(dataset_datatype)
  }
end

puts "after filtered by dataset datatypes: #{all_metric_infos.size}"

if filter_by_tf
  all_metric_infos.select!{|info|
    tf_list.include?(info[:tf])
  }
end

puts "after filtered by TF list: #{all_metric_infos.size}"

if filter_out_curated_datasets
  all_metric_infos.select!{|info|
    dataset_ids_for_dataset(info[:dataset]).any?{|ds_id| dataset_curation[ds_id] }
    # exp_for_motif         = experiment_for_motif(info[:motif], experiment_by_dataset_id)
    # exp_for_bench_dataset = experiment_for_dataset(info[:dataset], experiment_by_dataset_id)
    # if dataset_curation.has_key?(exp_for_bench_dataset)
    #   if dataset_curation[exp_for_bench_dataset]
    #     true
    #   else
    #     info = ["discarded after curation", info[:dataset], exp_for_bench_dataset, info[:motif], exp_for_motif, info[:metric_name]]
    #     $stderr.puts(info.join("\t"))
    #     false
    #   end
    # else
    #   info = ["discarded as non-curated", info[:dataset], exp_for_bench_dataset, info[:motif], exp_for_motif, info[:metric_name]]
    #   $stderr.puts(info.join("\t"))
    #   false # non-curated are dropped
    # end
  }
end

puts "after filtered curated datasets: #{all_metric_infos.size}"

if filter_out_curated_motifs
  all_metric_infos.select!{|info|
    motifs_curation[ info[:motif] ]
  }
end

puts "after filtered curated motifs: #{all_metric_infos.size}"

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

puts "after filtered out PBMs: #{all_metric_infos.size}"

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

puts "after filtered sticky flanks: #{all_metric_infos.size}"


all_metric_infos.select!{|info|
  if artifact_motifs.include?(info[:motif])
    info = ["discarded motif due to high similarity with an artifact motif",  info[:motif]]
    $stderr.puts(info.join("\t"))
    false
  else
    true
  end
}

puts "after filtered out artifacts: #{all_metric_infos.size}"

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

######################################################

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
