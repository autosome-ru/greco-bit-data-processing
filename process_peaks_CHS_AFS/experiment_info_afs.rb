require_relative 'utils'
require_relative 'experiment_info_extension'

ExperimentInfoAFS = Struct.new(
  :experiment_id, :peak_id, :tf, :raw_files, :type, :cycle_number,
  :qc_estFragLen, :qc_FRiP_CPICS, :qc_FRiP_GEM, :qc_FRiP_MACS2_PEMODE, :qc_FRiP_SISSRS, :qc_NRF, :qc_NSC, :qc_PBC1, :qc_PBC2, :qc_RSC,
  :macs2_pemode_peak_count, :gem_peak_count, :sissrs_peak_count, :cpics_peak_count,
  :align_count, :align_percent, :read_count,
) do
  include ExperimentInfoExtension
  def self.from_string(str)
    row = str.chomp.split("\t", 22)

    experiment_id = row[0]
    tf = row[1]
    raw_files = row[2]
    peak_id = row[3]
    qc_estFragLen = row[4].yield_self{|val| Integer(val) rescue val }
    qc_FRiP_CPICS, qc_FRiP_GEM, qc_FRiP_MACS2_PEMODE, qc_FRiP_SISSRS, qc_NRF, qc_NSC, qc_PBC1, qc_PBC2, qc_RSC = *row[5..13].map{|val|
      Float(val.sub(",", ".")) rescue val
    }
    macs2_pemode_peak_count, gem_peak_count, sissrs_peak_count, cpics_peak_count = *row[14..17].map{|val|
      Integer(val) rescue val
    }
    align_count = row[18].yield_self{|val| Integer(val.gsub("\u00a0", "")) rescue val } # remove non-breaking spaces
    align_percent = row[19].yield_self{|val| Float(val.sub(",", ".")) rescue val }
    read_count = row[20].yield_self{|val| Integer(val) rescue val }

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

    self.new(
      experiment_id, peak_id, tf, raw_files, type, cycle_number,
      qc_estFragLen, qc_FRiP_CPICS, qc_FRiP_GEM, qc_FRiP_MACS2_PEMODE, qc_FRiP_SISSRS, qc_NRF, qc_NSC, qc_PBC1, qc_PBC2, qc_RSC,
      macs2_pemode_peak_count, gem_peak_count, sissrs_peak_count, cpics_peak_count,
      align_count, align_percent, read_count
    )
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
