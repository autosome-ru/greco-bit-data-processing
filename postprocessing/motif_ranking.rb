require 'fileutils'
require 'erb'

module Enumerable
  def mean
    empty? ? nil : sum(0.0) / size
  end

  def stddev
    return nil  if size < 2
    m = mean
    (self.map{|x| (x-m) ** 2 }.sum(0.0) / (size - 1)) ** 0.5
  end
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

BASIC_RETAINED_METRICS = [
  # CHS peak metrics
  :chipseq_pwmeval_ROC, :chipseq_vigg_ROC, #:chipseq_vigg_logROC,
  :chipseq_centrimo_neglog_evalue, :chipseq_centrimo_concentration_30nt,

  # AFS peak metrics
  :affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, #:affiseq_IVT_vigg_logROC,
  :affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, #:affiseq_Lysate_vigg_logROC,
  :affiseq_IVT_centrimo_neglog_evalue, :affiseq_IVT_centrimo_concentration_30nt,
  :affiseq_Lysate_centrimo_neglog_evalue, :affiseq_Lysate_centrimo_concentration_30nt,

  # # AFS read metrics
  :affiseq_10_IVT_ROC, :affiseq_10_Lysate_ROC,
  :affiseq_50_IVT_ROC, :affiseq_50_Lysate_ROC,

  # # HTS read metrics
  :selex_10_IVT_ROC, :selex_10_Lysate_ROC,
  :selex_50_IVT_ROC, :selex_50_Lysate_ROC,

  # # SMS read metrics
  :smileseq_10_ROC, :smileseq_50_ROC,

  # PBM metrics
  # :pbm_qnzs_asis, :pbm_qnzs_log, :pbm_qnzs_exp, :pbm_qnzs_roc, :pbm_qnzs_pr, :pbm_qnzs_mers, :pbm_qnzs_logmers,
  # :pbm_sdqn_asis, :pbm_sdqn_log, :pbm_sdqn_exp, :pbm_sdqn_roc, :pbm_sdqn_pr, :pbm_sdqn_mers, :pbm_sdqn_logmers,
  :pbm_qnzs_roc, :pbm_qnzs_pr,
  :pbm_sdqn_roc, :pbm_sdqn_pr,
]
  # :combined, :affiseq_ROC, :selex_ROC, :pbm,
  # :affiseq_IVT_pwmeval_ROC, :affiseq_Lysate_pwmeval_ROC, :selex_10_IVT_ROC, :selex_10_Lysate_ROC,
# METRIC_COMBINATIONS = {
#   combined: {
#     chipseq_pwmeval_ROC: true,
#     affiseq_ROC: {
#       affiseq_IVT_pwmeval_ROC: true,
#       affiseq_Lysate_pwmeval_ROC: true,
#     },
#     selex_ROC: {
#       selex_10_IVT_ROC: true,
#       selex_10_Lysate_ROC: true,
#     },
#     pbm: {
#       pbm_qnzs: {
#         pbm_qnzs_asis: true,
#         pbm_qnzs_log: true,
#         pbm_qnzs_exp: true,
#         pbm_qnzs_roc: true,
#         pbm_qnzs_pr: true,
#       },
#       pbm_sdqn: {
#         pbm_sdqn_asis: true,
#         pbm_sdqn_log: true,
#         pbm_sdqn_exp: true,
#         pbm_sdqn_roc: true,
#         pbm_sdqn_pr: true,
#       }
#     }
#   }
# }

tfs_curration = read_tfs_curration('source_data_meta/shared/curation_tfs_vigg.tsv')

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

all_metric_infos = read_metrics(metrics_readers_configs).select{|info|
  BASIC_RETAINED_METRICS.include?(info[:metric_name])
}.select{|info|
  tf = info[:tf]
  metric_name = info[:metric_name]
  metric_type = METRIC_TYPE_BY_NAME[metric_name]
  tfs_curration[tf][:verdicts][metric_type] rescue true
}

module Enumerable
  def rank_by(start_with: 1, order: :large_better, &block)
    raise  unless block_given?
    raise  unless [:large_better, :small_better].include?(order)
    compactified_collection = self.select(&block)
    sorted_collection = compactified_collection.sort_by(&block).yield_self{|coll| (order == :large_better) ? coll.reverse : coll }
    sorted_collection.each_with_index.map{|obj, idx|
      [(idx + start_with), obj]
    }
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

