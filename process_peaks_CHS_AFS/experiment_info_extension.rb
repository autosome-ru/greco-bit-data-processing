require 'fileutils'
module ExperimentInfoExtension
  def peak_fn_for_main_caller(source_folder, main_peak_callers:)
    main_peak_callers.map{|peak_caller|
      peak_fn_for_peakcaller(peak_caller, source_folder)
    }.detect{|fn| File.exist?(fn) }
  end

  def basename; raise NotImplementedError; end
  def confirmed_peaks_folder; @confirmed_peaks_folder || raise("No value specified"); end
  attr_writer :confirmed_peaks_folder

  def confirmed_peaks_fn
    "#{confirmed_peaks_folder}/#{basename}.interval"
  end

  def num_peaks_for_peakcaller(peak_caller, source_folder)
    peaks_fn = peak_fn_for_peakcaller(peak_caller, source_folder)
    File.exist?(peaks_fn) ? num_rows(peaks_fn, has_header: true) : nil
  end

  def num_confirmed_peaks
    File.exist?(confirmed_peaks_fn) ? num_rows(confirmed_peaks_fn, has_header: true) : 0
  end

  def confirmed_peaks_transformations(source_folder:, main_peak_callers:, supplementary_peak_callers:)
    supporting_intervals_file_infos = supplementary_peak_callers.map{|peak_caller|
      peaks_fn = peak_fn_for_peakcaller(peak_caller, source_folder)
      {filename: peaks_fn, name: peak_caller}
    }.select{|info| File.exist?(info[:filename]) }

    supporting_intervals = supporting_intervals_file_infos.flat_map{|info|
      get_bed_intervals(info[:filename], has_header: true, drop_wrong: true).map{|row|
        row + [info[:name]]
      }
    }
    main_peaks_fn = peak_fn_for_main_caller(source_folder, main_peak_callers: main_peak_callers)
    if !main_peaks_fn
      $stderr.puts "There is no main peaks file for experiment #{self.experiment_id}"
      return []
    elsif num_rows(main_peaks_fn, has_header: true) == 0
      $stderr.puts "Main peaks file `#{main_peaks_fn}` is empty for experiment #{self.experiment_id}"
      return []
    end
    if supporting_intervals.size == 0
      $stderr.puts "There are no supporting intervals for experiment #{self.experiment_id}. See `#{supporting_intervals_file_infos}`."
      return []
    end
    transformations = []
    transformations << {
      main_peaks_fn: main_peaks_fn,
      resulting_peaks_fn: confirmed_peaks_fn,
      supporting_intervals: supporting_intervals,
      tempfile_fn: "#{peak_id}.supplementary_callers.bed"
    }
    transformations
  end

  def make_confirmed_peaks!(source_folder:, main_peak_callers:, supplementary_peak_callers:)
    confirmed_peaks_transformations(
      source_folder: source_folder,
      main_peak_callers: main_peak_callers,
      supplementary_peak_callers: supplementary_peak_callers
    ).each{|transformation|
      main_peaks_fn = transformation[:main_peaks_fn]
      resulting_peaks_fn = transformation[:resulting_peaks_fn]

      supporting_intervals_file = Tempfile.new( transformation[:tempfile_fn] ).tap(&:close)
      store_table(supporting_intervals_file.path, transformation[:supporting_intervals])
      # make_merged_intervals(supporting_intervals_file.path, transformation[:supporting_intervals])

      header = `head -1 #{main_peaks_fn}`.chomp
      system("echo '#{header}' '\t' supporting_peakcallers  > #{resulting_peaks_fn}")
      cmd = [
        "./bedtools intersect -loj -a #{main_peaks_fn} -b #{supporting_intervals_file.path}",
        "sort -k1,9",
        "./bedtools groupby -g 1,2,3,4,5,6,7,8,9 -c 13 -o distinct",
        "awk -F '\t' -e '$10 != \".\"'",
        "sed -re 's/^([0-9]+|[XYM])\\t/chr\\1\\t/'",
      ].join(" | ")
      system("#{cmd} >> #{resulting_peaks_fn}")
      supporting_intervals_file.unlink
    }
  end

  def peak_fn_for_peakcaller(peak_caller, source_folder)
    raise NotImplementedError
  end

  def raw_datasets
    raw_files.map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn|
      bn.sub(/_R[12](_001)?$/,'')
        .sub(/_Read[12]/i, '') # non-standard read number for controls
      }.uniq.join(';')
  end

  def dataset_id
    raw_datasets.split(';').map{|ds| ds.sub(/_Cyc(le)?\d$/i, '') }.uniq.take_the_only
  end

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def each_from_file(filename, &block)
      return enum_for(:each_from_file, filename)  unless block_given?
      header, *rows = File.readlines(filename)
      rows.each{|l|
        yield self.from_string(l, header: header)
      }
    end

    def from_string(str, header:)
      raise NotImplementedError
    end
  end
end
