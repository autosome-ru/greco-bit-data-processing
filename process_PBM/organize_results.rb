require 'optparse'
require 'fileutils'
require_relative 'chip_probe'

chips_src_folder = nil
results_src_folder = nil
dst_folder = nil
option_parser = OptionParser.new{|opts|
  opts.on('--chips-source FOLDER'){|folder| chips_src_folder = folder }
  opts.on('--results-source FOLDER'){|folder| results_src_folder = folder }
  opts.on('--destination FOLDER'){|folder| dst_folder = folder }
}
option_parser.parse!(ARGV)

raise "Specify chips source folder" unless chips_src_folder
raise "Specify results source folder" unless results_src_folder
raise "Specify organized results destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

chip_infos = Dir.glob(File.join(chips_src_folder, '*.txt')).each{|fn|
  info = Chip.parse_filename(fn)
  tf = info[:tf]
  bn = info[:basename]
  FileUtils.mkdir_p(File.join(dst_folder, tf))

  [
    {src: File.join(chips_src_folder, "#{bn}.txt"), dst: "chip.#{bn}.txt"},
    {src: File.join(results_src_folder, "normalized_chips/#{bn}.txt"), dst: "qn_chip.#{bn}.txt"},
    {src: File.join(results_src_folder, "zscored_chips/#{bn}.txt"), dst: "zscored_chip.#{bn}.txt"},
    {src: File.join(results_src_folder, "pcms/#{bn}.pcm"), dst: "pcm.#{bn}.pcm"},
    {src: File.join(results_src_folder, "dpcms/#{bn}.dpcm"), dst: "dpcm.#{bn}.dpcm"},
    {src: File.join(results_src_folder, "words/#{bn}.fa"), dst: "words.#{bn}.fa"},
    {src: File.join(results_src_folder, "dilogo/#{bn}.png"), dst: "dilogo.#{bn}.png"},
    {src: File.join(results_src_folder, "logo/#{bn}.png"), dst: "logo.#{bn}.png"},
    {src: File.join(results_src_folder, "zscored_seqs/#{bn}.tsv"), dst: "zscored_seqs.#{bn}.tsv"},
    {src: File.join(results_src_folder, "top_seqs_fasta/#{bn}.fa"), dst: "top_seqs.#{bn}.fa"},
    {src: File.join(results_src_folder, "chipmunk_results/#{bn}.txt"), dst: "chipmunk.#{bn}.txt"},
    {src: File.join(results_src_folder, "chipmunk_logs/#{bn}.log"), dst: "chipmunk.#{bn}.log"},
  ].each{|params|
    FileUtils.cp(params[:src], File.join(dst_folder, tf, params[:dst]))  if File.exist?(params[:src])
  }
}
