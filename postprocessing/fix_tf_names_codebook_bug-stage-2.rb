require 'json'

module Enumerable
  def take_the_only
    raise "Should be one element in a collection"  unless self.size == 1
    self.first
  end

  def to_h_safe
    raise "non-unique keys"  if self.size != self.map(&:first).size
    self.to_h
  end
end

def replace_construct_name(fn, tf_construct_by_dataset_id, &block)
  old_tf_construct, suffix = File.basename(fn).split('@', 2)
  dataset_ids = block.call(fn)
  new_tf_construct = dataset_ids.map{|dataset_id|
    tf_construct_by_dataset_id.fetch(dataset_id)
  }.uniq.take_the_only
  File.join(File.dirname(fn), "#{new_tf_construct}@#{suffix}")
end

# def dataset_id_by_dataset_fn(dataset_fn)
#   File.basename(dataset_fn).split('@')[3].split('.')[1]
# end

def dataset_ids_by_joined_datasets_fn(joined_datasets_fn)
  # TIGD5.FL@AFS.Lys@YWO_B_AffSeq_F11_TIGD5-FL.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC.C1+C2+C3+C4@Reads.sleepy-sangria-ladybird+skanky-saffron-pig+slaphappy-harlequin-whale+hasty-coral-dollar.Val.fastq.gz
  File.basename(joined_datasets_fn).split('@')[3].split('.')[1].split('+')
end

def dataset_ids_by_motif_fn(motif_fn)
  File.basename(motif_fn).split('@')[2].split('+')
end

motif_tf_construct_by_ds_fn = Dir.glob('freeze_recalc/all_motifs/*').flat_map{|fn|
  tf_construct = File.basename(fn).split('@', 2).first
  dataset_ids_by_motif_fn(fn).map{|dataset_id|
    [dataset_id, tf_construct]
  }
}.to_h_safe

# freeze-approved is a subset of freeze, so we don't make a separate mapping
dataset_tf_construct_by_ds_fn = Dir.glob('freeze_recalc/datasets_freeze/*/*/*').flat_map{|fn|
  tf_construct = File.basename(fn).split('@', 2).first
  dataset_ids_by_joined_datasets_fn(fn).map{|dataset_id|
    [dataset_id, tf_construct]
  }
}.to_h_safe

experiments_to_skip = ['YWN_B_AffSeq_F11_TIGD5-FL', 'YWO_B_AffSeq_F11_TIGD5-FL']
datasets_to_skip = File.open('freeze_recalc_integrated/datasets_metadata.full.json').each_line.lazy.map{|l|
  JSON.parse(l)
}.select{|d| experiments_to_skip.include?(d['experiment_id']) }.map{|d|
  d['dataset_id']
}.uniq.force


Dir.glob('freeze_recalc_backups/freeze_recalc_for_benchmark/benchmarks/*.tsv').each{|fn|
  metrics_renamed = File.readlines(fn).map{|l|
    dataset_fn, motif_fn, metrics = l.chomp.split("\t")
  }.reject{|dataset_fn, motif_fn, metrics|
    datasets_to_skip.intersect?( dataset_ids_by_joined_datasets_fn(dataset_fn) )
  }.reject{|dataset_fn, motif_fn, metrics|
    datasets_to_skip.intersect?( dataset_ids_by_motif_fn(motif_fn) )
  }.map{|dataset_fn, motif_fn, metrics|
    new_dataset_fn = replace_construct_name(dataset_fn, dataset_tf_construct_by_ds_fn){|fn|
      dataset_ids_by_joined_datasets_fn(fn)
    }
    new_motif_fn = replace_construct_name(motif_fn, motif_tf_construct_by_ds_fn){|fn|
      dataset_ids_by_motif_fn(fn)
    }
    [new_dataset_fn, new_motif_fn, metrics]
  }
  new_fn = File.join('freeze_recalc_for_benchmark/benchmarks/', File.basename(fn))
  File.open(new_fn, 'w'){|fw|
    metrics_renamed.each{|row|
      fw.puts(row.join("\t"))
    }
  }
}
