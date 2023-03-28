require 'json'
require 'fileutils'

dataset_infos = File.readlines('/home_local/vorontsovie/greco-bit-data-processing/metadata_release_8d.patch1.json').map{|l|
  JSON.parse(l)
}; nil

dataset_infos_addition = File.readlines('/home_local/vorontsovie/greco-data/release_7b.2022-02-21/metadata_release_7b.json').map{|l|
  JSON.parse(l)
}; nil


info_by_ds = dataset_infos.map{|ds|
  [ds['dataset_id'], ds]
}.tap{|r|
  raise  unless r.size == r.to_h.size
}.to_h; nil

dataset_infos_addition.reject{|ds|
  info_by_ds.has_key?(ds['dataset_id'])
}.each{|ds|
  info_by_ds[ ds['dataset_id'] ] = ds
}; nil

exp_verdicts = File.readlines('/home_local/vorontsovie/greco-bit-data-processing/source_data_meta/shared/experiment_verdicts.tsv').drop(1).map{|l|
  l.chomp.split("\t")
}.map{|num, tf, exp_type, exp_id, verdict|
  [exp_id, verdict]
}.tap{|r|
  raise  unless r.size == r.to_h.size
}.to_h; nil

bn_verdicts = [
  # *Dir.glob('/home_local/vorontsovie/greco-motifs/release_8c.7e+8c.pack_1+2+3+4+5/*'),
  *Dir.glob('/home_local/vorontsovie/greco-motifs/release_8c.pack_6/*'),
].map{|fn|
  File.basename(fn)
}.map{|bn|
  begin
    ds = bn.split('@')[2].split('+').first
    exp_id = info_by_ds[ds]['experiment_id']
    # $stderr.puts "Unknown experiment_id `#{exp_id}`"  unless exp_verdicts.has_key?(exp_id)
    [bn, exp_verdicts[exp_id]]
  rescue
    $stderr.puts "Unknown dataset `#{ds}`"
  end
}.to_h; nil


FileUtils.mkdir_p('/home_local/vorontsovie/greco-motifs/release_8c.pack_6_wo_bad/')

bn_verdicts.select{|bn, verdict|
  verdict != 'bad'
}.each{|bn, verdict|
  FileUtils.cp("/home_local/vorontsovie/greco-motifs/release_8c.pack_6/#{bn}", "/home_local/vorontsovie/greco-motifs/release_8c.pack_6_wo_bad/#{bn}")
}; nil