# def combine_metrics(tree, leaf_block: ->(k,v){puts "leaf #{x}"; x}, combine_block: ->(tree){ puts "combine #{tree}"; tree })
#   p tree
#   if tree.size == 1
#     k = tree.keys.first
#     v = tree[k]
#     return leaf_block.call(k,v)  if !v.is_a?(Enumerable)
#   end
#   # raise  unless block_given?
#   tree_combined = tree.map{|parent, child|
#     combine_metrics(child, leaf_block: leaf_block, combine_block: combine_block)
#   }.to_h
#   combine_block.call(tree_combined)
# end
# combine_metrics(METRIC_COMBINATIONS)

motif_metrics_combined = all_metric_infos.group_by{|info|
  info[:tf]
}.flat_map{|tf, tf_metrics|
  tf_metrics.group_by{|info|
   info[:metric_name]
  }.flat_map{|metric_name, metric_infos|
    motif_ranks = Hash.new{|h,k| h[k] = [] }

    metric_infos.group_by{|info|
      info[:dataset]
    }.each{|dataset, infos|
      infos.rank_by(order: :large_better, start_with: 1){|info| info[:value] }.each{|rank, info|
        motif_ranks[ info[:motif] ] << {dataset: info[:dataset], rank: rank, value: info[:value]}
      }
    }

    motif_ranks.map{|motif, rank_infos|
      ranks = rank_infos.map{|rank_info| rank_info[:rank] }
      [motif, rank_infos, product_mean(ranks)]
    }.sort_by{|motif, rank_infos, agg_rank|
      agg_rank
    }.map{|motif, rank_infos, agg_rank|
      rank_details = rank_infos.map{|info| "#{info[:dataset]}: #{info[:rank]}" }.join(', ')
      {tf: tf, metric_name: metric_name, motif: motif, dataset_combined_rank: agg_rank, rank_details: rank_details, rank_infos: rank_infos}
    }
  }
}

FileUtils.mkdir_p('results')
File.open('results/metrics.tsv', 'w') do |fw|
  header = ['tf', 'metric', 'motif', 'dataset_combined_rank', 'rank_details']
  column_order = [:tf, :metric_name, :motif, :dataset_combined_rank, :rank_details]
  fw.puts header.join("\t")
  motif_metrics_combined.each{|info|
    row = info.values_at(*column_order)
    fw.puts row.join("\t")
  }
end

