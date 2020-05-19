require 'fileutils'
require_relative 'chip_probe'

FileUtils.mkdir_p 'results/factors'

chips = Dir.glob('data/RawData/*.txt').map{|fn|
  Chip.from_file(fn)
}

chips.each{|chip|
  FileUtils.mkdir_p "results/factors/#{chip.tf}"
  FileUtils.cp "results/pcms/#{chip.basename}.pcm", "results/factors/#{chip.tf}/"  if File.exist?("results/pcms/#{chip.basename}.pcm")
  FileUtils.cp "results/dpcms/#{chip.basename}.dpcm", "results/factors/#{chip.tf}/"  if File.exist?("results/dpcms/#{chip.basename}.dpcm")
  FileUtils.cp "results/words/#{chip.basename}.fa", "results/factors/#{chip.tf}/words.#{chip.basename}.fa"
  FileUtils.cp "results/dilogo/#{chip.basename}.png", "results/factors/#{chip.tf}/di.#{chip.basename}.png"
  FileUtils.cp "results/logo/#{chip.basename}.png", "results/factors/#{chip.tf}/mono.#{chip.basename}.png"
  FileUtils.cp "results/seq_zscore/#{chip.basename}.tsv", "results/factors/#{chip.tf}/#{chip.basename}.zscore.tsv"
  FileUtils.cp "results/top_seqs/#{chip.basename}.fa", "results/factors/#{chip.tf}/"
  FileUtils.cp "results/chipmunk_results/#{chip.basename}.txt", "results/factors/#{chip.tf}/#{chip.basename}.chipmunk.txt"
  FileUtils.cp "results/chipmunk_logs/#{chip.basename}.log", "results/factors/#{chip.tf}/#{chip.basename}.chipmunk.log"
}
