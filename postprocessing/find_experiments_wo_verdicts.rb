require 'json'
require 'set'

metadata = File.readlines('/home_local/vorontsovie/greco-data/release_8d.2022-07-31/metadata_release_8d.patch1.json').map{|l| JSON.parse(l) }
exps = metadata.map{|d| rep = d.dig('experiment_params', 'replica'); [d['experiment_id'], (rep && "Rep-#{rep}") ].compact.join('.') }.uniq

verdicts = File.readlines('source_data_meta/shared/experiment_verdicts.tsv').drop(1).map{|l| l.chomp.split("\t") }
exps_w_verdicts = verdicts.map{|d| d[3] }.uniq.to_set
# exps_wo_verdicts = (exps - exps_w_verdicts).to_set

ranks = JSON.load(File.read('benchmarks/release_8d/ranks_7e+8c_pack_1-5_disallow-artifacts_include-dropped-motifs.json'))
exps_w_ranks = ranks.each_value.select{|v| v.is_a?(Hash) }.map{|tf_ranks|
  tf_ranks.each_value.select{|v| v.is_a?(Hash) }.map{|motif_ranks|
    motif_ranks.each_value.select{|v| v.is_a?(Hash) }.map{|exp_type_ranks|
      exp_type_ranks.keys
    }
  }
}.flatten.uniq.reject{|v| v == 'combined' }.to_set

# exps_wo_ranks = (exps - exps_w_ranks).to_set

dataset_fns = Dir.glob('/home_local/vorontsovie/greco-data/release_8d.2022-07-31/full/**/*').reject{|fn|
  fn.match?(/complete_data/)
}.select{|fn| File.file?(fn) }

exps_w_train_files = dataset_fns.select{|fn| fn.match?(/\.Train\./) }.map{|fn| File.basename(fn).split('@')[2].split('.')[0] }.uniq.to_set
exps_w_val_files = dataset_fns.select{|fn| fn.match?(/\.Val\./) }.map{|fn| File.basename(fn).split('@')[2].split('.')[0] }.uniq.to_set

File.open('experiment_status.tsv', 'w') do |fw|
  header = ['experiment', 'has_verdict', 'has_metrics', 'has_train_files', 'has_val_files']
  fw.puts header.join("\t")
  exps.sort.each{|exp|
    fw.puts([
      exp, 
      exps_w_verdicts.include?(exp) ? 'yes' : 'no',
      exps_w_ranks.include?(exp) ? 'yes' : 'no',
      exps_w_train_files.include?(exp) ? 'yes' : 'no',
      exps_w_val_files.include?(exp) ? 'yes' : 'no',
    ].join("\t"))
  }
end
