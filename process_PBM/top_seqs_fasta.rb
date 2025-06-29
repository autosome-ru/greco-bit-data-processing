require 'optparse'
require 'fileutils'

# standard normal distribution quantiles
quantiles = {0.05 => 1.64, 0.01 => 2.34, 0.005 => 2.57, 0.001 => 3.08}
quantiles_order = quantiles.keys.sort.reverse

threshold = -Float::INFINITY
max_head_size = false
src_folder = nil
dst_folder = nil
option_parser = OptionParser.new{|opts|
  opts.on('--quantile VALUE'){|q|
    q = Float(q)
    raise "Threshold for quantile #{q} is unknown"  unless quantiles.has_key?(q)
    threshold = quantiles[q]
  }
  opts.on('--max-head-size SIZE'){|size|
    max_head_size = Integer(size)
  }
  opts.on('--source FOLDER'){|folder|
    src_folder = folder
  }
  opts.on('--destination FOLDER'){|folder|
    dst_folder = folder
  }
}
option_parser.parse!(ARGV)

raise "Specify source folder" unless src_folder
raise "Specify destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

quantiles_header = quantiles_order.map{|quantile, z_score_thr|
  z_score_thr = quantiles[quantile]
  "q=#{quantile}(z>#{z_score_thr})"
}
header = ['TF', *quantiles_header, 'dataset']

Dir.glob(File.join(src_folder, '*.tsv')).each{|fn|
  basename = File.basename(fn, ".tsv")
  # tf = basename.split("_").last
  File.open(File.join(dst_folder, "#{basename}.fa"), 'w') {|fw|
    top_seqs = File.readlines(fn).map{|l|
      probe_id, seq, zscore = l.chomp.split("\t")
      {seq: seq, zscore: Float(zscore)}
    }.select{|info|
      info[:zscore] >= threshold
    }.sort_by{|info|
      -info[:zscore]
    }

    top_seqs = top_seqs.first(max_head_size) if max_head_size
    top_seqs.each{|info|
        fw.puts ">#{info[:zscore]}"
        fw.puts info[:seq]
    }
  }
}
