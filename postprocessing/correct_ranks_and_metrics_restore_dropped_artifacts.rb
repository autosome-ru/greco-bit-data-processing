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

raise 'Specify file folder' unless folder = ARGV[0] # 'benchmarks/release_8d/'
raise 'Specify basename' unless name = ARGV[1] # '7e+8c_pack_1-7'

['ranks', 'metrics'].each do |data_type|
  data_disallow_artifacts = JSON.parse(File.read("#{folder}/#{data_type}@#{name}@disallow-artifacts.json"));nil
  data_disallow_artifacts_ETS_only = JSON.parse(File.read("#{folder}/#{data_type}@#{name}@disallow-artifacts_ETS-only.json"));nil

  data_disallow_artifacts_ETS_only.each{|tf, info|
    data_disallow_artifacts[tf] = info
  }

  File.write("#{folder}/#{data_type}@#{name}@disallow-artifacts_ETS-refined.json", data_disallow_artifacts.to_json)
end
