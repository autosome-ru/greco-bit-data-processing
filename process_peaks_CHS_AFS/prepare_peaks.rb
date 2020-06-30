require 'fileutils'
require 'tempfile'

def take_the_only(vs)
  raise "Size of #{vs} should be 1 but was #{vs.size}" unless vs.size == 1
  vs[0]
end

def num_rows(filename, has_header: true)
  num_lines = File.readlines(filename).map(&:strip).reject(&:empty?).size
  has_header ? (num_lines - 1) : num_lines
end

def get_bed_intervals(filename, has_header: true, drop_wrong: false)
  lines = File.readlines(filename)
  lines = lines.drop(1)  if has_header
  lines.map{|l|
    l.chomp.split("\t").first(3)
  }.reject{|r|
    drop_wrong && Integer(r[1]) < 0
  }
end

def store_table(filename, rows)
  File.open(filename, 'w'){|fw|
    rows.each{|l|
      fw.puts(l.join("\t"))
    }
  }
end

def make_merged_intervals(filename, intervals)
  intervals_unsorted = Tempfile.new("intervals_unsorted.bed").tap(&:close)
  store_table(intervals_unsorted.path, intervals)
  system("cat #{intervals_unsorted.path} | sort -k1,1 -k2,2n | ./bedtools merge > #{filename}")
  intervals_unsorted.unlink
end

PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

SOURCE_FOLDER = ARGV[0] # 'source_data/chipseq'
RESULTS_FOLDER = ARGV[1] # 'results/chipseq'


FileUtils.mkdir_p("#{RESULTS_FOLDER}/confirmed_intervals")

confirmed_peaks_filename = ->(peak_id){ "#{confirmed_intervals_dirname}/#{peak_id}.interval" }

ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_fastq, :peaks, :peak_count_macs2_nomodel, :peak_count_macs2_pemode, :type) do
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

  def self.each_from_file(filename, &block)
    return enum_for(:each_from_file, filename)  unless block_given?
    File.readlines(filename).drop(1).each{|l|
      yield self.from_string(l)
    }
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

  def peak_fn_for_main_caller
    MAIN_PEAK_CALLERS.map{|peak_caller|
      peak_fn_for_peakcaller(peak_caller)
    }.detect{|fn| File.exist?(fn) }
  end

  def confirmed_peaks_fn
    "#{RESULTS_FOLDER}/confirmed_intervals/#{peak_id}.interval"
  end

  def num_peaks_for_peakcaller(peak_caller)
    peaks_fn = peak_fn_for_peakcaller(peak_caller)
    File.exist?(peaks_fn) ? num_rows(peaks_fn, has_header: true) : nil
  end

  def num_confirmed_peaks
    num_rows(confirmed_peaks_fn, has_header: true)
  end

  def make_confirmed_peaks!
    supporting_intervals = SUPPLEMENTARY_PEAK_CALLERS.flat_map{|peak_caller|
      peaks_fn = peak_fn_for_peakcaller(peak_caller)
      File.exist?(peaks_fn)  ?  get_bed_intervals(peaks_fn, has_header: true, drop_wrong: true)  :  []
    }
    supporting_intervals_file = Tempfile.new("#{peak_id}.supplementary_callers.bed").tap(&:close)
    make_merged_intervals(supporting_intervals_file.path, supporting_intervals)

    system("head -1 #{peak_fn_for_main_caller} > #{confirmed_peaks_fn}")
    system("./bedtools intersect -wa -a #{peak_fn_for_main_caller} -b #{supporting_intervals_file.path}  | sed -re 's/^([0-9]+|[XYM])\\t/chr\\1\\t/' >> #{confirmed_peaks_fn}")
    supporting_intervals_file.unlink
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
