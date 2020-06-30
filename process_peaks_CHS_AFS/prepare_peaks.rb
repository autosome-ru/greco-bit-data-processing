require 'fileutils'
require 'tempfile'
require_relative 'utils'
require_relative 'experiment_info_extension'

PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

SOURCE_FOLDER = ARGV[0] # 'source_data/chipseq'
RESULTS_FOLDER = ARGV[1] # 'results/chipseq'


FileUtils.mkdir_p("#{RESULTS_FOLDER}/confirmed_intervals")

ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_fastq, :peaks, :peak_count_macs2_nomodel, :peak_count_macs2_pemode, :type) do
  include ExperimentInfoExtension

  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_fastq = row[2].split(';')
    peaks = row[3].split(';')

    case row[13]
    when 'CONTROL'
      raise  unless row[14] == 'CONTROL'
      type = 'control'
      peak_count_macs2_nomodel = nil
    else
      peak_count_macs2_nomodel = Integer(row[13])
    end

    case row[14]
    when 'CONTROL'
      raise  unless row[13] == 'CONTROL'
      type = 'control'
      peak_count_macs2_pemode = nil
    when 'NOT_PAIRED_END'
      peak_count_macs2_pemode = nil
      type = 'single_end'
    else
      peak_count_macs2_pemode = Integer(row[14])
      type = 'paired_end'
    end

    if type == 'control'
      peak_id = nil
    else
      peak_id = take_the_only( peaks.map{|fn| File.basename(fn.strip,".interval") }.uniq.reject(&:empty?) )
    end

    self.new(experiment_id, peak_id, tf, raw_fastq, peaks, peak_count_macs2_nomodel, peak_count_macs2_pemode, type)
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

experiment_infos = ExperimentInfo.each_from_file("#{SOURCE_FOLDER}/metrics_by_exp.tsv").reject{|info| info.type == 'control' }.to_a
experiment_infos.each(&:make_confirmed_peaks!)

tf_infos = experiment_infos.group_by{|info| info[:tf] }.map{|tf, infos|
  FileUtils.mkdir_p "#{RESULTS_FOLDER}/tf_peaks/#{tf}/best"
  FileUtils.mkdir_p "#{RESULTS_FOLDER}/tf_peaks/#{tf}/rest"
  sorted_peaks_infos = infos.sort_by(&:num_confirmed_peaks).reverse
  best_peak_info = sorted_peaks_infos.first
  rest_peak_infos = sorted_peaks_infos.drop(1)
  {tf: tf, best_peak: best_peak_info, rest_peaks: rest_peak_infos}
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
