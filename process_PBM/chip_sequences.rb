#!/usr/bin/env ruby

require 'fileutils'
require_relative 'chip_probe'
require 'optparse'

src_folder = nil
dst_folder = nil

linker_length = 0 # Take `linker_length` nucleotides from linker sequence
output_format = :tsv
take_top = nil
option_parser = OptionParser.new{|opts|
  opts.on('--source FOLDER') {|folder| src_folder = folder }
  opts.on('--destination FOLDER') {|folder| dst_folder = folder }
  opts.on('--linker-length LENGTH') {|val| linker_length = Integer(val) }
  opts.on('--fasta'){ output_format = :fasta }
  opts.on('--take-top NUMBER'){|val| take_top = Integer(val) }
}
option_parser.parse!(ARGV)

raise "Specify source folder" unless src_folder
raise "Specify sequences destination folder" unless dst_folder

FileUtils.mkdir_p(dst_folder)

Dir.glob(File.join(src_folder, '*')).each{|fn|
  chip = Chip.from_file(fn)

  if output_format == :tsv
    output_filename = File.join(dst_folder, "#{chip.basename}.tsv")
  elsif output_format == :fasta
    output_filename = File.join(dst_folder, "#{chip.basename}.fa")
  else
    raise "Unknown output format `#{output_format}`"
  end

  sorted_probes = chip.probes.reject(&:flag).sort_by(&:signal).reverse
  sorted_probes = sorted_probes.first(take_top)  if take_top
  File.open(output_filename, 'w') {|fw|
    sorted_probes.each{|probe|
      linker_suffix = probe.linker_suffix(linker_length)
      seq = linker_suffix + probe.pbm_sequence
      if output_format == :tsv
        info = [probe.id_probe, seq, probe.signal]
        fw.puts(info.join("\t"))
      elsif output_format == :fasta
        fw.puts(">#{probe.id_probe} #{probe.signal}")
        fw.puts(seq)
      else
        raise "Unknown output format `#{output_format}`"
      end
    }
  }
}
