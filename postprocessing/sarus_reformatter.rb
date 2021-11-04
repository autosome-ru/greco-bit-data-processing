require 'json'
require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/utils'

def read_metadata(metadata_fn)
  File.readlines(metadata_fn).map{|l| JSON.parse(l.chomp) }
end

# motif name: ZNF687.DBD@AFS.IVT@bluesy-eggplant-shrimp+seedy-puce-hyrax+snappy-vermilion-sparrow+stealthy-blue-heron@autosome-ru.ChIPMunk@topk_cycle=C1+C2+C3+C4_k=5_top=10000.pcm
def dataset_ids_for_motif(motif_fullname)
  motif_fullname.split('@')[2].split('+')
end

metadata_fn = nil
filter_mode = :none
option_parser = OptionParser.new{|opts|
  opts.on('--filter-by-tf', 'Select motif/dataset pairs with matching TF'){
    filter_mode = :by_tf
  }
  opts.on('--filter-by-experiment METADATA_FILE', "Specify metadata file to select motif/dataset pairs with mathcing experiment id"){|fn|
    raise "Specify the only filtering mode"  if filter_mode != :none
    filter_mode = :by_experiment_id
    metadata_fn = fn
  }
}
option_parser.parse!(ARGV)

raise 'Specify motif name'  unless motif = ARGV[0]

motif_tf = motif.split(".")[0]

infos = $stdin.each_line.each_slice(2).map{|hdr,scores|
  tf, exp_id, flank_type = hdr.chomp[1..-1].split(":")
  logpval, pos, strand = scores.chomp.split("\t")
  [tf, exp_id, flank_type, logpval, pos, strand]
}

if filter_mode == :by_tf
  infos = infos.select{|tf, *_rest|
    motif_tf == tf
  }
end

if filter_mode == :by_experiment_id
  experiment_by_dataset_id = read_metadata(metadata_fn).index_by{|info| info['dataset_id'] }.transform_values{|info| info['experiment_id'] }
  infos = infos.select{|tf, dataset_exp_id, *_rest|
    exp_for_motif = dataset_ids_for_motif(motif).map{|ds_id| experiment_by_dataset_id[ds_id] }.uniq.take_the_only
    exp_for_motif == dataset_exp_id
  }
end

infos.each{|info|
  info = [motif, *info]
  puts info.join("\t")
}