motif_centered_metrics = motif_metrics_combined.group_by{|info| info[:tf] }.flat_map{|tf, tf_infos|
  tf_infos.group_by{|info| info[:motif] }.map{|motif, motif_infos|
    motif_ranks = motif_infos.map{|info|
      [info[:metric_name], info[:dataset_combined_rank]]
    }.to_h
    combined_rank = product_mean(motif_ranks.values.compact)

    motif_values = motif_infos.map{|info|
      [info[:metric_name], info[:rank_infos].map{|rank_info| rank_info[:value] }]
    }.to_h
    ## METRIC_COMBINATIONS.each

    ################
    motif_ranks[:chipseq] = product_mean(motif_ranks.values_at(:chipseq_pwmeval_ROC, :chipseq_vigg_ROC, :chipseq_centrimo_concentration_30nt).compact)

    motif_ranks[:affiseq_IVT_peaks] = product_mean(motif_ranks.values_at(:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, :affiseq_IVT_centrimo_concentration_30nt).compact)
    motif_ranks[:affiseq_IVT_reads] = product_mean(motif_ranks.values_at(:affiseq_10_IVT_ROC, :affiseq_50_IVT_ROC).compact)
    motif_ranks[:affiseq_IVT] = product_mean(motif_ranks.values_at(:affiseq_IVT_peaks, :affiseq_IVT_reads).compact)

    motif_ranks[:affiseq_Lysate_peaks] = product_mean(motif_ranks.values_at(:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, :affiseq_Lysate_centrimo_concentration_30nt).compact)
    motif_ranks[:affiseq_Lysate_reads] = product_mean(motif_ranks.values_at(:affiseq_10_Lysate_ROC, :affiseq_50_Lysate_ROC).compact)
    motif_ranks[:affiseq_Lysate] = product_mean(motif_ranks.values_at(:affiseq_Lysate_peaks, :affiseq_Lysate_reads).compact)

    motif_ranks[:affiseq] = product_mean(motif_ranks.values_at(:affiseq_IVT, :affiseq_Lysate).compact)

    motif_ranks[:selex_IVT] = product_mean(motif_ranks.values_at(:selex_10_IVT_ROC, :selex_50_IVT_ROC).compact)
    motif_ranks[:selex_Lysate] = product_mean(motif_ranks.values_at(:selex_10_Lysate_ROC, :selex_50_Lysate_ROC).compact)
    motif_ranks[:selex] = product_mean(motif_ranks.values_at(:selex_IVT, :selex_Lysate).compact)

    motif_ranks[:pbm_sdqn] = product_mean(motif_ranks.values_at(:pbm_sdqn_roc, :pbm_sdqn_pr).compact)
    motif_ranks[:pbm_qnzs] = product_mean(motif_ranks.values_at(:pbm_qnzs_roc, :pbm_qnzs_pr).compact)
    motif_ranks[:pbm] = product_mean(motif_ranks.values_at(:pbm_sdqn, :pbm_qnzs).compact)

    motif_ranks[:smileseq] = product_mean(motif_ranks.values_at(:smileseq_10_ROC, :smileseq_50_ROC).compact)

    motif_ranks[:combined] = product_mean(motif_ranks.values_at(:chipseq, :affiseq, :selex, :pbm, :smileseq).compact)
    ################

    ################
    motif_values[:chipseq] = motif_values.values_at(:chipseq_pwmeval_ROC, :chipseq_vigg_ROC, :chipseq_centrimo_concentration_30nt).flatten

    motif_values[:affiseq_IVT_peaks] = motif_values.values_at(:affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, :affiseq_IVT_centrimo_concentration_30nt).flatten
    motif_values[:affiseq_IVT_reads] = motif_values.values_at(:affiseq_10_IVT_ROC, :affiseq_50_IVT_ROC).flatten
    motif_values[:affiseq_IVT] = motif_values.values_at(:affiseq_IVT_peaks, :affiseq_IVT_reads).flatten

    motif_values[:affiseq_Lysate_peaks] = motif_values.values_at(:affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, :affiseq_Lysate_centrimo_concentration_30nt).flatten
    motif_values[:affiseq_Lysate_reads] = motif_values.values_at(:affiseq_10_Lysate_ROC, :affiseq_50_Lysate_ROC).flatten
    motif_values[:affiseq_Lysate] = motif_values.values_at(:affiseq_Lysate_peaks, :affiseq_Lysate_reads).flatten

    motif_values[:affiseq] = motif_values.values_at(:affiseq_IVT, :affiseq_Lysate).flatten

    motif_values[:selex_IVT] = motif_values.values_at(:selex_10_IVT_ROC, :selex_50_IVT_ROC).flatten
    motif_values[:selex_Lysate] = motif_values.values_at(:selex_10_Lysate_ROC, :selex_50_Lysate_ROC).flatten
    motif_values[:selex] = motif_values.values_at(:selex_IVT, :selex_Lysate).flatten

    motif_values[:pbm_sdqn_roc] = motif_values.values_at(:pbm_sdqn_roc).flatten
    motif_values[:pbm_qnzs_roc] = motif_values.values_at(:pbm_qnzs_roc).flatten
    motif_values[:pbm_roc] = motif_values.values_at(:pbm_sdqn_roc, :pbm_qnzs_roc).flatten

    motif_values[:pbm_sdqn_pr] = motif_values.values_at(:pbm_sdqn_pr).flatten
    motif_values[:pbm_qnzs_pr] = motif_values.values_at(:pbm_qnzs_pr).flatten
    motif_values[:pbm_pr] = motif_values.values_at(:pbm_sdqn_pr, :pbm_qnzs_pr).flatten

    motif_values[:smileseq] = motif_values.values_at(:smileseq_10_ROC, :smileseq_50_ROC).flatten

    # motif_values[:combined] = motif_values.values_at(:chipseq_ROC, :affiseq_ROC, :selex, :pbm).flatten
    ################
    [tf, motif, motif_ranks, motif_values]
  }
}

