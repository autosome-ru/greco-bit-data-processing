#!/usr/bin/env ruby

require 'fileutils'
require_relative 'chip_probe'
require_relative 'statistics'
require_relative 'quantile_normalization'
require 'optparse'

src_folder = nil
seqs_dst_folder = nil
norm_chips_dst_folder = nil
zscored_chips_dst_folder = nil

normalization_mode = :log10_scaled
linker_length = 0 # Take `linker_length` nucleotides from linker sequence
option_parser = OptionParser.new{|opts|
  opts.on('--source FOLDER') {|folder| src_folder = folder }
  opts.on('--sequences-destination FOLDER') {|folder| seqs_dst_folder = folder }
  opts.on('--norm-chips-destination FOLDER') {|folder| norm_chips_dst_folder = folder }
  opts.on('--zscored-chips-destination FOLDER') {|folder| zscored_chips_dst_folder = folder }
  opts.on('--log10') { normalization_mode = :log10_scaled }
  opts.on('--log10-bg') { normalization_mode = :log10_scaled_bg_normalized }
  opts.on('--linker-length LENGTH') {|val| linker_length = Integer(val) }
}

raise "Specify source folder" unless src_folder
raise "Specify sequences destination folder" unless seqs_dst_folder
raise "Specify quantile-normalized chips destination folder" unless norm_chips_dst_folder
raise "Specify zscore-converted chips destination folder" unless zscored_chips_dst_folder

FileUtils.mkdir_p(seqs_dst_folder)
FileUtils.mkdir_p(norm_chips_dst_folder)
FileUtils.mkdir_p(zscored_chips_dst_folder)

chips_by_type = Dir.glob(File.join(src_folder, '*.txt')).group_by{|fn|
  Chip.parse_filename(fn)[:chip_type]
}

chips_by_type.each{|chip_type, fns|
  chips = fns.map{|fn| Chip.from_file(fn) }
  
  normed_chips = quantile_normalized_chips(chips.map(&normalization_mode))
  normed_chips.each{|chip|  chip.store_to_file(File.join(norm_chips_dst_folder, "#{chip.basename}.txt")) }

  zscored_chips = convert_to_zscores(normed_chips)
  zscored_chips.each{|chip|  chip.store_to_file(File.join(zscored_chips_dst_folder, "#{chip.basename}.txt")) }

  zscored_chips.each{|chip|
    File.open(File.join(seqs_dst_folder, "#{chip.basename}.tsv"), 'w') {|fw|
      chip.probes.sort_by(&:signal).reverse.each{|probe|
        linker_suffix = (linker_length == 0) ? '' : probe.linker_sequence[(-linker_length) .. (-1)]
        info = [probe.id_probe, linker_suffix + probe.pbm_sequence, probe.signal]
        fw.puts(info.join("\t"))
      }
    }
  }
}; nil
