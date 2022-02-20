require_relative 'statistics'

# map elements into their ranks (multiple ranks for tying elements)
def ranks(vs, &by_block)
  by_block = ->(x){ x }  unless block_given?
  vs
  .each_with_index
  .map{|v, idx|  {value: v, orig_idx: idx, comparison_value: by_block.call(v)}  }
  .sort_by{|info|  info[:comparison_value]  }
  .each_with_index
  .chunk{|info, rank|  info[:comparison_value]  }
  .flat_map{|_comparison_value, pairs|
    ranks = pairs.map{|info, rank| rank }
    pairs.map{|info, rank|
      info.merge({ranks: ranks}) # we don't wanr a single rank but all ranks
    }
  }
  .sort_by{|info|
    info[:orig_idx]
  }.map{|info|
    info[:ranks]
  }
end

def values_with_ranks(values)
  values.zip( ranks(values) )
end

# [[sample 1 values], [sample 2 values], ...] -> {rank => average_value}
def average_values_by_rank(samples)
  total_values_sum_by_rank = Hash.new(0)
  samples.each{|sample|
    values_with_ranks(sample).each{|val, ranks|
      ranks.each{|rank|
        total_values_sum_by_rank[rank] += val * (1.0 / ranks.size) # not to count value several times
      }
    }
  }
  total_values_sum_by_rank.transform_values{|sum_total| sum_total.to_f / samples.size }
end

# [[sample 1 values], [sample 2 values], ...] -> [[sample 1 qn-values], [sample 2 qn-values], ...]
# sets of qn-values for each sample are the same (unless there are ties).
#  qn-values are equal to average values (across samples) for each rank. Ranks are taken along a single sample.
def quantile_normalization(samples)
  value_by_rank = average_value_by_rank(samples)

  samples.map{|sample|
    ranks(sample).map{|ranks| ranks.map{|rank| value_by_rank[rank] }.mean }
  }
end
