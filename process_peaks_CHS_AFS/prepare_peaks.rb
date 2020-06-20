require 'fileutils'
require 'tempfile'

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

def make_confirmed_peaks(peak_id, filename, &peaks_filename)
  main_peak_fn = peaks_filename.call(MAIN_PEAK_CALLER, peak_id)
  supporting_intervals = SUPPLEMENTARY_PEAK_CALLERS.flat_map{|peak_caller|
    peaks_fn = peaks_filename.call(peak_caller, peak_id)
    File.exist?(peaks_fn)  ?  get_bed_intervals(peaks_fn, has_header: true, drop_wrong: true)  :  []
  }
  supporting_intervals_file = Tempfile.new("#{peak_id}.supplementary_callers.bed").tap(&:close)
  make_merged_intervals(supporting_intervals_file.path, supporting_intervals)
    
  system("( head -1 #{main_peak_fn}; ./bedtools intersect -wa -a #{main_peak_fn} -b #{supporting_intervals_file.path} ) | sed -re 's/^([0-9]+|[XYM])\\t/chr\\1\\t/' > #{filename}")
  supporting_intervals_file.unlink
end

def num_peaks_by_peakcaller(peak_id, &peaks_filename)
  PEAK_CALLERS.map{|peak_caller|
    peak_fn = peaks_filename.call(peak_caller, peak_id)
    num_peaks = File.exist?(peak_fn)  ?  num_rows(peak_fn, has_header: true) : 0
    [peak_caller, num_peaks]
  }.to_h
end

PEAK_CALLERS = ['macs2-pemode', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLER = 'macs2-pemode'
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - [MAIN_PEAK_CALLER]

source_folder = ARGV[0] # 'source_data/affiseq'
results_folder = ARGV[1] # 'results/affiseq'

confirmed_intervals_dirname = "#{results_folder}/confirmed_intervals"
FileUtils.mkdir_p(confirmed_intervals_dirname)

peaks_filename = ->(peak_caller, peak_id){ "#{source_folder}/peaks-intervals/#{peak_caller}/#{peak_id}.interval" }
confirmed_peaks_filename = ->(peak_id){ "#{confirmed_intervals_dirname}/#{peak_id}.interval" }

all_peaks = File.readlines("#{results_folder}/tf_peaks.txt").map{|l|
  tf, peak_id = l.chomp.split("\t")
  {
    tf: tf,
    peak_id: peak_id,
    num_peaks: num_peaks_by_peakcaller(peak_id, &peaks_filename),
  }
}

all_peaks.each{|peak_info|
  confirmed_peaks_fn = confirmed_peaks_filename.call(peak_info[:peak_id])
  make_confirmed_peaks(peak_info[:peak_id], confirmed_peaks_fn, &peaks_filename)
  peak_info[:num_confirmed_peaks] = num_rows(confirmed_peaks_fn, has_header: true)
}

peaks_by_tf = all_peaks.group_by{|info| info[:tf] }

tf_infos = peaks_by_tf.map{|tf, peak_infos|
  FileUtils.mkdir_p "#{results_folder}/tf_peaks/#{tf}/best"
  FileUtils.mkdir_p "#{results_folder}/tf_peaks/#{tf}/rest"
  sorted_peaks_infos = peak_infos.sort_by{|peak_info|
    peak_info[:num_confirmed_peaks]
  }.reverse
  best_peak_info = sorted_peaks_infos.first
  rest_peak_infos = sorted_peaks_infos.drop(1)
  {tf: tf, best_peak: best_peak_info, rest_peaks: rest_peak_infos}
}

tf_infos.each{|tf_info|
  peak_fn = "#{results_folder}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak][:peak_id]}.interval"
  FileUtils.cp(confirmed_peaks_filename.call(tf_info[:best_peak][:peak_id]), peak_fn)
  tf_info[:rest_peaks].each{|peak_info|
    peak_fn = "#{results_folder}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info[:peak_id]}.interval"
    FileUtils.cp(confirmed_peaks_filename.call(peak_info[:peak_id]), peak_fn)
  }

  # train & basic validation
  peak_fn = "#{results_folder}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak][:peak_id]}.interval"
  train_fn = "#{results_folder}/train/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.train.interval"
  validation_fn = "#{results_folder}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.basic_validation.interval"
  system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"

  # advanced validation
  if tf_info[:best_peak][:num_confirmed_peaks] >= 200
    rest_peaks_file = Tempfile.new("rest_peaks.interval")
    header = File.readlines("#{results_folder}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak][:peak_id]}.interval").first
    rest_peaks_file.puts(header)
    tf_info[:rest_peaks].flat_map{|peak_info|
      peak_fn = "#{results_folder}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info[:peak_id]}.interval"
      File.readlines(peak_fn).drop(1).each{|row|
        rest_peaks_file.puts(row)
      }
    }
    rest_peaks_file.close

    peak_fn = rest_peaks_file.path
    train_fn = '/dev/null'
    validation_fn = "#{results_folder}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation.interval"
    system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"
    rest_peaks_file.unlink
  end
}

File.open("#{results_folder}/confirmed_peaks_stats.tsv", 'w') {|fw|
  header = ['peak_id', 'tf', 'best_or_rest', 'num_confirmed_peaks', *PEAK_CALLERS.map{|peak_caller| "num_peaks:#{peak_caller}" }]
  fw.puts(header.join("\t"))
  tf_infos.each{|tf_info|
    peak_info = tf_info[:best_peak]
    row = [peak_info[:peak_id], tf_info[:tf], 'best', peak_info[:num_confirmed_peaks], *PEAK_CALLERS.map{|peak_caller| peak_info[:num_peaks][peak_caller] } ]
    fw.puts(row.join("\t"))

    tf_info[:rest_peaks].each{|peak_info|
      row = [peak_info[:peak_id], tf_info[:tf], 'rest', peak_info[:num_confirmed_peaks], *PEAK_CALLERS.map{|peak_caller| peak_info[:num_peaks][peak_caller] } ]
      fw.puts(row.join("\t"))
    }
  }
}

File.open("#{results_folder}/train_val_peaks_stats.tsv", 'w') {|fw|
  header = ['peak_id', 'tf', 'type', 'num_peaks', 'filename']
  fw.puts(header.join("\t"))
  tf_infos.each{|tf_info|
    peak_info = tf_info[:best_peak]
    train_fn = "#{results_folder}/train/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.train.interval"
    basic_validation_fn = "#{results_folder}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.basic_validation.interval"
    advanced_validation_fn = "#{results_folder}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation.interval"
    
    row = [peak_info[:peak_id], tf_info[:tf], 'train', num_rows(train_fn, has_header: true), train_fn]
    fw.puts(row.join("\t"))

    row = [peak_info[:peak_id], tf_info[:tf], 'basic_validation', num_rows(basic_validation_fn, has_header: true), basic_validation_fn]
    fw.puts(row.join("\t"))

    if File.exist?(advanced_validation_fn)
      row = [peak_info[:peak_id], tf_info[:tf], 'advanced_validation', num_rows(advanced_validation_fn, has_header: true), advanced_validation_fn]
      fw.puts(row.join("\t"))
    end
  }
}
