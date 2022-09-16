require 'json'

def deep_keys(hsh, root: [], &block)
  return enum_for(:deep_keys, hsh, root: root)  unless block_given?
  if hsh.is_a?(Hash)
  hsh.each{|k,v|
    deep_keys(v, root: [*root, k], &block)
  }
  else
    yield root
  end
end

['ranks', 'metrics'].each do |data_type|
  data_allow_artifacts = JSON.parse(File.read("benchmarks/release_8d/#{data_type}_7e+8c_pack_1+2+3+4_crosspbm_allow-artifact_no-afs-reads.json"));nil
  data_disallow_artifacts = JSON.parse(File.read("benchmarks/release_8d/#{data_type}_7e+8c_pack_1+2+3+4_crosspbm_artifact_no-afs-reads.json"));nil

  deep_keys(data_allow_artifacts, root: []).each{|ks|
    rank = data_disallow_artifacts.dig(*ks) rescue nil
    data_allow_artifacts.dig( *ks[0...-1] )[ ks[-1] ] = rank
  }; nil

  File.write("benchmarks/release_8d/#{data_type}_7e+8c_pack_1+2+3+4_crosspbm_allow-artifact_no-afs-reads_include-dropped-motifs.json", data_allow_artifacts.to_json)
end
