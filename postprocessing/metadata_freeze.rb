require 'csv'
require 'json'
require 'set'

def exp_qual_name(exp, rep)
  rep ? "#{exp}.Rep-#{rep}" : exp
end

raise 'Specify freeze file'  unless freeze_fn = ARGV[0]
raise 'Specify metadata file'  unless metadata_fn = ARGV[1]

experiments_in_freeze = File.readlines(freeze_fn).drop(1).map{|l| l.chomp.split("\t").last }.to_set

dataset_info_by_id = File.open(metadata_fn).each_line.map{|l|
  data = JSON.parse(l.chomp)
  [data['dataset_id'], {'experiment_id' => data['experiment_id'], 'replicate' => data.dig('experiment_params','replica')}]
}.to_h

File.open(metadata_fn){|f|
  f.each_line.select{|l|
    dataset_id = JSON.parse(l.chomp)['dataset_id']
    dataset_info = dataset_info_by_id[dataset_id]
    exp_fullname = exp_qual_name(dataset_info['experiment_id'], dataset_info['replicate'])
    experiments_in_freeze.include?(exp_fullname)
  }.each{|l|
    puts(l)
  }
}
