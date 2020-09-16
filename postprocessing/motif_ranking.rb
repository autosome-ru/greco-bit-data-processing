require 'fileutils'

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

## fix bug: different TF names for the same TF (e.g. CxxC4 --> CXXC4, zf-CXXC4 --> CXXC4)
TF_NAME_MAPPING = File.readlines('tf_name_mapping.txt').map{|l| l.chomp.split("\t") }.to_h

## fix bug: pbm_roclog and pbm_prlog are equivalent to pbm_roc and pbm_log
RETAINED_METRICS = [
  :combined, :chipseq_ROC, :affiseq_ROC, :selex_ROC, :pbm_combined,
  :affiseq_IVT_ROC, :affiseq_Lysate_ROC, :selex_IVT_ROC, :selex_Lysate_ROC,
  :pbm_asis, :pbm_log, :pbm_exp, :pbm_roc, :pbm_pr,
]

METRIC_COMBINATIONS = {
  combined: {
    chipseq_ROC: true,
    affiseq_ROC: {
      affiseq_IVT_ROC: true,
      affiseq_Lysate_ROC: true,
    },
    selex_ROC: {
      selex_IVT_ROC: true,
      selex_Lysate_ROC: true,
    },
    pbm_combined: {
      pbm_qn_zscore: {
        pbm_qn_zscore_asis: true,
        pbm_qn_zscore_log: true,
        pbm_qn_zscore_exp: true,
        pbm_qn_zscore_roc: true,
        pbm_qn_zscore_pr: true,
      },
      pbm_sd_qn: {
        pbm_sd_qn_asis: true,
        pbm_sd_qn_log: true,
        pbm_sd_qn_exp: true,
        pbm_sd_qn_roc: true,
        pbm_sd_qn_pr: true,
      }
    }
  }
}


all_metric_infos = [
  ['results/parsed_chipseq_affiseq_metrics.tsv', [:chipseq_ROC], ->(x){ x.match?(/\.chipseq\./) }],
  ['results/parsed_chipseq_affiseq_metrics.tsv', [:affiseq_IVT_ROC], ->(x){ x.match?(/\.affiseq\./) && x.match?(/\.IVT\./) }],
  ['results/parsed_chipseq_affiseq_metrics.tsv', [:affiseq_Lysate_ROC], ->(x){ x.match?(/\.affiseq\./) && x.match?(/\.Lysate\./) }],
  ['results/parsed_selex_metrics.tsv', [:selex_IVT_ROC], ->(x){ x.match?(/\.selex\./) && x.match?(/\.IVT\./) }],
  ['results/parsed_selex_metrics.tsv', [:selex_Lysate_ROC], ->(x){ x.match?(/\.selex\./) && x.match?(/\.Lysate\./) }],
  ['results/parsed_pbm_metrics.tsv', [:pbm_qn_zscore_asis, :pbm_qn_zscore_log, :pbm_qn_zscore_exp, :pbm_qn_zscore_roc, :pbm_qn_zscore_pr], ->(x){ x.match?(/\.quantNorm_zscore\./) }],
  ['results/parsed_pbm_metrics.tsv', [:pbm_sd_qn_asis, :pbm_sd_qn_log, :pbm_sd_qn_exp, :pbm_sd_qn_roc, :pbm_sd_qn_pr], ->(x){ x.match?(/\.spatialDetrend_quantNorm\./) }],
].flat_map{|fn, metric_names, condition|
  File.readlines(fn).drop(1).flat_map{|l|
    dataset, motif, *values = l.chomp.split("\t")
    dataset_tf = dataset.split('.')[0]
    motif_tf = motif.split('.')[0]
    dataset_tf = TF_NAME_MAPPING.fetch(dataset_tf, dataset_tf)
    motif_tf = TF_NAME_MAPPING.fetch(motif_tf, motif_tf)
    raise  unless dataset_tf == motif_tf
    metric_names.zip(values).map{|metric_name, value|
      {dataset: dataset, motif: motif, value: Float(value), metric_name: metric_name, tf: dataset_tf}
    }.select{|info|
      condition.call(info[:dataset])
    }
  }
}.select{|info|
  RETAINED_METRICS.include?(info[:metric_name])
}

module Enumerable
  def rank_by(start_with: 1, order: :large_better, &block)
    raise  unless block_given?
    raise  unless [:large_better, :small_better].include?(order)
    sorted_collection = self.sort_by(&block).yield_self{|coll| (order == :large_better) ? coll.reverse : coll }
    sorted_collection.each_with_index.map{|obj, idx|
      [(idx + start_with), obj]
    }
  end
end

def product_mean(values)
  values.size == 0 ? nil : values.inject(1.0, &:*) ** (1.0 / values.size)
end

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
        motif_ranks[ info[:motif] ] << {dataset: info[:dataset], rank: rank}
      }
    }
    
    motif_ranks.map{|motif, rank_infos|
      ranks = rank_infos.map{|rank_info| rank_info[:rank] }
      [motif, rank_infos, product_mean(ranks)]
    }.sort_by{|motif, rank_infos, agg_rank|
      agg_rank
    }.map{|motif, rank_infos, agg_rank|
      rank_details = rank_infos.map{|info| "#{info[:dataset]}: #{info[:rank]}" }.join(', ')
      {tf: tf, metric_name: metric_name, motif: motif, dataset_combined_rank: agg_rank, rank_details: rank_details}
    }
  }
}


