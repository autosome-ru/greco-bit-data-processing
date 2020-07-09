#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require_relative 'chip_probe'

src_folder = nil
dst_folder = nil

sort_chip = false

option_parser = OptionParser.new{|opts|
  opts.on('--source FOLDER') {|folder| src_folder = folder }
  opts.on('--destination FOLDER') {|folder| dst_folder = folder }
  opts.on('--sort-chip') { sort_chip = true }
}
option_parser.parse!(ARGV)

raise "Specify source folder" unless src_folder
raise "Specify zscore-converted chips destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

chips_by_type = Dir.glob(File.join(src_folder, '*.txt')).group_by{|fn|
  Chip.parse_filename(fn)[:chip_type]
}

chips_by_type.each{|chip_type, fns|
  chips = fns.map{|fn| Chip.from_file(fn) }
  zscored_chips = zscore_transformed_chips(chips)
  zscored_chips.each{|chip|
    chip = chip.sort  if sort_chip
    chip.store_to_file(File.join(dst_folder, "#{chip.basename}.txt"))
  }
}
