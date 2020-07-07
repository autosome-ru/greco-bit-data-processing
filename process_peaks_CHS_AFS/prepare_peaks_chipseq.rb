require 'fileutils'
require 'tempfile'
require_relative 'utils'
require_relative 'peak_preparation_utils'
require_relative 'experiment_info_extension'

PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

SOURCE_FOLDER = ARGV[0] # 'source_data/chipseq'
RESULTS_FOLDER = ARGV[1] # 'results/chipseq'


FileUtils.mkdir_p("#{RESULTS_FOLDER}/confirmed_intervals")

ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_files, :peaks, :type) do
  include ExperimentInfoExtension

  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_files = row[2]
    peaks = row[3].split(';')

    raise 'Inconsistent data'  if (row[13] == 'CONTROL') ^ (row[13] == 'CONTROL')

    if row[14] == 'CONTROL'
      peak_id = nil
      type = 'control'
    else
      peak_bns = peaks.map{|fn| File.basename(fn.strip,".interval") }.reject(&:empty?).uniq
      peak_id = take_the_only( peak_bns )
      if row[14] == 'NOT_PAIRED_END'
        type = 'single_end'
      else
        type = 'paired_end'
      end
    end

    self.new(experiment_id, peak_id, tf, raw_files, peaks, type)
  end

  def peak_fn_for_peakcaller(peak_caller)
    case type
    when 'control'
      raise "No peak file for control #{peak_id}"
    when 'single_end'
      "#{SOURCE_FOLDER}/peaks-intervals-se_control/#{peak_caller}/#{peak_id}.interval"
    when 'paired_end'
      "#{SOURCE_FOLDER}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end
end

bad_experiments = File.readlines("#{SOURCE_FOLDER}/bad_experiments.txt").map(&:strip).reject(&:empty?)
experiment_infos = ExperimentInfo.each_from_file("#{SOURCE_FOLDER}/metrics_by_exp.tsv").reject{|info|
  info.type == 'control'
}.reject{|info|
  bad_experiments.include?(info.experiment_id)
}.to_a

raise 'Non-uniq peak ids'  unless experiment_infos.map(&:peak_id).uniq.size == experiment_infos.map(&:peak_id).uniq.size
experiment_by_peak_id = experiment_infos.map{|info| [info.peak_id, info] }.to_h

experiment_infos.each(&:make_confirmed_peaks!)

# experiment_infos = experiment_infos.reject{|info| info.num_confirmed_peaks < 100 }
# experiment_infos.select{|info| info.num_confirmed_peaks < 100 }.each{|info|
#   FileUtils.rm(info.confirmed_peaks_fn)
# }

tf_infos = experiment_infos.group_by(&:tf).map{|tf, infos|
  FileUtils.mkdir_p "#{RESULTS_FOLDER}/tf_peaks/#{tf}/best"
  FileUtils.mkdir_p "#{RESULTS_FOLDER}/tf_peaks/#{tf}/rest"

  sorted_peaks_infos = infos.sort_by(&:num_confirmed_peaks).reverse
  best_peak_info = sorted_peaks_infos.first
  rest_peak_infos = sorted_peaks_infos.drop(1)
  {tf: tf, best_peak: best_peak_info, rest_peaks: rest_peak_infos}
}

tf_infos.each{|tf_info| split_train_val!(tf_info) }
store_confirmed_peak_stats(tf_infos, "#{RESULTS_FOLDER}/confirmed_peaks_stats.tsv")
store_train_val_stats(tf_infos, "#{RESULTS_FOLDER}/train_val_peaks_stats.tsv", experiment_by_peak_id)
