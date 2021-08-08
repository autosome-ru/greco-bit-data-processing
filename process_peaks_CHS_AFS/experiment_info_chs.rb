require_relative 'utils'
require_relative 'experiment_info_extension'

ExperimentInfoCHS = Struct.new(*[
  :experiment_id, :tf, :raw_files, :peaks, :reads_id,
  :peak_id, :type, :plate_id,
  :peak_count_MACS2_SE, :peak_count_MACS2_PE, :peak_count_GEM, :peak_count_SISSRS, :peak_count_CPICS,
  :qc_estFragLen,
  :qc_FRiP_MACS2_SE, :qc_FRiP_MACS2_PE, :qc_FRiP_GEM, :qc_FRiP_SISSRS, :qc_FRiP_CPICS,
  :qc_NRF, :qc_NSC, :qc_PBC1, :qc_PBC2, :qc_RSC,
  :align_count, :align_percent, :read_count,
], keyword_init: true) do
  include ExperimentInfoExtension

  def self.from_string(str, header:)
    header_mapping = {
      'ID' => 'experiment_id',
      'EXP_ID' => 'experiment_id',
      'TF' => 'tf',
      'Raw files' => 'raw_files',
      'FilePath' => 'raw_files',
      'RawFiles(/mnt/space/hughes/June1st2021/ChipSeq/)' => 'raw_files',
      'Peaks' => 'peaks',
      'Peaks (/mnt/space/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/)' => 'peaks',
      'Peaks(/mnt/space/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval)' => 'peaks',
      'ReadsID' => 'reads_id',

      'peak_count_macs2_nomodel'    => 'peak_count_MACS2_SE',
      'macs2-single-end-peak-count' => 'peak_count_MACS2_SE',
      'peak_count_macs2_pemode'     => 'peak_count_MACS2_PE',
      'macs2-pemode-peak-count'     => 'peak_count_MACS2_PE',
      'macs2-paired-end-peak-count' => 'peak_count_MACS2_PE',
      'gem-peak-count'              => 'peak_count_GEM',
      'sissrs-peak-count'           => 'peak_count_SISSRS',
      'cpics-peak-count'            => 'peak_count_CPICS',

      'QC.estFragLen (max cross-correlation)' => 'qc_estFragLen',
      'QC.estFragLen' => 'qc_estFragLen',

      'QC.FRiP_MACS2-NOMODEL' => 'qc_FRiP_MACS2_SE',
      'QC.FRiP_MACS2-SE'      => 'qc_FRiP_MACS2_SE',
      'QC.FRiP_MACS2-PEMODE'  => 'qc_FRiP_MACS2_PE',
      'QC.FRiP_MACS2-PE'      => 'qc_FRiP_MACS2_PE',
      'QC.FRiP_GEM'           => 'qc_FRiP_GEM',
      'QC.FRiP_SISSRS'        => 'qc_FRiP_SISSRS',
      'QC.FRiP_CPICS'         => 'qc_FRiP_CPICS',

      'QC.NRF'  => 'qc_NRF',
      'QC.NSC'  => 'qc_NSC',
      'QC.PBC1' => 'qc_PBC1',
      'QC.PBC2' => 'qc_PBC2',
      'QC.RSC'  => 'qc_RSC',

      'readAlignedCount' => 'align_count',
      'alignPercent' => 'align_percent',
      'readCount' => 'read_count',
    }

    peak_count_attrs = [:peak_count_MACS2_SE, :peak_count_MACS2_PE, :peak_count_GEM, :peak_count_SISSRS, :peak_count_CPICS, ]
    qc_frip_attrs = [:qc_FRiP_MACS2_SE, :qc_FRiP_MACS2_PE, :qc_FRiP_GEM, :qc_FRiP_SISSRS, :qc_FRiP_CPICS, ]
    some_other_qc_attrs = [:qc_NRF, :qc_NSC, :qc_PBC1, :qc_PBC2, :qc_RSC, ]

    float_metrics = [*qc_frip_attrs, *some_other_qc_attrs, :align_percent, ]
    integer_metrics = [*peak_count_attrs, :qc_estFragLen, :align_count, :read_count, ]

    header = header.chomp.split("\t", 100500).map(&:strip)  if header.is_a?(String)
    unpacked_row = str.chomp.split("\t", 100500).map(&:strip)
    header = header.map{|name| header_mapping.fetch(name, name).to_sym }
    row = header.zip(unpacked_row).to_h

    nullify_for_control = [:tf, :peaks, *peak_count_attrs, *qc_frip_attrs, ]

    type = nil
    if nullify_for_control.all?{|k| ['CONTROL', 'NA', '', nil, 'NOT_PAIRED_END'].include?(row[k]) }
      type = 'control'
      peak_id = nil
    elsif nullify_for_control.any?{|k| ['CONTROL'].include?(row[k]) }
      type = 'control'
      peak_id = nil
      raise "Inconsistent data: some fields are marked as controls but not all for row:\n#{row}"
    elsif nullify_for_control.none?{|k| ['CONTROL'].include?(row[k]) }
      # pass
    else
      raise "Inconsistent data for row:\n#{row}"
    end

    nullify_for_control.each do |k|
      row[k] = nil  if ['CONTROL', 'NA', '', nil, 'NOT_PAIRED_END'].include?(row[k])
    end

    row[:peaks] = row[:peaks] ? row[:peaks].split(';') : []

    float_metrics.each{|k|
      val = row[k]
      val = val && val.sub(",", ".").gsub("\u00a0", "") # \u+00a0 -- nbsp
      row[k] = Float(val) rescue val
    }

    integer_metrics.each{|k|
      val = row[k]
      val = val && val.gsub("\u00a0", "") # \u+00a0 -- nbsp
      row[k] = Integer(val) rescue val
    }

    plate_ids = row[:raw_files].split(';').map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn| bn.sub(/_R[12](_001)?$/,'') }.uniq
    if plate_ids.size == 1
      plate_id = plate_ids[0]
    elsif plate_ids.size == 0
      raise "No plate id for row:\n#{row}"
    else
      parts = plate_ids[0].split('_').zip( *plate_ids.drop(1).map{|s| s.split('_') } ).map{|parts| parts.uniq }
      prefix = parts.take_while{|part| part.size == 1 }.flatten.join('_') + '_'
      plate_id = prefix + plate_ids.map{|s| s[prefix.size..-1] }.join('+')
      # plate_id_parts = plate_ids.tap{|x| p x }.map{|s| s.match(/^(.+)_(L\d+)$/) }
      # plate_id = take_the_only(plate_id_parts.map(&:first).uniq) + '_' + plate_id_parts.map(&:last).uniq.join('+')
    end

    if type != 'control'
      peak_bns = row[:peaks].map{|fn| File.basename(fn.strip, ".interval") }.reject(&:empty?).uniq
      peak_id = take_the_only( peak_bns )
      if row[:peak_count_MACS2_PE]
        type = 'paired_end'
      else
        type = 'single_end'
      end
    end

    self.new(
      **row,
      peak_id: peak_id, type: type, plate_id: plate_id,
    )
  end

  # GLI4.Plate_2_G12_S191.PEAKS991005
  def basename
    "#{tf}.#{plate_id}.#{peak_id}.chipseq"
  end

  def self.peak_id_from_basename(bn)
    bn.split('.')[2]
  end

  def peak_fn_for_peakcaller(peak_caller, source_folder)
    case type
    when 'control'
      raise "No peak file for control #{peak_id}"
    when 'single_end'
      "#{source_folder}/peaks-intervals-se_control/#{peak_caller}/#{peak_id}.interval"
    when 'paired_end'
      "#{source_folder}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end

  def normalized_id
    plate_id.sub(/_L\d+(\+L\d+)?$/, "").sub(/_\d_pf(\+\d_pf)?$/,"").sub(/_[ACGT]{6}$/, "").sub(/_S\d+$/, "")
  end
end
