require 'tempfile'
require 'fileutils'

def make_merged_intervals(filename, intervals)
  intervals_unsorted = Tempfile.new("intervals_unsorted.bed").tap(&:close)
  store_table(intervals_unsorted.path, intervals)
  system("cat #{intervals_unsorted.path} | sort -k1,1 -k2,2n | ./bedtools merge > #{filename}")
  intervals_unsorted.unlink
end

def cleanup_bad_datasets!(tf_info, min_peaks: 50)
  tf = tf_info[:tf]
  train_fn = take_the_only( Dir.glob("#{RESULTS_FOLDER}/train_intervals/#{tf}.*.train.interval") )
  basic_fn = take_the_only( Dir.glob("#{RESULTS_FOLDER}/validation_intervals/#{tf}.*.basic_val.interval") )
  advanced_fns = Dir.glob("#{RESULTS_FOLDER}/validation_intervals/#{tf}.*.advanced_val_*.interval")
  if num_rows(train_fn, has_header: true) < min_peaks  ||  num_rows(basic_fn, has_header: true) < min_peaks
    [train_fn, basic_fn, *advanced_fns].each{|fn| FileUtils.rm(fn) }
  end
  advanced_fns.select{|fn| num_rows(fn, has_header: true) < min_peaks }.each{|fn| FileUtils.rm(fn) }
end

def split_train_val!(tf_info)
  return  unless File.exist?( tf_info[:best_peak].confirmed_peaks_fn )

  best_peak_file = Tempfile.new("#{tf_info[:best_peak].basename}.interval").tap(&:close)
  FileUtils.cp(tf_info[:best_peak].confirmed_peaks_fn, best_peak_file.path)

  # train & basic validation
  train_fn = "#{RESULTS_FOLDER}/train_intervals/#{tf_info[:best_peak].basename}.train.interval"
  validation_fn = "#{RESULTS_FOLDER}/validation_intervals/#{tf_info[:best_peak].basename}.basic_val.interval"
  system "ruby split_train_val.rb #{best_peak_file.path} #{train_fn} #{validation_fn}"
  best_peak_file.unlink
  
  if tf_info[:best_peak].num_confirmed_peaks >= 200
    
    sorted_rest_peaks_infos = tf_info[:rest_peaks].sort_by{|peak_info|
      num_rows(peak_info.confirmed_peaks_fn, has_header: true)
    }.reverse

    idx = 1
    sorted_rest_peaks_infos.each{|peak_info|
    
      rest_peak_file = Tempfile.new("#{peak_info.basename}.interval").tap(&:close)
      FileUtils.cp(peak_info.confirmed_peaks_fn, rest_peak_file.path)

      train_fn = '/dev/null'
      validation_fn = "#{RESULTS_FOLDER}/validation_intervals/#{peak_info.basename}.advanced_val_#{idx}.interval"
      system "ruby split_train_val.rb #{rest_peak_file.path} #{train_fn} #{validation_fn}"
      rest_peak_file.unlink
      # if num_rows(validation_fn, has_header: true) >= 50
        idx += 1
      # else
      #   FileUtils.rm(validation_fn)
      # end
    }
  end
end

def store_confirmed_peak_stats(tf_infos, filename)
  File.open(filename, 'w') {|fw|
    header = ['peak_id', 'tf', 'peak_type', 'is_best', 'num_confirmed_peaks', *PEAK_CALLERS.map{|peak_caller| "num_peaks:#{peak_caller}" }, 'filename']
    fw.puts(header.join("\t"))
    tf_infos.each{|tf_info|

      tf_info[:best_peak].yield_self{|peak_info|
        next  unless File.exist?(peak_info.confirmed_peaks_fn)
        row = [peak_info.peak_id, tf_info[:tf], peak_info.type, 'best', peak_info.num_confirmed_peaks, *PEAK_CALLERS.map{|peak_caller| peak_info.num_peaks_for_peakcaller(peak_caller) }, peak_info.confirmed_peaks_fn ]
        fw.puts(row.join("\t"))
      }

      tf_info[:rest_peaks].each{|peak_info|
        next  unless File.exist?(peak_info.confirmed_peaks_fn)
        row = [peak_info.peak_id, tf_info[:tf], peak_info.type, 'not_best', peak_info.num_confirmed_peaks, *PEAK_CALLERS.map{|peak_caller| peak_info.num_peaks_for_peakcaller(peak_caller) }, peak_info.confirmed_peaks_fn ]
        fw.puts(row.join("\t"))
      }
    }
  }
end

def store_train_val_stats(tf_infos, filename, experiment_by_peak_id)
  File.open(filename, 'w') {|fw|
    header = ['peak_id', 'tf', 'type', 'train/validation_intervals', 'num_peaks', 'filename', 'raw_datasets', 'raw_files']
    fw.puts(header.join("\t"))
    tf_infos.each{|tf_info|
      # peak_info = tf_info[:best_peak]
      tf = tf_info[:tf]
      Dir.glob("#{RESULTS_FOLDER}/train_intervals/#{tf}.*.train.interval").each{|train_fn|
        train_peak_id = ExperimentInfo.peak_id_from_basename(File.basename(train_fn, '.interval'))
        peak_info = experiment_by_peak_id[train_peak_id]
        row = [train_peak_id, tf, peak_info.type, 'train', num_rows(train_fn, has_header: true), train_fn, peak_info.raw_datasets, peak_info.raw_files]
        fw.puts(row.join("\t"))
      }

      Dir.glob("#{RESULTS_FOLDER}/validation_intervals/#{tf}.*.basic_val.interval").each{|basic_validation_fn|
        validation_peak_id = ExperimentInfo.peak_id_from_basename(File.basename(basic_validation_fn, '.interval'))
        peak_info = experiment_by_peak_id[validation_peak_id]
        row = [validation_peak_id, tf, peak_info.type, 'basic_validation', num_rows(basic_validation_fn, has_header: true), basic_validation_fn, peak_info.raw_datasets, peak_info.raw_files]
        fw.puts(row.join("\t"))
      }

      Dir.glob("#{RESULTS_FOLDER}/validation_intervals/#{tf}.*.advanced_val_*.interval").each{|advanced_validation_fn|
        validation_peak_id = ExperimentInfo.peak_id_from_basename(File.basename(advanced_validation_fn, '.interval'))
        peak_info = experiment_by_peak_id[validation_peak_id]
        row = [validation_peak_id, tf, peak_info.type, 'advanced_validation', num_rows(advanced_validation_fn, has_header: true), advanced_validation_fn, peak_info.raw_datasets, peak_info.raw_files]
        fw.puts(row.join("\t"))
      }
    }
  }
end