File.open('results/metrics.tsv', 'w') do |fw|
  header = ['tf', 'metric', 'motif', 'dataset_combined_rank', 'rank_details']
  column_order = [:tf, :metric_name, :motif, :dataset_combined_rank, :rank_details]
  fw.puts header.join("\t")
  motif_metrics_combined.each{|info|
    row = info.values_at(*column_order)
    fw.puts row.join("\t")
  }
end

# def combine_metrics(motif_ranks, combination, &block)
#   raise  unless block_given?
#   combination.map{|resulting_metric, incoming_metrics|
#     return motif_ranks[incoming_metrics]  if incoming_metrics == true
#     incoming_metrics.map{|metric|
      
#     }
#   }
#   motif_ranks.merge()

# end

motif_centered_metrics = motif_metrics_combined.group_by{|info| info[:tf] }.flat_map{|tf, tf_infos|
  tf_infos.group_by{|info| info[:motif] }.map{|motif, motif_infos|
    motif_ranks = motif_infos.map{|info|
      [info[:metric_name], info[:dataset_combined_rank]]
    }.to_h
    combined_rank = product_mean(motif_ranks.values.compact)
    ## METRIC_COMBINATIONS.each


    motif_ranks[:affiseq_ROC] = product_mean(motif_ranks.values_at(:affiseq_IVT_ROC, :affiseq_Lysate_ROC).compact)
    motif_ranks[:selex_ROC] = product_mean(motif_ranks.values_at(:selex_IVT_ROC, :selex_Lysate_ROC).compact)
    motif_ranks[:pbm_sd_qn] = product_mean(motif_ranks.values_at(:pbm_sd_qn_asis, :pbm_sd_qn_log, :pbm_sd_qn_exp, :pbm_sd_qn_roc, :pbm_sd_qn_pr).compact)
    motif_ranks[:pbm_qn_zscore] = product_mean(motif_ranks.values_at(:pbm_qn_zscore_asis, :pbm_qn_zscore_log, :pbm_qn_zscore_exp, :pbm_qn_zscore_roc, :pbm_qn_zscore_pr).compact)
    motif_ranks[:pbm_combined] = product_mean(motif_ranks.values_at(:pbm_sd_qn, :pbm_qn_zscore).compact)
    motif_ranks[:combined] = product_mean(motif_ranks.values_at(:chipseq_ROC, :affiseq_ROC, :selex_ROC, :pbm_combined).compact)
    [tf, motif, motif_ranks]
  }
}

motif_rankings = motif_centered_metrics.group_by{|tf, motif, motif_ranks|
  tf
}.sort.flat_map{|tf, tf_metrics|
  tf_metrics.rank_by(order: :small_better, start_with: 1){|tf, motif, motif_ranks|
    motif_ranks[:combined]
  }.map{|overall_rank, (tf, motif, motif_ranks)|
    [tf, motif, overall_rank, motif_ranks]
  }
}

metrics_order = [
  :combined, :chipseq_ROC, :affiseq_ROC, :selex_ROC, :pbm_combined, :pbm_sd_qn, :pbm_qn_zscore,
  :affiseq_IVT_ROC, :affiseq_Lysate_ROC, :selex_IVT_ROC, :selex_Lysate_ROC,
  :pbm_qn_zscore_asis, :pbm_qn_zscore_log, :pbm_qn_zscore_exp, :pbm_qn_zscore_roc, :pbm_qn_zscore_pr, 
  :pbm_sd_qn_asis, :pbm_sd_qn_log, :pbm_sd_qn_exp, :pbm_sd_qn_roc, :pbm_sd_qn_pr, 
]

File.open('results/motif_metrics.tsv', 'w'){|fw|
  header = ['tf', 'motif', 'rank_overall', *metrics_order.map{|metric| "rank_#{metric}"} ]
  fw.puts(header.join("\t"))

  motif_rankings.each{|tf, motif, overall_rank, motif_ranks|
    row = [tf, motif, overall_rank, motif_ranks.values_at(*metrics_order).map{|x| x&.round(2) }]
    fw.puts(row.join("\t"))
  }
}


winning_tools = motif_rankings.select{|tf, motif, overall_rank, ranks|
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

    motif_rankings.select{|tf, motif, overall_rank, ranks|
      ranks[metric_name]
    }.each{|tf, motif, overall_rank, ranks|
      motif_bn = File.basename(motif, File.extname(motif))
      fw.puts '<tr>'
      motif_metric_infos = motif_metrics_subset.select{|info| info[:motif] == motif }
      vals = motif_metric_infos.map{|info| info[:value] }
      row = [tf, overall_rank, ranks[metric_name], "#{vals.mean&.round(2)} ± #{vals.stddev&.round(2)}", "<img src='../../logo/#{motif_bn}.png' />", motif]
      fw.puts row.map{|x| "<td>#{x}</td>" }.join
      fw.puts '</tr>'
    }
    

    fw.puts <<-EOS
    </tbody></table>
    </body></html>
    EOS
  }
}
