require 'json'

header = [
  'dataset_name', 'tf', 'experiment_subtype', 
  # 'slice_type',
  'cycle', 'experiment_id',
  #'num_peaks_in_dataset',
  'qc_estFragLen', 'qc_FRiP_CPICS', 'qc_FRiP_GEM', 'qc_FRiP_MACS2_NOMODEL', 'qc_FRiP_MACS2_PEMODE', 'qc_FRiP_SISSRS',
  'qc_NRF', 'qc_NSC', 'qc_PBC1', 'qc_PBC2', 'qc_RSC',
]

fields = [
  ['dataset_name'],
  ['tf'],
  ['experiment_subtype'],
  # ['slice_type'],
  ['experiment_params', 'cycle'],
  ['experiment_id'],
  # ['stats','num_peaks'],
  ['experiment_info','qc_estFragLen'],
  ['experiment_info','qc_FRiP_CPICS'],
  ['experiment_info','qc_FRiP_GEM'],
  ['experiment_info','qc_FRiP_MACS2_NOMODEL'],
  ['experiment_info','qc_FRiP_MACS2_PEMODE'],
  ['experiment_info','qc_FRiP_SISSRS'],
  ['experiment_info','qc_NRF'],
  ['experiment_info','qc_NSC'],
  ['experiment_info','qc_PBC1'],
  ['experiment_info','qc_PBC2'],
  ['experiment_info','qc_RSC'],
]

AFS_DATA_FOLDER = "/home_local/vorontsovie/greco-data/release_8d.2022-07-31/full/AFS.Peaks"
peak_by_ds = File.readlines("#{AFS_DATA_FOLDER}/complete_data_mapping_peaks.txt").map(&:chomp).slice_before{|l|
  l.start_with?('>')
}.flat_map{|peak_fn,*dataset_fns|
  dataset_fns.map{|dataset_fn|
    [File.basename(dataset_fn), peak_fn[1..-1]]
  }
}.to_h

num_peaks_by_peak_bn = peak_by_ds.values.uniq.map{|peak_bn|
  [peak_bn, File.open("#{AFS_DATA_FOLDER}/complete_data/#{peak_bn}"){|f| f.each_line.drop(1).count }]
}.to_h

puts [*header, 'total_peaks_filename', 'total_num_peaks'].drop(1).join("\t")
data = File.open('metadata_release_8d.json'){|f|
  f.each_line.lazy.map{|l|
    JSON.parse(l)
  }.select{|d|
    d['experiment_type'] == "AFS"
  }.select{|d|
    d['extension'] == "peaks"
  }.map{|d|
    ds = d['dataset_name']
    peak_bn = peak_by_ds[ds]
    fields.map{|field| d.dig(*field) } + [peak_bn, num_peaks_by_peak_bn[peak_bn]]
  }.to_a
}

data.select{|row|
  row[-2].nil? # empty total_peaks_filename
}.each{|row|
  $stderr.puts [row, 'missing-peaks-file'].join("\t")
}


data.group_by{|row|
  row[-2] # total_peaks_filename
}.reject{|peaks_fn, grp|
  peaks_fn.nil?
}.map{|peaks_fn, grp|
  unless grp.map{|r| r.drop(1) }.uniq.size == 1
    $stderr.puts grp.map{|r| r.drop(1) }.uniq.inspect
    raise
  end
  grp[0].drop(1) # drop dataset_id
}.each{|info|
  puts info.join("\t")
}
