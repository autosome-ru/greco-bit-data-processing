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


FileUtils.mkdir_p("#{RESULTS_FOLDER}/complete_data")

ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_files, :peaks, :type, :plate_id) do
  include ExperimentInfoExtension

  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_files = row[2]
    peaks = row[3].split(';')
    plate_ids = raw_files.split(';').map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn| bn.sub(/_R[12](_001)?$/,'') }.uniq
    if plate_ids.size == 1
      plate_id = plate_ids[0]
    elsif plate_ids.size == 0
      raise
    else
      parts = plate_ids[0].split('_').zip( *plate_ids.drop(1).map{|s| s.split('_') } ).map{|parts| parts.uniq }
      prefix = parts.take_while{|part| part.size == 1 }.flatten.join('_') + '_'
      plate_id = prefix + plate_ids.map{|s| s[prefix.size..-1] }.join('+')
      # plate_id_parts = plate_ids.tap{|x| p x }.map{|s| s.match(/^(.+)_(L\d+)$/) }
      # plate_id = take_the_only(plate_id_parts.map(&:first).uniq) + '_' + plate_id_parts.map(&:last).uniq.join('+')
    end

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

    self.new(experiment_id, peak_id, tf, raw_files, peaks, type, plate_id)
  end

  # GLI4.Plate_2_G12_S191.PEAKS991005
  def basename
    "#{tf}.#{plate_id}.#{peak_id}"
  end

  def self.peak_id_from_basename(bn)
    bn.split('.')[2]
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

experiment_infos.each{|peak_info|
    FileUtils.rm(peak_info.confirmed_peaks_fn)  if File.exist?(peak_info.confirmed_peaks_fn) && num_rows(peak_info.confirmed_peaks_fn, has_header: true) < 100
}
experiment_infos = experiment_infos.select{|peak_info|
  File.exist?(peak_info.confirmed_peaks_fn)
}.reject{|peak_info|
  num_rows(peak_info.confirmed_peaks_fn, has_header: true) < 100
}

tf_infos = experiment_infos.group_by(&:tf).map{|tf, infos|
  sorted_peaks_infos = infos.sort_by(&:num_confirmed_peaks).reverse
  best_peak_info = sorted_peaks_infos.first
  rest_peak_infos = sorted_peaks_infos.drop(1)
  {tf: tf, best_peak: best_peak_info, rest_peaks: rest_peak_infos}
}

tf_infos.each{|tf_info| split_train_val!(tf_info) }
tf_infos.each{|tf_info| cleanup_bad_datasets!(tf_info, min_peaks: 50) }

store_confirmed_peak_stats(tf_infos, "#{RESULTS_FOLDER}/complete_data_stats.tsv")
store_train_val_stats(tf_infos, "#{RESULTS_FOLDER}/train_val_peaks_stats.tsv", experiment_by_peak_id)
