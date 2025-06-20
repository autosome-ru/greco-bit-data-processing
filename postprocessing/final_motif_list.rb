require 'csv'
require_relative '../shared/lib/utils'

gene_mapping = {
  'ZNF788' => 'ZNF788P',
  'ZUFSP' => 'ZUP1',
  'TPRX' => 'TPRX1',
  'OKT4' => 'POU5F1',
  'cJUN' => 'JUN',
  'ZFAT1' => 'ZFAT',
  'C11orf95' => 'ZFTA',
  'ZNF705E' => 'ZNF705EP',
}

raise 'Specify motifs folder' unless motifs_folder = ARGV[0]
raise 'Specify metadata.tsv' unless metadata_tsv_fn = ARGV[1]

motifs = Dir.glob("#{motifs_folder}/*").map{|fn| File.basename(fn) }
dataset_infos = CSV.readlines(metadata_tsv_fn, headers: true, col_sep: "\t").map(&:to_h)
dataset_info_by_id = dataset_infos.map{|h| [h["dataset_id"], h] }.to_h

motif_infos = motifs.map{|motif|
  tf_w_dbd, exp_type_w_subtype, datasets, tool, motif_name_w_ext  = motif.split('@')
  tf, construct_type = tf_w_dbd.split('.')
  tf = gene_mapping.fetch(tf, tf)
  exp_type, exp_subtype = exp_type_w_subtype.split('.')
  exp_type = exp_type.sub('AFS', 'GHTS')
  datasets = datasets.split('+')
  motif_name, extension = motif_name_w_ext.split('.')
  fields = [
    "tf", "construct_type", "experiment_type", "experiment_subtype",
    "experiment_id", "replicate", "processing_type", "extension",
  ]
  
  dataset_info = datasets.map{|ds|
    dataset_info_by_id[ds]
  }.map{|hsh|
    fields.map{|f| [f, hsh[f]] }.to_h
  }.uniq.take_the_only

  raise  unless (tf == dataset_info['tf']) && (construct_type == dataset_info['construct_type']) && (exp_type.sub('AFS', 'GHTS') == dataset_info['experiment_type']) && (exp_subtype == dataset_info['experiment_subtype'])

  {
    'motif' => motif,
    'tf' => tf, 'construct_type' => construct_type, 'exp_type' => exp_type, 'exp_subtype' => exp_subtype,
    'datasets' => datasets.sort.join('+'), 'motif_name' => motif_name, 'extension' => extension,
    'experiment_id' => dataset_info['experiment_id'], 'replicate' => dataset_info['replicate'],
    'processing_type' => dataset_info['processing_type'],
    'dataset_extension' => dataset_info['extension'],
  }
}

header = [
  'motif', 'tf', 'construct_type', 'exp_type', 'exp_subtype', 'datasets', 'motif_name', 'extension',
  'experiment_id', 'replicate', 'processing_type', 'dataset_extension',
]
puts header.join("\t")
motif_infos.each{|info|
  puts info.values_at(*header).join("\t")
}
