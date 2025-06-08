require 'json'

module Enumerable
  def index_by(&block)
    self.each_with_object({}){|el, result|
      key = block.call(el)
      raise "Non-unique key can't be used as index (duplicates for key `#{key}`)"  if result.has_key?(key)
      result[key] = el
    }
  end
end

def replace_construct_name(fn, suffix_tf_construct_mapping)
  old_tf_construct, suffix = File.basename(fn).split('@', 2)
  new_tf_construct = suffix_tf_construct_mapping.fetch(suffix, suffix)
  File.join(File.dirname(fn), "#{new_tf_construct}@#{suffix}")
end

def dataset_id_by_dataset_fn(dataset_fn)
  File.basename(dataset_fn).split('@')[3].split('.')[1]
end

def dataset_ids_by_motif_fn(motif_fn)
  File.basename(motif_fn).split('@')[2].split('+')
end

motif_tf_construct_by_suffix = Dir.glob('freeze_recalc/all_motifs/*').map{|fn|
  File.basename(fn).split('@', 2)
}.index_by{|tf_construct, suffix| suffix }.transform_values(&:first)

# freeze-approved is a subset of freeze, so we don't make a separate mapping
dataset_tf_construct_by_suffix = Dir.glob('freeze_recalc/datasets_freeze/*/*/*').map{|fn|
  File.basename(fn).split('@', 2)
}.index_by{|tf_construct, suffix| suffix }.transform_values(&:first)


experiments_to_skip = ['YWN_B_AffSeq_F11_TIGD5-FL', 'YWO_B_AffSeq_F11_TIGD5-FL']
datasets_to_skip = File.open('freeze_recalc_integrated/datasets_metadata.full.json').each_line.lazy.map{|l|
  JSON.parse(l)
}.select{|d| experiments_to_skip.include?(d['experiment_id']) }.map{|d|
  d['dataset_id']
}.force


Dir.glob('freeze_recalc_backups/freeze_recalc_for_benchmark/benchmarks/*.tsv').each{|fn|
  metrics_renamed = File.readlines(fn).map{|l|
    dataset_fn, motif_fn, metrics = l.chomp.split("\t")
    new_dataset_fn = replace_construct_name(dataset_fn, dataset_tf_construct_by_suffix)
    new_motif_fn = replace_construct_name(motif_fn, motif_tf_construct_by_suffix)
    [new_dataset_fn, new_motif_fn, metrics]
  }.reject{|dataset_fn, motif_fn, metrics|
    datasets_to_skip.include?( dataset_id_by_dataset_fn(dataset_fn) )
  }.reject{|dataset_fn, motif_fn, metrics|
    datasets_to_skip.intersect?( dataset_ids_by_motif_fn(motif_fn) )
  }
  new_fn = File.join('freeze_recalc_for_benchmark/benchmarks/', File.basename(fn))
  File.open(new_fn, 'w'){|fw|
    metrics_renamed.each{|row|
      fw.puts(row.join("\t"))
    }
  }
}
