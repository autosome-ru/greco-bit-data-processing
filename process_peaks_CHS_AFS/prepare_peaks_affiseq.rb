require 'fileutils'
require 'tempfile'
require 'optparse'
require_relative 'utils'
require_relative 'peak_preparation_utils'
require_relative 'experiment_info_extension'
require_relative 'experiment_info_afs'

PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

experiment_type = nil
option_parser = OptionParser.new{|opts|
  opts.on('--experiment-type TYPE'){|value| experiment_type = value }
}
option_parser.parse!(ARGV)

SOURCE_FOLDER = ARGV[0] # 'source_data/affiseq'
RESULTS_FOLDER = ARGV[1] # 'results/affiseq_Lysate'
metrics_fn = ARGV[2] # "#{__dir__}/../source_data_meta/AFS/metrics_by_exp.tsv"

experiment_infos = ExperimentInfoAFS.each_from_file(metrics_fn).reject{|info| info.type == 'control' }.to_a
experiment_infos.each{|info|
  info.confirmed_peaks_folder = "#{RESULTS_FOLDER}/complete_data"
}

FileUtils.mkdir_p("#{RESULTS_FOLDER}/complete_data")

experiment_infos.select!{|info| info.type == experiment_type }  if experiment_type
tfs_at_start = experiment_infos.map(&:tf).uniq

raise 'Non-uniq peak ids'  unless experiment_infos.map(&:peak_id).uniq.size == experiment_infos.map(&:peak_id).uniq.size
experiment_by_peak_id = experiment_infos.map{|info| [info.peak_id, info] }.to_h

failed_infos = []
experiment_infos.each{|info|
  begin
    info.make_confirmed_peaks!(
      source_folder: SOURCE_FOLDER,
      main_peak_callers: MAIN_PEAK_CALLERS,
      supplementary_peak_callers: SUPPLEMENTARY_PEAK_CALLERS,
    )
  rescue
    failed_infos << info
  end
}

unless failed_infos.empty?
  puts "Failed to make confirmed peaks. Probably there were no file with peak calls for one of main peak-callers. Failed datasets:"
  failed_infos.each{|info|
    relevant_info = info.to_h.select{|k,v| [:experiment_id, :peak_id, :tf].include?(k) }
    puts relevant_info
  }
end

# experiment_infos.each{|peak_info|
#     FileUtils.rm(peak_info.confirmed_peaks_fn)  if File.exist?(peak_info.confirmed_peaks_fn) && num_rows(peak_info.confirmed_peaks_fn, has_header: true) < 100
# }
# experiment_infos = experiment_infos.select{|peak_info|
#   File.exist?(peak_info.confirmed_peaks_fn)
# }
# .reject{|peak_info|
#   num_rows(peak_info.confirmed_peaks_fn, has_header: true) < 100
# }

tf_infos = experiment_infos.group_by{|info| info.tf }.map{|tf, tf_group|
  {tf: tf, best_peak: tf_group.max_by(&:num_confirmed_peaks), rest_peaks: []}
}

tf_infos.each{|tf_info| split_train_val!(tf_info, RESULTS_FOLDER) }
tf_infos.each{|tf_info| cleanup_bad_datasets!(tf_info, RESULTS_FOLDER, min_peaks: 50) }
store_confirmed_peak_stats(
  tf_infos,
  "#{RESULTS_FOLDER}/complete_data_stats.tsv",
  source_folder: SOURCE_FOLDER,
  peak_callers: PEAK_CALLERS,
)
store_train_val_stats(
  tf_infos, "#{RESULTS_FOLDER}/train_val_peaks_stats.tsv", experiment_by_peak_id, RESULTS_FOLDER,
  get_peak_id: ->(fn){ ExperimentInfoAFS.peak_id_from_basename(File.basename(fn, '.interval')) }
)

tfs_at_finish = Dir.glob("#{RESULTS_FOLDER}/Train_intervals/*").map{|fn| File.basename(fn).split('.').first }.uniq
File.write("#{RESULTS_FOLDER}/skipped_tfs.txt", (tfs_at_start - tfs_at_finish).sort.join("\n"))
File.write("#{RESULTS_FOLDER}/tfs.txt", tfs_at_finish.sort.join("\n"))
