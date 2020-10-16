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

def quantile_normalization(samples)
  values_by_rank = Hash.new(0)
  samples.each{|sample|
    sample_ranks = ranks(sample)
    sample.zip(sample_ranks).each{|val, ranks|
      ranks.each{|rank|
        values_by_rank[rank] += val * (1.0 / ranks.size) # not to count value several times
      }
    }
  }
  value_by_rank = values_by_rank.transform_values{|v| v.to_f / samples.size }

  samples.map{|sample|
    ranks(sample).map{|ranks| vals = ranks.map{|rank| value_by_rank[rank] }; vals.sum(0.0) / vals.length }
  }
end
