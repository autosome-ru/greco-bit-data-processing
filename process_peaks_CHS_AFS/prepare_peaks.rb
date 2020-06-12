require 'fileutils'

def num_rows(filename, has_header: true)
  num_lines = File.readlines(filename).map(&:strip).reject(&:empty?).size
  has_header ? (num_lines - 1) : num_lines
end

def get_bed_intervals(filename, has_header: true)
  lines = File.readlines(filename)
  lines = lines.drop(1)  if has_header
  lines.map{|l|
    l.chomp.split("\t").first(3)
  }
end

def store_table(filename, rows)
  File.open(filename, 'w'){|fw|
    rows.each{|l|
      fw.puts(l.join("\t"))
    }
  }
end

PEAK_CALLERS = ['cpics', 'gem', 'macs2-pemode', 'sissrs']
MAIN_PEAK_CALLER = 'macs2-pemode'
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - [MAIN_PEAK_CALLER]

results_folder = ARGV[0] # 'results/affiseq'


all_peaks = File.readlines("#{results_folder}/tf_peaks.txt").map{|l|
  tf, peak_id = l.chomp.split("\t")

  num_train_peaks = PEAK_CALLERS.map{|peak_caller|
    num_peaks = num_rows("#{results_folder}/train/peaks-intervals/#{MAIN_PEAK_CALLER}/#{peak_id}.interval", has_header: true)
    [peak_caller, num_peaks]
  }.to_h
  num_validation_peaks = PEAK_CALLERS.map{|peak_caller|
    num_peaks = num_rows("#{results_folder}/validation/peaks-intervals/#{MAIN_PEAK_CALLER}/#{peak_id}.interval", has_header: true)
    [peak_caller, num_peaks]
  }.to_h
  {tf: tf, peak_id: peak_id, num_train_peaks: num_train_peaks, num_validation_peaks: num_validation_peaks}
}
peaks_by_tf = all_peaks.group_by{|info| info[:tf] }

['train', 'validation'].each do |chunk_type|
  confirmating_intervals_unsorted_dn = "#{results_folder}/#{chunk_type}/confirmating_intervals.unsorted"
  confirmating_intervals_dn = "#{results_folder}/#{chunk_type}/confirmating_intervals"
  confirmed_intervals_dn = "#{results_folder}/#{chunk_type}/confirmed_intervals"
  FileUtils.mkdir_p(confirmating_intervals_unsorted_dn)
  FileUtils.mkdir_p(confirmating_intervals_dn)
  FileUtils.mkdir_p(confirmed_intervals_dn)
  all_peaks.each{|peak_info|
    peak_id = peak_info[:peak_id]
    main_peak_fn = "#{results_folder}/#{chunk_type}/peaks-intervals/#{MAIN_PEAK_CALLER}/#{peak_id}.interval"
    supporting_peaks = SUPPLEMENTARY_PEAK_CALLERS.flat_map{|peak_caller|
      peaks_fn = "#{results_folder}/#{chunk_type}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
      File.exist?(peaks_fn)  ?  get_bed_intervals(peaks_fn, has_header: true)  :  []
    }
    confirmating_intervals_unsorted_fn = "#{confirmating_intervals_unsorted_dn}/#{peak_id}.bed"
    confirmating_intervals_fn = "#{confirmating_intervals_dn}/#{peak_id}.bed"
    store_table(confirmating_intervals_unsorted_fn, supporting_peaks)
    cmd = "cat #{confirmating_intervals_unsorted_fn} | sort -k1,1 -k2,2n | ./bedtools merge > #{confirmating_intervals_fn}"
    system(cmd)
    confirmed_intervals_fn = "#{confirmed_intervals_dn}/#{peak_id}.interval"
    cmd2 = "( head -1 #{main_peak_fn}; ./bedtools intersect -wa -a #{main_peak_fn} -b #{confirmating_intervals_fn} ) > #{confirmed_intervals_fn}"
    system(cmd2)
  }
end

all_peaks.each{|peak_info|
  peak_info[:num_confirmed_train_peaks] = num_rows("#{results_folder}/train/confirmed_intervals/#{peak_info[:peak_id]}.interval", has_header: true)
  peak_info[:num_confirmed_validation_peaks] = num_rows("#{results_folder}/validation/confirmed_intervals/#{peak_info[:peak_id]}.interval", has_header: true)
  peak_info[:num_confirmed_peaks] = peak_info[:num_confirmed_train_peaks] + peak_info[:num_confirmed_validation_peaks]
}

['train', 'validation'].each do |chunk_type|
  FileUtils.mkdir_p "#{results_folder}/#{chunk_type}/tf_peaks"
  peaks_by_tf.each{|tf, peak_infos|
    sorted_peaks_infos = peak_infos.sort_by{|peak_info|
      peak_info[:num_confirmed_peaks]
    }.reverse
    best_peak_info = sorted_peaks_infos.first
    other_peak_infos = sorted_peaks_infos.drop(1)
    FileUtils.cp("#{results_folder}/#{chunk_type}/confirmed_intervals/#{best_peak_info[:peak_id]}.interval", "#{results_folder}/#{chunk_type}/tf_peaks/#{tf}.interval")
  }
end
