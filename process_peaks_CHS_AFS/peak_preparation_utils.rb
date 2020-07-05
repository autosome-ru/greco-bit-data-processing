require 'tempfile'
require 'fileutils'

def make_merged_intervals(filename, intervals)
  intervals_unsorted = Tempfile.new("intervals_unsorted.bed").tap(&:close)
  store_table(intervals_unsorted.path, intervals)
  system("cat #{intervals_unsorted.path} | sort -k1,1 -k2,2n | ./bedtools merge > #{filename}")
  intervals_unsorted.unlink
end

# def annotate_overlaps(filename, in)
#   merged_intervals_file = Tempfile.new("merged").tap(&:close)

def split_train_val!(tf_info)
  peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak].peak_id}.interval"
  FileUtils.cp(tf_info[:best_peak].confirmed_peaks_fn, peak_fn)
  tf_info[:rest_peaks].each{|peak_info|
    peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info.peak_id}.interval"
    FileUtils.cp(peak_info.confirmed_peaks_fn, peak_fn)
  }

  # train & basic validation
  peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak].peak_id}.interval"
  train_fn = "#{RESULTS_FOLDER}/train/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.train.#{tf_info[:best_peak].peak_id}.interval"
  validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.basic_validation.#{tf_info[:best_peak].peak_id}.interval"
  system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"

  # advanced validation
  # if tf_info[:best_peak].num_confirmed_peaks >= 200
  #   rest_peaks_file = Tempfile.new("rest_peaks.interval")
  #   header = File.readlines("#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/best/#{tf_info[:best_peak].peak_id}.interval").first
  #   rest_peaks_file.puts(header)
  #   tf_info[:rest_peaks].flat_map{|peak_info|
  #     peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info.peak_id}.interval"
  #     File.readlines(peak_fn).drop(1).each{|row|
  #       rest_peaks_file.puts(row)
  #     }
  #   }
  #   rest_peaks_file.close

  #   peak_fn = rest_peaks_file.path
  #   train_fn = '/dev/null'
  #   validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation.interval"
  #   system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"
  #   rest_peaks_file.unlink
  # end

  if tf_info[:best_peak].num_confirmed_peaks >= 200
    sorted_rest_peaks_infos = tf_info[:rest_peaks].sort_by{|peak_info|
      peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info.peak_id}.interval"
      num_rows(peak_fn, has_header: true)
    }.reverse
    idx = 1
    sorted_rest_peaks_infos.each{|peak_info|
      peak_fn = "#{RESULTS_FOLDER}/tf_peaks/#{tf_info[:tf]}/rest/#{peak_info.peak_id}.interval"
      train_fn = '/dev/null'
      validation_fn = "#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation_#{idx}.#{peak_info.peak_id}.interval"
      system "ruby split_train_val.rb #{peak_fn} #{train_fn} #{validation_fn}"
      if num_rows(validation_fn, has_header: true) >= 50
        idx += 1
      else
        FileUtils.rm(validation_fn)
      end
    }
  end
end

def store_confirmed_peak_stats(tf_infos, filename)
  File.open(filename, 'w') {|fw|
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
end

def store_train_val_stats(tf_infos, filename)
  File.open(filename, 'w') {|fw|
    header = ['peak_id', 'tf', 'type', 'num_peaks', 'filename', 'peak_id']
    fw.puts(header.join("\t"))
    tf_infos.each{|tf_info|
      peak_info = tf_info[:best_peak]
      Dir.glob("#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.train.*.interval").each{|train_fn|
        train_peak_id = File.basename(train_fn, '.interval').split('.').last
        row = [peak_info.peak_id, tf_info[:tf], 'train', num_rows(train_fn, has_header: true), train_fn, train_peak_id]
        fw.puts(row.join("\t"))
      }

      Dir.glob("#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.basic_validation.*.interval").each{|basic_validation_fn|
        validation_peak_id = File.basename(basic_validation_fn, '.interval').split('.').last
        row = [peak_info.peak_id, tf_info[:tf], 'basic_validation', num_rows(basic_validation_fn, has_header: true), basic_validation_fn, validation_peak_id]
        fw.puts(row.join("\t"))
      }

      Dir.glob("#{RESULTS_FOLDER}/validation/tf_peaks/#{tf_info[:tf]}/#{tf_info[:tf]}.advanced_validation_*.*.interval").each{|advanced_validation_fn|
        validation_peak_id = File.basename(advanced_validation_fn, '.interval').split('.').last
        row = [peak_info.peak_id, tf_info[:tf], 'advanced_validation', num_rows(advanced_validation_fn, has_header: true), advanced_validation_fn]
        fw.puts(row.join("\t"))
      }
    }
  }
end
