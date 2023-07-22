require 'csv'
require_relative 'shared/lib/utils'

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

motifs = File.readlines("release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad+7_list.txt").map(&:chomp)
dataset_infos = CSV.readlines('metadata_release_8d.patch2.tsv', headers: true, col_sep: "\t").map(&:to_h)
dataset_infos_by_id = dataset_infos.map{|h| [h["dataset_id"], h] }.to_h

motif_infos = motifs.map{|motif|
  tf_w_dbd, exp_type_w_subtype, datasets, tool, motif_name_w_ext  = motif.split('@')
  tf, construct_type = tf_w_dbd.split('.')
  tf = gene_mapping.fetch(tf, tf)
  exp_type, exp_subtype = exp_type_w_subtype.split('.')
  datasets = datasets.split('+')
  motif_name, extension = motif_name_w_ext.split('.')
  fields = [
    "tf", "construct_type", "experiment_type", "experiment_subtype",
    "experiment_id", "replicate", "processing_type", "slice_type", "extension",
  ]
  
  dataset_info = datasets.map{|ds|
    dataset_infos_by_id[ds]
  }.map{|hsh|
    fields.map{|f| [f, hsh[f]] }.to_h
  }.uniq.take_the_only

  raise  unless (tf == dataset_info['tf']) && (construct_type == dataset_info['construct_type']) && (exp_type == dataset_info['experiment_type']) && (exp_subtype == dataset_info['experiment_subtype'])

  {
    'motif' => motif,
    'tf' => tf, 'construct_type' => construct_type, 'exp_type' => exp_type, 'exp_subtype' => exp_subtype,
    'datasets' => datasets.sort.join('+'), 'motif_name' => motif_name, 'extension' => extension,
    'experiment_id' => dataset_info['experiment_id'], 'replicate' => dataset_info['replicate'],
    'processing_type' => dataset_info['processing_type'], 'slice_type' => dataset_info['slice_type'],
    'dataset_extension' => dataset_info['extension'],
  }
}

File.open('motif_infos.tsv', 'w'){|fw|
  header = [
    'motif', 'tf', 'construct_type', 'exp_type', 'exp_subtype', 'datasets', 'motif_name', 'extension',
    'experiment_id', 'replicate', 'processing_type', 'slice_type', 'dataset_extension',
  ]
  fw.puts header.join("\t")
  motif_infos.each{|info|
    fw.puts info.values_at(*header).join("\t")
  }
}
