require 'fileutils'
require 'tempfile'
require 'optparse'
require_relative 'utils'
require_relative 'peak_preparation_utils'
require_relative 'experiment_info_extension'

PEAK_CALLERS = ['macs2-pemode', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

experiment_type = nil
option_parser = OptionParser.new{|opts|
  opts.on('--experiment-type TYPE'){|value| experiment_type = value }
}
option_parser.parse!(ARGV)

SOURCE_FOLDER = ARGV[0] # 'source_data/affiseq'
RESULTS_FOLDER = ARGV[1] # 'results/affiseq_Lysate'

ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_files, :type, :cycle_number) do
  include ExperimentInfoExtension
  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_files = row[2]
    peak_id = row[3]
    cycle_number = take_the_only( raw_files.split(';').map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn| bn[/Cycle\d+/] }.uniq )

    if tf == 'CONTROL'
      type = 'control'
    else
      raw_files_list = raw_files.split(';')
      if raw_files_list.first.match?(/AffSeq_IVT/)
        type = 'IVT'
      elsif raw_files_list.first.match?(/AffSeq_Lysate/)
        type = 'Lysate'
      end
    end

    self.new(experiment_id, peak_id, tf, raw_files, type, cycle_number)
  end

  # GLI4.IVT.Cycle3.PEAKS991005
  def basename
    "#{tf}.#{type}.#{cycle_number}.#{peak_id}.affiseq"
  end

  def self.peak_id_from_basename(bn)
    bn.split('.')[3]
  end

  def peak_fn_for_peakcaller(peak_caller)
    case type
    when 'control'
      raise "No peak file for control #{peak_id}"
    when 'IVT', 'Lysate'
      "#{SOURCE_FOLDER}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end
end

experiment_infos = ExperimentInfo.each_from_file("#{__dir__}/../source_data_meta/AFS/metrics_by_exp.tsv").reject{|info| info.type == 'control' }.to_a
FileUtils.mkdir_p("#{RESULTS_FOLDER}/complete_data")

experiment_infos.select!{|info| info.type == experiment_type }  if experiment_type
tfs_at_start = experiment_infos.map(&:tf).uniq

raise 'Non-uniq peak ids'  unless experiment_infos.map(&:peak_id).uniq.size == experiment_infos.map(&:peak_id).uniq.size
experiment_by_peak_id = experiment_infos.map{|info| [info.peak_id, info] }.to_h

experiment_infos.each(&:make_confirmed_peaks!)

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

tf_infos.each{|tf_info| split_train_val!(tf_info) }
tf_infos.each{|tf_info| cleanup_bad_datasets!(tf_info, min_peaks: 50) }
store_confirmed_peak_stats(tf_infos, "#{RESULTS_FOLDER}/complete_data_stats.tsv")
store_train_val_stats(tf_infos, "#{RESULTS_FOLDER}/train_val_peaks_stats.tsv", experiment_by_peak_id)

tfs_at_finish = Dir.glob("#{RESULTS_FOLDER}/Train_intervals/*").map{|fn| File.basename(fn).split('.').first }.uniq
File.write("#{RESULTS_FOLDER}/skipped_tfs.txt", (tfs_at_start - tfs_at_finish).sort.join("\n"))
$stderr.puts("Affiseq TFs:\n" + tfs_at_finish.sort.join("\n"))
