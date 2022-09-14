require 'json'

def stats(vals)
  {count: vals.size, mean: vals.sum(0.0) / vals.size }  #, values: vals}
end

data = JSON.parse(File.read('heatmaps/CTCF.json'))['data']
triples = data.flat_map{|ds_info|
  ds_1 = ds_info['name']
  ds_info['data'].map{|corr_info|
    ds_2 = corr_info['x']
    val = corr_info['y']
    [ds_1, ds_2, val]
  }
}.select{|ds_1, ds_2, val|
  ds_1 < ds_2
}.map{|ds_1, ds_2, vals|
  [
    [ds_1.split(':').first, ds_1],
    [ds_2.split(':').first, ds_2],
    vals,
  ]
}

data_types = triples.flat_map{|(dt_1, ds_1), (dt_2, ds_2), val|
  [dt_1, dt_2]
}.uniq

data_types.repeated_combination(2).map{|data_type_1_2|
  matching_triples = triples.select{|(dt_1, ds_1), (dt_2, ds_2), val|
    [dt_1, dt_2].sort == data_type_1_2.sort
  }
  vals = matching_triples.map(&:last)
  [*data_type_1_2.sort, stats(vals)]
}
