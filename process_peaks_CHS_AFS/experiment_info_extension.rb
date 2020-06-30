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
