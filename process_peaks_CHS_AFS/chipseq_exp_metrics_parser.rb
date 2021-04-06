ExperimentInfo = Struct.new(:experiment_id, :peak_id, :tf, :raw_files, :peaks, :type, :plate_id) do
  include ExperimentInfoExtension

  def self.from_string(str)
    row = str.chomp.split("\t")

    experiment_id = row[0]
    tf = row[1]
    raw_files = row[2]
    peaks = row[3].split(';')
    plate_ids = raw_files.split(';').map{|fn| File.basename(fn, '.fastq.gz') }.map{|bn| bn.sub(/_R[12](_001)?$/,'') }.uniq
    if plate_ids.size == 1
      plate_id = plate_ids[0]
    elsif plate_ids.size == 0
      raise
    else
      parts = plate_ids[0].split('_').zip( *plate_ids.drop(1).map{|s| s.split('_') } ).map{|parts| parts.uniq }
      prefix = parts.take_while{|part| part.size == 1 }.flatten.join('_') + '_'
      plate_id = prefix + plate_ids.map{|s| s[prefix.size..-1] }.join('+')
      # plate_id_parts = plate_ids.tap{|x| p x }.map{|s| s.match(/^(.+)_(L\d+)$/) }
      # plate_id = take_the_only(plate_id_parts.map(&:first).uniq) + '_' + plate_id_parts.map(&:last).uniq.join('+')
    end

    raise 'Inconsistent data'  if (row[13] == 'CONTROL') ^ (row[13] == 'CONTROL')

    if row[14] == 'CONTROL'
      peak_id = nil
      type = 'control'
    else
      peak_bns = peaks.map{|fn| File.basename(fn.strip,".interval") }.reject(&:empty?).uniq
      peak_id = take_the_only( peak_bns )
      if row[14] == 'NOT_PAIRED_END'
        type = 'single_end'
      else
        type = 'paired_end'
      end
    end

    self.new(experiment_id, peak_id, tf, raw_files, peaks, type, plate_id)
  end

  # GLI4.Plate_2_G12_S191.PEAKS991005
  def basename
    "#{tf}.#{plate_id}.#{peak_id}.chipseq"
  end

  def self.peak_id_from_basename(bn)
    bn.split('.')[2]
  end

  def peak_fn_for_peakcaller(peak_caller)
    case type
    when 'control'
      raise "No peak file for control #{peak_id}"
    when 'single_end'
      "#{SOURCE_FOLDER}/peaks-intervals-se_control/#{peak_caller}/#{peak_id}.interval"
    when 'paired_end'
      "#{SOURCE_FOLDER}/peaks-intervals/#{peak_caller}/#{peak_id}.interval"
    else
      raise "Unknown type `#{type}` for #{peak_id}"
    end
  end
end
