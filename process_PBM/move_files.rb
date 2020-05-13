require 'fileutils'
require_relative 'chip_probe'

FileUtils.mkdir_p 'factors'

chips = Dir.glob('data/RawData/*.txt').map{|fn|
  Chip.from_file(fn)
}

chips.each{|chip|
  FileUtils.mkdir_p "factors/#{chip.tf}"
  FileUtils.cp "pcms/#{chip.basename}.pcm", "factors/#{chip.tf}/"  if File.exist?("pcms/#{chip.basename}.pcm")
  FileUtils.cp "dpcms/#{chip.basename}.dpcm", "factors/#{chip.tf}/"  if File.exist?("dpcms/#{chip.basename}.dpcm")
  FileUtils.cp "logo/#{chip.basename}.png", "factors/#{chip.tf}/"
  FileUtils.cp "seq_zscore/#{chip.basename}.tsv", "factors/#{chip.tf}/#{chip.basename}.zscore.tsv"
  FileUtils.cp "top_seqs/#{chip.basename}.fa", "factors/#{chip.tf}/"
  FileUtils.cp "chipmunk_results/#{chip.basename}.chipmunk.txt", "factors/#{chip.tf}/"
  FileUtils.cp "chipmunk_logs/#{chip.basename}.chipmunk.log", "factors/#{chip.tf}/"
}
