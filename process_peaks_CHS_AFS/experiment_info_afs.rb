require_relative 'utils'
require_relative 'experiment_info_extension'

ExperimentInfoAFS = Struct.new(*[
  :experiment_id, :peak_id, :tf, :raw_files, :type, :cycle_number, :batch,
  :qc_estFragLen, :qc_FRiP_CPICS, :qc_FRiP_GEM, :qc_FRiP_MACS2_NOMODEL, :qc_FRiP_MACS2_PEMODE, :qc_FRiP_SISSRS, :qc_NRF, :qc_NSC, :qc_PBC1, :qc_PBC2, :qc_RSC,
  :macs2_nomodel_peak_count, :macs2_pemode_peak_count, :gem_peak_count, :sissrs_peak_count, :cpics_peak_count,
  :align_count, :align_percent, :read_count,
], keyword_init: true) do
  include ExperimentInfoExtension

  def self.each_from_file(filename, metadata, &block)
    return enum_for(:each_from_file, filename, metadata)  unless block_given?
    header, *rows = File.readlines(filename)
    metadata_index = metadata.index_by(&:normalized_basename)
    rows.each{|l|
      yield self.from_string_and_metadata_index(l, header: header, metadata_by_normalized_basename: metadata_index)
    }
  end

  def self.from_string(str, header:, metadata:)
    from_string_and_metadata_index(str, header: header, metadata_by_normalized_basename: metadata.index_by(&:normalized_basename))
  end

  def self.from_string_and_metadata_index(str, header:, metadata_by_normalized_basename:)
    header = header.chomp.split("\t", 100500)  if header.is_a?(String)
    unpacked_row = str.chomp.split("\t", 100500)
    header_mapping = {
      "Peaks (/home_local/ivanyev/egrid/dfs-affyseq/peaks-interval)" => "Peaks",
      "Raw files" => "RawFiles",
      "macs2-single-end-peak-count" => "macs2-nomodel-peak-count",
      "macs2-paired-end-peak-count" => "macs2-pemode-peak-count",
      "QC.estFragLen (max cross-correlation)" => "QC.estFragLen",
    }
    header = header.map{|name| header_mapping.fetch(name, name) }
    row = header.zip(unpacked_row).to_h

    experiment_id = row['ID']
    tf = row['TF']
    raw_files = row['RawFiles'].split(/[;,]/)
    row['Peaks'] = ''  if row['Peaks'] == 'NULL'
    peak_id = row['Peaks']
    qc_estFragLen = row['QC.estFragLen'].yield_self{|val| Integer(val) rescue val }


    qc_FRiP_CPICS, qc_FRiP_GEM, qc_FRiP_MACS2_NOMODEL, qc_FRiP_MACS2_PEMODE, qc_FRiP_SISSRS, qc_NRF, qc_NSC, qc_PBC1, qc_PBC2, qc_RSC = *[
      'QC.FRiP_CPICS', 'QC.FRiP_GEM', 'QC.FRiP_MACS2-NOMODEL', 'QC.FRiP_MACS2-PEMODE', 'QC.FRiP_SISSRS', 'QC.NRF', 'QC.NSC', 'QC.PBC1', 'QC.PBC2', 'QC.RSC',
    ].map{|k| row[k] }.map{|val|
      Float(val.sub(",", ".")) rescue val
    }
    macs2_nomodel_peak_count, macs2_pemode_peak_count, gem_peak_count, sissrs_peak_count, cpics_peak_count = *[
      'macs2-nomodel-peak-count', 'macs2-pemode-peak-count', 'gem-peak-count', 'sissrs-peak-count', 'cpics-peak-count',
    ].map{|k| row[k] }.map{|val|
      Integer(val) rescue val
    }
    # macs2_nomodel_peak_count = nil
    align_count = row['align_count'].yield_self{|val| Integer(val.gsub("\u00a0", "")) rescue val } # remove non-breaking spaces
    align_percent = row['align_percent'].yield_self{|val| Float(val.sub(",", ".")) rescue val }
    read_count = row['read_count'].yield_self{|val| Integer(val) rescue val }

    if tf == 'CONTROL' || tf == 'NULL'
      tf = nil
      type = 'control'
    else
      if raw_files.first.match?(/Affi?Seq_IVT/)
        type = 'IVT'
      elsif raw_files.first.match?(/Affi?Seq_Lysate/)
        type = 'Lysate'
      elsif raw_files.first.match?(/Ecoli_GST/)
        type = 'Lysate'
      elsif raw_files.first.match?(/eGFP-IVT/)
        type = 'GFPIVT'
      else
        bn = File.basename(raw_files.first) \
          .sub(/_Cycle\d(_\w\d+)?_R(ead)?[12]\.fastq(\.gz)?$/, '') \
          .sub(/_Cycle\d_S\d+_R[12]_001\.fastq(\.gz)?$/, '') \
          .sub(/_cyc\d_read[12]\.fastq(\.gz)?$/, '')
        type = metadata_by_normalized_basename[bn].ivt_or_lysate
        type = {'Lys' => 'Lysate'}.fetch(type, type)
        raise "Cannot infer type for #{bn}"  if !type
      end

      batch = raw_files.map{|fn| File.basename(fn)[/Batch([^_]+)/, 1] }.uniq.take_the_only
    end

    cycle_number_variants = raw_files.map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn| bn[/Cycle\d+/] }.uniq
    cycle_number = (type != 'control') ? take_the_only(cycle_number_variants) : nil

    self.new(
      experiment_id: experiment_id, peak_id: peak_id, tf: tf, raw_files: raw_files, type: type, cycle_number: cycle_number, batch: batch,
      qc_estFragLen: qc_estFragLen, qc_FRiP_CPICS: qc_FRiP_CPICS, qc_FRiP_GEM: qc_FRiP_GEM,
      qc_FRiP_MACS2_NOMODEL: qc_FRiP_MACS2_NOMODEL, qc_FRiP_MACS2_PEMODE: qc_FRiP_MACS2_PEMODE, qc_FRiP_SISSRS: qc_FRiP_SISSRS,
      qc_NRF: qc_NRF, qc_NSC: qc_NSC, qc_PBC1: qc_PBC1, qc_PBC2: qc_PBC2, qc_RSC: qc_RSC,
      macs2_nomodel_peak_count: macs2_nomodel_peak_count, macs2_pemode_peak_count: macs2_pemode_peak_count,
      gem_peak_count: gem_peak_count, sissrs_peak_count: sissrs_peak_count, cpics_peak_count: cpics_peak_count,
      align_count: align_count, align_percent: align_percent, read_count: read_count,
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
    when 'IVT', 'Lysate', 'GFPIVT'
      "#{source_folder}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end
end
