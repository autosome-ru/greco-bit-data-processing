require_relative '../shared/lib/utils'
require_relative 'statistics'
require_relative 'quantile_normalization'

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
      Float(signal), (background.empty? ? nil : Float(background)),
      flag)
  end

  def to_s
    [id_spot, row, col, control ? 'TRUE' : 'FALSE', id_probe, pbm_sequence, linker_sequence, signal, background, flag ? '1' : '0'].join("\t")
  end

  def self.each_in_stream(stream, has_header: true, &block)
    return enum_for(:each_in_stream, stream)  unless block_given?
    stream.readline   if has_header  # skip header
    stream.each_line{|l|
      yield self.from_string(l)
    }
  end

  def self.each_in_file(filename, &block)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.open(filename){|f|
      self.each_in_stream(f, has_header: true, &block)
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

  def log10_scaled_bg_normalized
    with_signal(Math.log10(signal / background)).with_background(0)
  end

  def linker_suffix(linker_length)
    (linker_length == 0) ? '' : probe.linker_sequence[(-linker_length) .. (-1)]
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

  def sort
    Chip.new(probes.sort_by(&:signal).reverse, info)
  end

  def self.from_file(filename, &block)
    probes = ChipProbe.each_in_file(filename).to_a
    info = self.parse_filename(filename)
    self.new(probes, info)
  end

  def store_to_file(filename)
    File.open(filename, 'w'){|fw|
      header = ['id_spot', 'row', 'col', 'control', 'id_probe', 'pbm_sequence', 'linker_sequence', 'mean_signal_intensity', 'mean_background_intensity', 'flag']
      fw.puts '#' + header.join("\t")

      @probes.each{|probe|
        fw.puts probe
      }
    }
  end

  # '13733_R_2018-10-29_13733_1M-ME_Standard_pTH14320.1_PURG.FL.txt'
  def self.parse_filename(filename)
    filename = File.absolute_path(filename)
    dirname = File.dirname(filename)
    extname = File.extname(filename)
    basename = File.basename(filename, extname)
    _sample_id_dup, _, date, sample_id, chip_type, standard, pth, tf = basename.split("_")
    {sample_id: sample_id, chip_type: chip_type, tf: tf, date: date, basename: basename, extname: extname, dirname: dirname, filename: filename}
  end

  def linker_sequence
    linker_sequences = probes.map(&:linker_sequence).uniq
    raise "Different linkers for chip" unless linker_sequences.size == 1
    linker_sequences.first
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

  def log10_scaled_bg_normalized
    Chip.new(probes.map{|probe| probe.log10_scaled_bg_normalized }, info)
  end

  def probe_by_id
    @_probe_by_id ||= probes.map{|probe| [probe.id_probe, probe] }.to_h
  end
end

def quantile_normalized_chips(chips)
  ordered_probe_ids = chips.map{|chip| chip.probes.map{|chip_probe| chip_probe.id_probe }.sort }.uniq.take_the_only

  # [[chip_1 probes ordered], [chip_2 probes in the same order], ...]
  chips_ordered_probes = chips.map{|chip|
    ordered_probe_ids.map{|probe_id| chip.probe_by_id[probe_id] }
  }
  chips_ordered_signals = chips_ordered_probes.map{|chip_probes| chip_probes.map(&:signal) }

  chips_ordered_qn_signals = quantile_normalization(chips_ordered_signals)
  chips.zip(chips_ordered_probes, chips_ordered_qn_signals).map{|chip, chip_ordered_probes, chip_ordered_qn_signals|
    normalized_probes = chip_ordered_probes.zip(chip_ordered_qn_signals).map{|probe, qn_signal|
      probe.with_signal(qn_signal)
    }
    Chip.new(normalized_probes, chip.info)
  }
end

def zscore_transformed_chips(chips)
  probe_values = Hash.new{|h,k| h[k] = [] }
  chips.each{|chip|
    chip.probes
        .reject(&:flag)
        .each{|probe|
          probe_values[probe.id_probe] << probe.signal
        }
  }
  probe_means = probe_values.map{|id, vs| [id, vs.mean] }.to_h
  probe_stdevs = probe_values.map{|id, vs| [id, vs.stddev] }.to_h

  chips.map{|chip|
    zscored_probes = chip.probes.map{|probe|
      zscore_val = zscore(probe.signal, probe_means[probe.id_probe], probe_stdevs[probe.id_probe])
      probe.with_signal(zscore_val).with_background(nil)
    }
    Chip.new(zscored_probes, chip.info)
  }
end
