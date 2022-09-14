require 'json'

def load_dataset_correlations(heatmaps_glob)
  dataset_correlation_triples = []
  Dir.glob(heatmaps_glob).each{|dataset_correlation_heatmap_fn|
    tf = File.basename(dataset_correlation_heatmap_fn, '.json')
    data = JSON.parse(File.read(dataset_correlation_heatmap_fn))['data']
    data.each{|ds_info|
      ds_1 = ds_info['name']
      ds_info['data'].each{|corr_info|
        ds_2 = corr_info['x']
        val = corr_info['y']
        dataset_correlation_triples << [ds_1, ds_2, val]  if ds_1 < ds_2
      }
    }
  }
  dataset_correlation_triples.map{|d1, d2, v| [[d1, d2], v] }.to_h
end

heatmaps = load_dataset_correlations('heatmaps_custom/*.json');nil


metadata = File.open('metadata_release_8d.json'){|f|
  f.each_line.map{|l|
    JSON.parse(l.chomp)
  }
}; nil

# Template for Brechalov's data
UNKNOWN_SIMILARITY = nil

dataset_similarities_table = metadata.select{|d|
  d['slice_type'] == 'Val'
}.select{|d|
  ['AFS', 'CHS'].include?(d['experiment_type'])
}.group_by{|d|
  d['tf']
}.map{|tf, ds|
  ds.map{|d|
    replica = d.dig('experiment_params', 'replica')
    [ 
      tf,
      [ d['experiment_type'], d['experiment_subtype'] ].compact.join('-').upcase,
      [d['experiment_id'], replica ? "Rep-#{replica}" : nil].compact.join('.'),
    ]
  }.uniq
}.reject{|ds|
  ds.size <= 1
}.flat_map{|ds|
  ds.combination(2).map{|(tf, exp_1_type, exp_1_id), (_tf, exp_2_type, exp_2_id)|
    raise  unless tf == _tf
    d1 = "#{exp_1_type}:#{exp_1_id}"
    d2 = "#{exp_2_type}:#{exp_2_id}"
    corr = heatmaps[ [d1, d2].sort ]
    raise "No correlation for #{tf} between datasets #{d1}, #{d2}"  if !corr
    [tf, exp_1_type, exp_1_id, exp_2_type, exp_2_id, corr, UNKNOWN_SIMILARITY]
  }
}.sort; nil

File.open('peak_based_dataset_similarities.tsv', 'w'){|fw|
  fw.puts ['TF', 'exp_1_type', 'exp_1_id', 'exp_2_type', 'exp_2_id', 'motif_ranks_correlation', 'peak_concordance' ].join("\t")
  dataset_similarities_table.each{|row|
    fw.puts row.join("\t")
  }
}
