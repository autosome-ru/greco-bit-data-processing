require 'json'

def metadata_concat
  used_ids = File.open('metadata_release_8d.patch1.json').each_line.map{|l| JSON.parse(l.chomp)['dataset_id'] }
  missing = File.open('metadata_release_7b.json').each_line.select{|l|
    ds_id = JSON.parse(l.chomp)['dataset_id']
    !used_ids.include?(ds_id)
  }
  return enum_for(:metadata_concat)  unless block_given?
  File.open('metadata_release_8d.patch1.json').each_line{|l|
    yield l
  }
  missing.each{|l|
    yield l
  }
end

metadata_concat.reject{|l|
  info = JSON.parse(l)
  (info['experiment_type'] == 'PBM') && (info['processing_type'] == 'SDQN') && (info['slice_type'] == 'Val')
}.each{|l|
  puts l
}
