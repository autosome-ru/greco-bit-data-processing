#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'

src_folder = nil
dst_folder = nil
tf_mapping_filename = nil

option_parser = OptionParser.new{|opts|
  opts.on('--source FOLDER') {|folder| src_folder = folder }
  opts.on('--destination FOLDER') {|folder| dst_folder = folder }
  opts.on('--tf-mapping FILE') {|filename| tf_mapping_filename = filename}
}
option_parser.parse!(ARGV)

raise "Specify source folder" unless src_folder
raise "Specify destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

tf_mapping = {}
if tf_mapping_filename
  tf_mapping = File.readlines(tf_mapping_filename).map{|l| l.chomp.split("\t") }.to_h
end
Dir.glob("#{src_folder}/*.txt").each{|fn|
  bn = File.basename(fn, '.txt')
  tf = bn.split('_').last.split('.').first
  raise  unless bn.match?(/^([^_]+)_(R_\d{4}-\d{2}-\d{2}_\1_(1M-ME|1M-HK)_.+)$/)
  shortened_bn = bn.split('_', 2)[1]
  tf = tf_mapping.fetch(tf, tf)
  FileUtils.cp(fn, "#{dst_folder}/#{tf}.#{shortened_bn}.pbm.txt")
}
