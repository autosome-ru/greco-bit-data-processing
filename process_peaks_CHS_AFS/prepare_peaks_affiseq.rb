require 'fileutils'
require 'tempfile'
require_relative 'utils'
require_relative 'experiment_info_extension'

PEAK_CALLERS = ['macs2-pemode', 'cpics', 'gem', 'gem-affiseq', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

SOURCE_FOLDER = ARGV[0] # 'source_data/affiseq'
RESULTS_FOLDER = ARGV[1] # 'results/affiseq'


FileUtils.mkdir_p("#{RESULTS_FOLDER}/confirmed_intervals")

ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_fastq, :type) do
  include ExperimentInfoExtension
  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_fastq = row[2].split(';').map{|fn| File.basename(fn, '.fastq.gz') }
    peak_id = row[3]

    if tf == 'CONTROL'
      type = 'control'
    else
      if raw_fastq.first.match?(/AffSeq_IVT/)
        type = 'IVT'
      elsif raw_fastq.first.match?(/AffSeq_Lysate/)
        type = 'Lysate'
      end
    end

    self.new(experiment_id, peak_id, tf, raw_fastq, type)
  end

  def peak_fn_for_peakcaller(peak_caller)
    case type
    when 'control'
      raise "No peak file for control #{peak_id}"
    when 'experiment'
      "#{SOURCE_FOLDER}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end
end

experiment_infos = ExperimentInfo.each_from_file("#{SOURCE_FOLDER}/metrics_by_exp.tsv").reject{|info| info.type == 'control' }.to_a

experiment_infos.each(&:make_confirmed_peaks!)

tf_infos = experiment_infos.group_by(&:tf).map{|tf, tf_group|
  best_cycle_infos = tf_group.group_by(&:type).map{|type, peak_infos| peak_infos.max_by(&:num_confirmed_peaks) }

  best_replica = best_cycle_infos.max_by(&:num_confirmed_peaks)
  rest_replicas = best_cycle_infos - [best_replica]

  FileUtils.mkdir_p "#{RESULTS_FOLDER}/tf_peaks/#{tf}/best"
  FileUtils.mkdir_p "#{RESULTS_FOLDER}/tf_peaks/#{tf}/rest"
  {tf: tf, best_peak: best_replica, rest_peaks: rest_replicas}
}

tf_infos.each{|tf_info|
  peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak].peak_id}.interval"
  FileUtils.cp(tf_info[:best_peak].confirmed_peaks_fn, peak_fn)
  tf_info[:rest_peaks].each{|peak_info|
    peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info.peak_id}.interval"
    FileUtils.cp(peak_info.confirmed_peaks_fn, peak_fn)
  }

  # train & basic validation
  peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak].peak_id}.interval"
  train_fn = "#{RESULTS_FOLDER}/train/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.train.interval"
  validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.basic_validation.interval"
  system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"

  # advanced validation
  if tf_info[:best_peak].num_confirmed_peaks >= 200
    rest_peaks_file = Tempfile.new("rest_peaks.interval")
    header = File.readlines("#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak].peak_id}.interval").first
    rest_peaks_file.puts(header)
    tf_info[:rest_peaks].flat_map{|peak_info|
      peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info.peak_id}.interval"
      File.readlines(peak_fn).drop(1).each{|row|
        rest_peaks_file.puts(row)
      }
    }
    rest_peaks_file.close

    peak_fn = rest_peaks_file.path
    train_fn = '/dev/null'
    validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation.interval"
    system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"
    rest_peaks_file.unlink
  end
}

File.open("#{RESULTS_FOLDER}/confirmed_peaks_stats.tsv", 'w') {|fw|
  header = ['peak_id', 'tf', 'best_or_rest', 'num_confirmed_peaks', *PEAK_CALLERS.map{|peak_caller| "num_peaks:#{peak_caller}" }]
  fw.puts(header.join("\t"))
  tf_infos.each{|tf_info|
    peak_info = tf_info[:best_peak]
    row = [peak_info.peak_id, tf_info[:tf], 'best', peak_info.num_confirmed_peaks, *PEAK_CALLERS.map{|peak_caller| peak_info.num_peaks_for_peakcaller(peak_caller) } ]
    fw.puts(row.join("\t"))

    tf_info[:rest_peaks].each{|peak_info|
      row = [peak_info.peak_id, tf_info[:tf], 'rest', peak_info.num_confirmed_peaks, *PEAK_CALLERS.map{|peak_caller| peak_info.num_peaks_for_peakcaller(peak_caller) } ]
      fw.puts(row.join("\t"))
    }
  }
}

File.open("#{RESULTS_FOLDER}/train_val_peaks_stats.tsv", 'w') {|fw|
  header = ['peak_id', 'tf', 'type', 'num_peaks', 'filename']
  fw.puts(header.join("\t"))
  tf_infos.each{|tf_info|
    peak_info = tf_info[:best_peak]
    train_fn = "#{RESULTS_FOLDER}/train/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.train.interval"
    basic_validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.basic_validation.interval"
    advanced_validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation.interval"

    row = [peak_info.peak_id, tf_info[:tf], 'train', num_rows(train_fn, has_header: true), train_fn]
    fw.puts(row.join("\t"))

    row = [peak_info.peak_id, tf_info[:tf], 'basic_validation', num_rows(basic_validation_fn, has_header: true), basic_validation_fn]
    fw.puts(row.join("\t"))

    if File.exist?(advanced_validation_fn)
      row = [peak_info.peak_id, tf_info[:tf], 'advanced_validation', num_rows(advanced_validation_fn, has_header: true), advanced_validation_fn]
      fw.puts(row.join("\t"))
    end
  }
}
