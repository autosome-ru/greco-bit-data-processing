#!/usr/bin/env ruby

require 'fileutils'
require_relative 'chip_probe'
require 'optparse'

src_folder = nil
dst_folder = nil

linker_length = 0 # Take `linker_length` nucleotides from linker sequence
option_parser = OptionParser.new{|opts|
  opts.on('--source FOLDER') {|folder| src_folder = folder }
  opts.on('--destination FOLDER') {|folder| dst_folder = folder }
  opts.on('--linker-length LENGTH') {|val| linker_length = Integer(val) }
}
option_parser.parse!(ARGV)

raise "Specify source folder" unless src_folder
raise "Specify sequences destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

Dir.glob(File.join(src_folder, '*.txt')).each{|fn|
  chip = Chip.from_file(fn)

  File.open(File.join(dst_folder, "#{chip.basename}.tsv"), 'w') {|fw|
    chip.probes.reject(&:flag).sort_by(&:signal).reverse.each{|probe|
      linker_suffix = (linker_length == 0) ? '' : probe.linker_sequence[(-linker_length) .. (-1)]
      info = [probe.id_probe, linker_suffix + probe.pbm_sequence, probe.signal]
      fw.puts(info.join("\t"))
    }
  }
}
