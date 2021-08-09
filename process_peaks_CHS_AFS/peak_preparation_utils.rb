require 'tempfile'
require 'fileutils'
require 'shellwords'

def make_merged_intervals(filename, intervals)
  intervals_unsorted = Tempfile.new("intervals_unsorted.bed").tap(&:close)
  store_table(intervals_unsorted.path, intervals)
  system("cat #{intervals_unsorted.path} | sort -k1,1 -k2,2n | ./bedtools merge > #{filename}")
  intervals_unsorted.unlink
end

def cleanup_bad_datasets!(tf_info, results_folder, min_peaks: 50)
  tf = tf_info[:tf]
  train_fns = Dir.glob("#{results_folder}/Train_intervals/#{tf}.*.train.interval")
  basic_validation_fns = Dir.glob("#{results_folder}/Val_intervals/#{tf}.*.basic_val.interval")
  advanced_validation_fns = Dir.glob("#{results_folder}/Val_intervals/#{tf}.*.advanced_val_*.interval")

  train_ok = (train_fns.size == 1) && (num_rows(train_fns.first, has_header: true) >= min_peaks)
  basic_validation_ok = (basic_validation_fns.size == 1) && (num_rows(basic_validation_fns.first, has_header: true) >= min_peaks)
  if !(train_ok && basic_validation_ok)
    [*train_fns, *basic_validation_fns, *advanced_validation_fns].each{|fn| FileUtils.rm(fn) }
  else
    advanced_validation_fns.select{|fn| num_rows(fn, has_header: true) < min_peaks }.each{|fn| FileUtils.rm(fn) }
  end
end

def split_train_val_transformations(tf_info, results_folder)
  results = []
  return  results  unless File.exist?( tf_info[:best_peak].confirmed_peaks_fn )

  # train & basic validation
  best_peak_info = tf_info[:best_peak]
  results << {
    original_fn: best_peak_info.confirmed_peaks_fn,
    train_fn: "#{results_folder}/Train_intervals/#{best_peak_info.basename}.train.interval",
    validation_fn: "#{results_folder}/Val_intervals/#{best_peak_info.basename}.basic_val.interval",
  }

  sorted_rest_peaks_infos = tf_info[:rest_peaks].sort_by{|peak_info|
    num_rows(peak_info.confirmed_peaks_fn, has_header: true)
  }.reverse

  sorted_rest_peaks_infos.each_with_index{|peak_info, idx|
    results << {
      original_fn: peak_info.confirmed_peaks_fn,
      train_fn: nil,
      validation_fn: "#{results_folder}/Val_intervals/#{peak_info.basename}.advanced_val_#{idx + 1}.interval",
    }
  }
  results
end

def split_train_val!(tf_info, results_folder)
  split_train_val_transformations(tf_info, results_folder).each{|transformation|
    original_fn = transformation[:original_fn]
    train_fn = transformation[:train_fn] || '/dev/null'
    validation_fn = transformation[:validation_fn] || '/dev/null'
    system "ruby #{__dir__}/split_train_val.rb #{original_fn.shellescape} #{train_fn.shellescape} #{validation_fn.shellescape}"
  }
end

def store_confirmed_peak_stats(tf_infos, filename, source_folder:, peak_callers:)
  File.open(filename, 'w') {|fw|
    header = ['peak_id', 'tf', 'peak_type', 'is_best', 'num_confirmed_peaks', *peak_callers.map{|peak_caller| "num_peaks:#{peak_caller}" }, 'filename']
    fw.puts(header.join("\t"))
    tf_infos.each{|tf_info|

      tf_info[:best_peak].yield_self{|peak_info|
        next  unless File.exist?(peak_info.confirmed_peaks_fn)
        row = [
          peak_info.peak_id, tf_info[:tf], peak_info.type, 'best',
          peak_info.num_confirmed_peaks,
          *peak_callers.map{|peak_caller|
            peak_info.num_peaks_for_peakcaller(peak_caller, source_folder: source_folder)
          },
          peak_info.confirmed_peaks_fn,
         ]
        fw.puts(row.join("\t"))
      }

      tf_info[:rest_peaks].each{|peak_info|
        next  unless File.exist?(peak_info.confirmed_peaks_fn)
        row = [
          peak_info.peak_id, tf_info[:tf], peak_info.type, 'not_best',
          peak_info.num_confirmed_peaks,
          *peak_callers.map{|peak_caller|
            peak_info.num_peaks_for_peakcaller(peak_caller, source_folder: source_folder)
          },
          peak_info.confirmed_peaks_fn,
        ]
        fw.puts(row.join("\t"))
      }
    }
  }
end

# get_peak_id: ->(fn){ ... }
def store_train_val_stats(tf_infos, filename, experiment_by_peak_id, results_folder, get_peak_id:)
  File.open(filename, 'w') {|fw|
    header = ['peak_id', 'tf', 'type', 'train/validation_intervals', 'num_peaks', 'filename', 'raw_datasets', 'raw_files']
    fw.puts(header.join("\t"))
    tf_infos.each{|tf_info|
      # peak_info = tf_info[:best_peak]
      tf = tf_info[:tf]
      Dir.glob("#{results_folder}/Train_intervals/#{tf}.*.train.interval").each{|train_fn|
        train_peak_id = get_peak_id.call(train_fn)
        peak_info = experiment_by_peak_id[train_peak_id]
        row = [train_peak_id, tf, peak_info.type, 'train', num_rows(train_fn, has_header: true), train_fn, peak_info.raw_datasets, peak_info.raw_files.join(';')]
        fw.puts(row.join("\t"))
      }

      Dir.glob("#{results_folder}/Val_intervals/#{tf}.*.basic_val.interval").each{|basic_validation_fn|
        validation_peak_id = get_peak_id.call(basic_validation_fn)
        peak_info = experiment_by_peak_id[validation_peak_id]
        row = [validation_peak_id, tf, peak_info.type, 'basic_validation', num_rows(basic_validation_fn, has_header: true), basic_validation_fn, peak_info.raw_datasets, peak_info.raw_files.join(';')]
        fw.puts(row.join("\t"))
      }

      Dir.glob("#{results_folder}/Val_intervals/#{tf}.*.advanced_val_*.interval").each{|advanced_validation_fn|
        validation_peak_id = get_peak_id.call(advanced_validation_fn)
        peak_info = experiment_by_peak_id[validation_peak_id]
        row = [validation_peak_id, tf, peak_info.type, 'advanced_validation', num_rows(advanced_validation_fn, has_header: true), advanced_validation_fn, peak_info.raw_datasets, peak_info.raw_files.join(';')]
        fw.puts(row.join("\t"))
      }
    }
  }
end
