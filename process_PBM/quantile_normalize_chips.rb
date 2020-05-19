#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require_relative 'chip_probe'

src_folder = nil
dst_folder = nil

normalization_mode = :log10_scaled

option_parser = OptionParser.new{|opts|
  opts.on('--source FOLDER') {|folder| src_folder = folder }
  opts.on('--destination FOLDER') {|folder| dst_folder = folder }
  opts.on('--log10') { normalization_mode = :log10_scaled }
  opts.on('--log10-bg') { normalization_mode = :log10_scaled_bg_normalized }
}
option_parser.parse!(ARGV)

raise "Specify source folder" unless src_folder
raise "Specify quantile-normalized chips destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

chips_by_type = Dir.glob(File.join(src_folder, '*.txt')).group_by{|fn|
  Chip.parse_filename(fn)[:chip_type]
}

chips_by_type.each{|chip_type, fns|
  chips = fns.map{|fn| Chip.from_file(fn) }
  normalized_chips = quantile_normalized_chips(chips.map(&normalization_mode))
  normalized_chips.each{|chip|  chip.store_to_file(File.join(dst_folder, "#{chip.basename}.txt")) }
}
