require_relative 'utils'
require_relative 'experiment_info_extension'

SOURCE_FOLDER = 'source_data/AFS/'
ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_files, :type, :cycle_number) do
  include ExperimentInfoExtension
  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_files = row[2]
    peak_id = row[3]
    cycle_number = take_the_only( raw_files.split(';').map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn| bn[/Cycle\d+/] }.uniq )

    if tf == 'CONTROL'
      type = 'control'
    else
      raw_files_list = raw_files.split(';')
      if raw_files_list.first.match?(/AffSeq_IVT/)
        type = 'IVT'
      elsif raw_files_list.first.match?(/AffSeq_Lysate/)
        type = 'Lysate'
      end
    end

    self.new(experiment_id, peak_id, tf, raw_files, type, cycle_number)
  end

  # GLI4.IVT.Cycle3.PEAKS991005
  def basename
    "#{tf}.#{type}.#{cycle_number}.#{peak_id}.affiseq"
  end

  def self.peak_id_from_basename(bn)
    bn.split('.')[3]
  end

  def peak_fn_for_peakcaller(peak_caller, source_folder)
    case type
    when 'control'
      raise "No peak file for control #{peak_id}"
    when 'IVT', 'Lysate'
      "#{source_folder}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end
end
