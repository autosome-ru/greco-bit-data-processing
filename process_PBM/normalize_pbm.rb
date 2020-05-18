#!/usr/bin/env ruby

require 'fileutils'
require_relative 'chip_probe'
require_relative 'statistics'
require_relative 'quantile_normalization'
require 'optparse'

normalization_mode = :log10_scaled
linker_length = 0 # Take `linker_length` nucleotides from linker sequence
option_parser = OptionParser.new{|opts|
  opts.on('--log10') { normalization_mode = :log10_scaled }
  opts.on('--log10-bg') { normalization_mode = :log10_scaled_bg_normalized }
  opts.on('--linker-length LENGTH') {|val| linker_length = Integer(val) }
}

FileUtils.mkdir_p('results/seq_zscore')
FileUtils.mkdir_p('results/normalized_chips')
FileUtils.mkdir_p('results/zscored_chips')

chips_by_type = Dir.glob('data/RawData/*.txt').group_by{|fn|
  Chip.parse_filename(fn)[:chip_type]
}

chips_by_type.each{|chip_type, fns|
  chips = fns.map{|fn| Chip.from_file(fn) }
  
  normed_chips = quantile_normalized_chips(chips.map(&normalization_mode))
  normed_chips.each{|chip|  chip.store_to_file("results/normalized_chips/#{chip.basename}.txt") }

  zscored_chips = convert_to_zscores(normed_chips)
  zscored_chips.each{|chip|  chip.store_to_file("results/zscored_chips/#{chip.basename}.txt") }

  zscored_chips.each{|chip|
    File.open("results/seq_zscore/#{chip.basename}.tsv", 'w') {|fw|
      chip.probes.sort_by(&:signal).reverse.each{|probe|
        linker_suffix = (linker_length == 0) ? '' : probe.linker_sequence[(-linker_length) .. (-1)]
        info = [probe.id_probe, linker_suffix + probe.pbm_sequence, probe.signal]
        fw.puts(info.join("\t"))
      }
    }
  }
}; nil
