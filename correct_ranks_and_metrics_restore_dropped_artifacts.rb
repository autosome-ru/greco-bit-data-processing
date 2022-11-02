require 'json'

def deep_keys(obj, root: [], &block)
  return enum_for(:deep_keys, obj, root: root)  unless block_given?
  if obj.is_a?(Hash)
    obj.each{|k,v|
      deep_keys(v, root: [*root, k], &block)
    }
  elsif obj.is_a?(Array)
    obj.each_with_index{|v, idx|
      deep_keys(v, root: [*root, idx], &block)
    }
  else
    yield root
  end
end

['ranks', 'metrics'].each do |data_type|
  data_allow_artifacts    = JSON.parse(File.read("benchmarks/release_8d/#{data_type}_7e+8c_pack_1-5_allow-artifacts.json"));nil
  data_disallow_artifacts = JSON.parse(File.read("benchmarks/release_8d/#{data_type}_7e+8c_pack_1-5_disallow-artifacts.json"));nil

  deep_keys(data_allow_artifacts, root: []).each{|ks|
    if ks[-1] != 'metric_name'
      rank = data_disallow_artifacts.dig(*ks) rescue nil
      data_allow_artifacts.dig( *ks[0...-1] )[ ks[-1] ] = rank
    end
  }; nil

  File.write("benchmarks/release_8d/#{data_type}_7e+8c_pack_1-5_disallow-artifacts_include-dropped-motifs.json", data_allow_artifacts.to_json)
end
