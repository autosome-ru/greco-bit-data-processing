require_relative 'statistics'

ChipProbe = Struct.new(:id_spot, :row, :col, :control, :id_probe, :pbm_sequence, :linker_sequence, :signal, :background, :flag) do
  def self.from_string(str)
    id_spot, row, col, control, id_probe, pbm_sequence, linker_sequence, signal, background, flag = str.chomp.split("\t")
    
    case control
    when 'TRUE'; control = true
    when 'FALSE'; control = false
    else raise "Unknown `control` value #{control}"
    end

    case flag
    when '0'; flag = false
    when '1'; flag = true
    else raise "Unknown `flag` value #{flag}"
    end

    self.new(id_spot, Integer(row), Integer(col), control, id_probe,
      pbm_sequence, linker_sequence,
      Float(signal), Float(background),
      flag)
  end

  def self.each_in_file(filename, &block)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.open(filename){|f|
      f.readline # skip header
      f.each_line{|l|
        yield self.from_string(l)
      }
    }
  end

  def with_signal(new_signal)
    ChipProbe.new(id_spot, row, col, control, id_probe, pbm_sequence, linker_sequence, new_signal, background, flag)
  end

  def with_background(new_background)
    ChipProbe.new(id_spot, row, col, control, id_probe, pbm_sequence, linker_sequence, signal, new_background, flag)
  end

  def scaled(factor)
    with_signal(factor * signal).with_background(factor * background)
  end

  def background_subtracted
    with_signal(signal - background).with_background(0.0)
  end

  def background_normalized
    with_signal(Math.log2(signal / background)).with_background(nil)
  end

  def log10_scaled
    with_signal(Math.log10(signal)).with_background(Math.log10(background))
  end
end

class Chip
  attr_reader :probes, :info
  def initialize(probes, info)
    @probes = probes
    @info = info
  end

  def chip_type; info[:chip_type]; end
  def tf; info[:tf]; end
  def sample_id; info[:sample_id]; end
  def filename; info[:filename]; end
  def basename; info[:basename]; end
  
  def self.from_file(filename, &block)
    probes = ChipProbe.each_in_file(filename).to_a
    info = self.parse_filename(filename)
    self.new(probes, info)
  end

  # 'R_2018-10-24_13709_1M-HK_Standard_pTH13929.2_ZBED2.FL.txt'
  def self.parse_filename(filename)
    filename = File.absolute_path(filename)
    dirname = File.dirname(filename)
    extname = File.extname(filename)
    basename = File.basename(filename, extname)
    prefix, date, sample_id, chip_type, standard, pth, tf = basename.split("_")
    {sample_id: sample_id, chip_type: chip_type, tf: tf, date: date, basename: basename, extname: extname, dirname: dirname, filename: filename}
  end

  def mean_signal
    @_mean_signal ||= probes.map(&:signal).mean
  end

  def mean_background
    @_mean_background ||= probes.map(&:background).mean
  end

  def scaled(factor)
    Chip.new(probes.map{|probe| probe.scaled(factor) }, info)
  end

  def background_subtracted
    Chip.new(probes.map{|probe| probe.background_subtracted }, info)
  end

  def background_normalized
    Chip.new(probes.map{|probe| probe.background_normalized }, info)
  end

  def log10_scaled
    Chip.new(probes.map{|probe| probe.log10_scaled }, info)
  end
end

def quantile_normalized_chips(chips)
  probe_ids_variants = chips.map{|chip| chip.probes.map{|chip_probe| chip_probe.id_probe }.sort }
  raise 'Probe ids are different'  if probe_ids_variants.uniq.size != 1
  probe_ids = probe_ids_variants.first
  samples_sorted_probes = chips.map{|chip|
    chip.probes.map{|probe| [probe.id_probe, probe] }.to_h.values_at(*probe_ids)
  }

  qn_signals     = quantile_normalization(samples_sorted_probes.map{|chip_probes| chip_probes.map{|probe| probe.signal } })
  qn_backgrounds = quantile_normalization(samples_sorted_probes.map{|chip_probes| chip_probes.map{|probe| probe.background } })
  chips.zip(samples_sorted_probes, qn_signals, qn_backgrounds).map{|chip, chip_sorted_probes, chip_qn_signals, chip_qn_backgrounds|
    normalized_probes = chip_sorted_probes.zip(chip_qn_signals, chip_qn_backgrounds).map{|probe, qn_signal, qn_background|
      probe.with_signal(qn_signal).with_background(qn_background)
    }
    Chip.new(normalized_probes, chip.info)
  }
end
