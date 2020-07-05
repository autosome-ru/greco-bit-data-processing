module ExperimentInfoExtension
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
    supporting_intervals_file_infos = SUPPLEMENTARY_PEAK_CALLERS.map{|peak_caller|
      peaks_fn = peak_fn_for_peakcaller(peak_caller)
      {filename: peaks_fn, name: peak_caller}
    }.select{|info| File.exist?(info[:filename]) }

    supporting_intervals = supporting_intervals_file_infos.flat_map{|info|
      get_bed_intervals(info[:filename], has_header: true, drop_wrong: true).map{|row|
        row + [info[:name]]
      }
    }
    supporting_intervals_file = Tempfile.new("#{peak_id}.supplementary_callers.bed").tap(&:close)
    store_table(supporting_intervals_file.path, supporting_intervals)
    # make_merged_intervals(supporting_intervals_file.path, supporting_intervals)

    header = `head -1 #{peak_fn_for_main_caller}`.chomp
    system("echo '#{header}' '\t' supporting_peakcallers  > #{confirmed_peaks_fn}")
    system("./bedtools intersect -loj -a #{peak_fn_for_main_caller} -b #{supporting_intervals_file.path} | sort -k1,9 | bedtools groupby -g 1,2,3,4,5,6,7,8,9 -c 13 -o distinct | awk -F '\t' -e '$13 != \".\"' | sed -re 's/^([0-9]+|[XYM])\\t/chr\\1\\t/' >> #{confirmed_peaks_fn}")
    supporting_intervals_file.unlink
  end

  def peak_fn_for_peakcaller(peak_caller)
    raise NotImplementedError
  end

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def each_from_file(filename, &block)
      return enum_for(:each_from_file, filename)  unless block_given?
      File.readlines(filename).drop(1).each{|l|
        yield self.from_string(l)
      }
    end

    def from_string(str)
      raise NotImplementedError
    end
  end
end