motif_rankings = motif_centered_metrics.group_by{|tf, motif, motif_ranks, motif_values|
  tf
}.sort.flat_map{|tf, tf_metrics|
  tf_metrics.rank_by(order: :small_better, start_with: 1){|tf, motif, motif_ranks, motif_values|
    motif_ranks[:combined]
  }.map{|overall_rank, (tf, motif, motif_ranks, motif_values)|
    [tf, motif, overall_rank, motif_ranks, motif_values]
  }
}

metrics_order = [
  :combined, :chipseq, :affiseq, :selex, :pbm, :smileseq,
  :affiseq_IVT, :affiseq_Lysate,
  :selex_IVT, :selex_Lysate,
  :pbm_sdqn, :pbm_qnzs,

  :chipseq_pwmeval_ROC, :chipseq_vigg_ROC, :chipseq_centrimo_concentration_30nt, :chipseq_centrimo_neglog_evalue, #:chipseq_vigg_logROC,

  :affiseq_IVT_pwmeval_ROC, :affiseq_IVT_vigg_ROC, :affiseq_IVT_centrimo_concentration_30nt, :affiseq_IVT_centrimo_neglog_evalue, #:affiseq_IVT_vigg_logROC,
  :affiseq_10_IVT_ROC, :affiseq_50_IVT_ROC,

  :affiseq_Lysate_pwmeval_ROC, :affiseq_Lysate_vigg_ROC, :affiseq_Lysate_centrimo_concentration_30nt, :affiseq_Lysate_centrimo_neglog_evalue, #:affiseq_Lysate_vigg_logROC,
  :affiseq_10_Lysate_ROC, :affiseq_50_Lysate_ROC,

  :selex_10_IVT_ROC, :selex_10_Lysate_ROC,
  :selex_50_IVT_ROC, :selex_50_Lysate_ROC,

  :pbm_sdqn_roc, :pbm_sdqn_pr,
  :pbm_qnzs_roc, :pbm_qnzs_pr,

  :smileseq_10_ROC, :smileseq_50_ROC,
]

File.open('results/motif_metrics.tsv', 'w'){|fw|
  header = ['tf', 'motif', 'rank_overall', *metrics_order.map{|metric| "rank_#{metric}"} ]
  fw.puts(header.join("\t"))

  motif_rankings.each{|tf, motif, overall_rank, motif_ranks, motif_values|
    row = [tf, motif, overall_rank, motif_ranks.values_at(*metrics_order).map{|x| x&.round(2) }]
    fw.puts(row.join("\t"))
  }
}

class MotifMetricsFormatter
  def initialize(metrics_order, motif_rankings); @metrics_order, @motif_rankings = metrics_order, motif_rankings; end
  def get_binding; binding; end
end

FileUtils.cp_r(File.absolute_path('websrc', __dir__), 'results/websrc')
File.open('results/motif_metrics.html', 'w'){|fw|
  template_fn = File.absolute_path('templates/motif_metrics.html.erb', __dir__)
  renderer = ERB.new( File.read(template_fn) )
  formatter = MotifMetricsFormatter.new(metrics_order, motif_rankings)
  fw.puts renderer.result(formatter.get_binding)
}

##########################################################
FileUtils.mkdir_p "results/metrics_by_TF/"
motif_rankings.group_by{|tf,*rest| tf }.each do |tf, motif_rankings_part|
File.open("results/metrics_by_TF/#{tf}.html", 'w'){|fw|
  header = ['tf', 'motif', 'rank_overall', *metrics_order.map{|metric| "rank_#{metric}"} ]
  fw.puts <<-EOS
    <html><head>
    <meta charset="utf-8">
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/jquery.tablesorter.min.js" integrity="sha512-qzgd5cYSZcosqpzpn7zF2ZId8f/8CHmFKZ8j7mU4OUXTNRd5g+ZHBPsgKEwoqxCtdQvExE5LprwwPAgoicguNg==" crossorigin="anonymous"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/css/theme.blue.min.css" integrity="sha512-jJ9r3lTLaH5XXa9ZOsCQU8kLvxdAVzyTWO/pnzdZrshJQfnw1oevJFpoyCDr7K1lqt1hUgqoxA5e2PctVtlSTg==" crossorigin="anonymous" />
    <script>
    $(function() {
      $("table.tablesorter").tablesorter({
        theme: 'blue',
        widgets: ['zebra'],
        sortList: [[0,0], [2,0]]
      });
    });
    </script>
    <style>
    img{max-width: 400px;}
    </style></head><body>
    <table class="tablesorter tablesorter-blue"><thead><tr>
    <th class="group-word">TF</th>
    <th>logo</th>
    <th>overall rank</th>
    EOS
  metrics_order.each{|metric| fw.puts "<th>#{metric} rank</th>"}
  fw.puts <<-EOS
    <th>motif</th>
    </tr></thead><tbody>
  EOS

  motif_rankings_part.each{|tf, motif, overall_rank, motif_ranks, motif_values|
    motif_bn = File.basename(motif, File.extname(motif))
    row = [tf, "<img src='../../logo/#{motif_bn}.png' />", overall_rank, *motif_ranks.values_at(*metrics_order).map{|x| x&.round(2) }, motif]
    fw.puts('<tr>' + row.map{|x| "<td>#{x}</td>" }.join + '</tr>')
  }

  fw.puts <<-EOS
    </tbody></table>
    </body></html>
    EOS
}
end


