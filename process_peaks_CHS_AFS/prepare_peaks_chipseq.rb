require 'fileutils'
require 'tempfile'
require 'optparse'
require_relative '../shared/lib/index_by'
require_relative 'utils'
require_relative 'peak_preparation_utils'
require_relative 'experiment_info_extension'
require_relative 'experiment_info_chs'

PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

metrics_fns = []
option_parser = OptionParser.new{|opts|
  opts.on('--qc-file FILE', 'Specify file with QC metrics. This option can be specified several times') {|fn|
    raise "QC file `#{fn}` not exists"  unless File.exists?(fn)
    metrics_fns << fn # "#{__dir__}/../source_data_meta/CHS/metrics_by_exp.tsv"
  }
}
option_parser.parse!(ARGV)

SOURCE_FOLDER = ARGV[0] # 'source_data/chipseq'
RESULTS_FOLDER = ARGV[1] # 'results/chipseq'

FileUtils.mkdir_p("#{RESULTS_FOLDER}/complete_data")

experiment_infos = metrics_fns.flat_map{|fn|
  ExperimentInfoCHS.each_from_file(fn).to_a
}
experiment_infos = experiment_infos.reject{|info| info.type == 'control' }.to_a
experiment_infos.each{|info|
  info.confirmed_peaks_folder = "#{RESULTS_FOLDER}/complete_data"
}

tfs_at_start = experiment_infos.map(&:tf).uniq

experiment_by_peak_id = experiment_infos.index_by(&:peak_id)

failed_infos = []
experiment_infos.each do |info|
  info.make_confirmed_peaks!(
    source_folder: SOURCE_FOLDER,
    main_peak_callers: MAIN_PEAK_CALLERS,
    supplementary_peak_callers: SUPPLEMENTARY_PEAK_CALLERS,
  )
rescue
  failed_infos << info
end

unless failed_infos.empty?
  $stderr.puts "Failed to make confirmed peaks. Probably there were no file with peak calls for one of main peak-callers. Failed datasets:"
  failed_infos.each{|info|
    relevant_info = info.to_h.select{|k,v| [:experiment_id, :peak_id, :tf].include?(k) }
    $stderr.puts relevant_info
  }
end

experiment_infos.each{|info|
  $stderr.puts "Confirmed peaks (`#{info.confirmed_peaks_fn}`) not exist for #{info.experiment_id}"  if !File.exist?(info.confirmed_peaks_fn)
}

experiment_infos = experiment_infos.select{|info|
  File.exist?(info.confirmed_peaks_fn)
}

# experiment_infos.each{|peak_info|
#     FileUtils.rm(peak_info.confirmed_peaks_fn)  if File.exist?(peak_info.confirmed_peaks_fn) && num_rows(peak_info.confirmed_peaks_fn, has_header: true) < 100
# }
# experiment_infos = experiment_infos.select{|peak_info|
#   File.exist?(peak_info.confirmed_peaks_fn)
# }
#.reject{|peak_info|
#  num_rows(peak_info.confirmed_peaks_fn, has_header: true) < 100
# }

tf_infos = experiment_infos.group_by(&:tf).map{|tf, infos|
  sorted_peaks_infos = infos.sort_by(&:num_confirmed_peaks).reverse
  best_peak_info = sorted_peaks_infos.first
  rest_peak_infos = sorted_peaks_infos.drop(1)
  {tf: tf, best_peak: best_peak_info, rest_peaks: rest_peak_infos}
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
  get_peak_id: ->(fn){ ExperimentInfoCHS.peak_id_from_basename(File.basename(fn, '.interval')) }
)

tfs_at_finish = Dir.glob("#{RESULTS_FOLDER}/Train_intervals/*").map{|fn| File.basename(fn).split('.').first }.uniq
File.write("#{RESULTS_FOLDER}/skipped_tfs.txt", (tfs_at_start - tfs_at_finish).sort.join("\n"))
File.write("#{RESULTS_FOLDER}/tfs.txt", tfs_at_finish.sort.join("\n"))
