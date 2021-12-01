require 'json'
raise 'Specify metadata'  unless metadata_fn = ARGV[0]
# metadata_fn = 'run_benchmarks_release_7/metadata_release_7a.json'

def normalize(val)
  case val
  when NilClass
    []
  when String
    val.split(";").map(&:strip)
  when Array
    val
  else
    raise "Unknown type #{val.class} of #{val}"
  end    
end

tf_infos = File.readlines(metadata_fn).map{|l|
  info = JSON.parse(l)
  tf = info['tf']
  dbd = info.dig('experiment_meta', 'plasmid', 'insert', 'dbd_type')
  dbd_human = info.dig('experiment_meta', 'plasmid', 'insert', 'dbd_type_from_HumanTFs')
  [tf, normalize(dbd), normalize(dbd_human)]
}.each_with_object({}){|(tf, dbd, dbd_human), hsh|
  hsh[tf] ||= {}
  hsh[tf]["dbd"] ||= []
  hsh[tf]["dbd_human"] ||= []
  hsh[tf]["dbd"] += dbd
  hsh[tf]["dbd_human"] += dbd_human
}.transform_values{|info|
  info.transform_values{|vs|
    vs.uniq.sort
  }
}

tf_infos.map{|tf, info|
  dbd = (info['dbd'] + info['dbd_human']).uniq.sort.join(";")
  puts([tf, dbd].join("\t"))
}