##########################################################


winning_tools = motif_rankings.select{|tf, motif, overall_rank, ranks, motif_values|
  overall_rank == 1
}.map{|tf, motif, *rest|
  motif.match(/\w+@\w+/)[0]
}.each_with_object(Hash.new(0)){|tool, hsh|
  hsh[tool] += 1
}.sort_by{|k,v|
  -v
}.to_h

puts winning_tools

FileUtils.mkdir_p('results/metrics/')

metrics_order.each{|metric_name|
  motif_metrics_subset = all_metric_infos.select{|info| info[:metric_name] == metric_name }
  File.open("results/metrics/#{metric_name}.html", 'w'){|fw|
    fw.puts <<-EOS
    <html><head>
    <meta charset="utf-8">
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/jquery.tablesorter.min.js" integrity="sha512-qzgd5cYSZcosqpzpn7zF2ZId8f/8CHmFKZ8j7mU4OUXTNRd5g+ZHBPsgKEwoqxCtdQvExE5LprwwPAgoicguNg==" crossorigin="anonymous"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/css/theme.blue.min.css" integrity="sha512-jJ9r3lTLaH5XXa9ZOsCQU8kLvxdAVzyTWO/pnzdZrshJQfnw1oevJFpoyCDr7K1lqt1hUgqoxA5e2PctVtlSTg==" crossorigin="anonymous" />
    <script>
    $(function() {
      $("table.tablesorter").tablesorter({
        theme: 'blue',
        widgets: ['zebra']
      });
    });
    </script>
    <style>
    img{max-width: 400px;}
    </style></head><body>
    <table class="tablesorter tablesorter-blue"><thead><tr>
    <th>TF</th>
    <th>overall rank</th>
    <th>#{metric_name} rank</th>
    <th style="min-width:100px;">value</th>
    <th>logo</th>
    <th>motif</th>
    </tr></thead><tbody>
    EOS

    motif_rankings.select{|tf, motif, overall_rank, ranks, motif_values|
      ranks[metric_name]
    }.each{|tf, motif, overall_rank, ranks, motif_values|
      motif_bn = File.basename(motif, File.extname(motif))
      fw.puts '<tr>'
      motif_metric_infos = motif_metrics_subset.select{|info| info[:motif] == motif }
      if BASIC_RETAINED_METRICS.include?(metric_name)
        vals = motif_metric_infos.map{|info| info[:value] }
      else
        if [:pbm, :pbm_sdqn, :pbm_qnzs].include?(metric_name)
          vals_roc = motif_values.fetch("#{metric_name}_roc".to_sym).compact
          vals_pr = motif_values.fetch("#{metric_name}_pr".to_sym).compact
          vals_summary = "ROC: #{basic_stats(vals_roc)}; PR: #{basic_stats(vals_pr)}"
        elsif metric_name == :combined
          vals_summary = ''
        else
          vals = motif_values.fetch(metric_name).compact
          vals_summary = basic_stats(vals)
        end
      end
      row = [tf, overall_rank, ranks[metric_name].round(2), vals_summary, "<img src='../../logo/#{motif_bn}.png' />", motif]
      fw.puts row.map{|x| "<td>#{x}</td>" }.join
      fw.puts '</tr>'
    }


    fw.puts <<-EOS
    </tbody></table>
    </body></html>
    EOS
  }
}
