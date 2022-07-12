require 'json'
require 'csv'
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

domain_mapping = {'ETS' => 'Ets', 'Homeobox' => 'Homeodomain', 'HMG/Sox' => 'Sox'}

cisbp_dbd_info = CSV.foreach('source_data_meta/shared/cisbp_TF_Information_all_motifs_plus.txt', col_sep: "\t", headers: true).each_with_object({}){|row, hsh|
  tf, family, dbds, dbd_count = row.values_at('TF_Name', 'Family_Name', 'DBDs', 'DBD_Count')
  hsh[tf] = {family: family, dbds: dbds, dbd_count: dbd_count && Integer(dbd_count)}
}

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
}.map{|tf, info|
  fams = (info['dbd'] + info['dbd_human']).uniq.sort
  if fams.empty?
    fams = (cisbp_dbd_info.dig(tf, :family) || '').split(',').reject{|v| v == 'Unknown' }
  end
  
  fams = fams.map{|fam| domain_mapping.fetch(fam, fam) }.uniq
  fams.delete('HMG')  if fams.include?('Sox') # Sox family is inside HMG

  [tf, fams]
}.to_h

puts ['tf', 'domain'].join("\t")
tf_infos.sort_by{|tf, dbds| [dbds.size, tf] }.each{|tf, dbds|
  puts([tf, dbds.empty? ? 'unknown' : dbds.sort.join(";")].join("\t"))
}
