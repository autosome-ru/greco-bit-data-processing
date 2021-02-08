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

  File.open(output_filename, 'w') {|fw|
    sorted_probes = chip.probes.reject(&:flag).sort_by(&:signal).reverse
    sorted_probes = sorted_probes.first(take_top)  if take_top
    sorted_probes.each{|probe|
      linker_suffix = (linker_length == 0) ? '' : probe.linker_sequence[(-linker_length) .. (-1)]
      if output_format == :tsv
        info = [probe.id_probe, linker_suffix + probe.pbm_sequence, probe.signal]
        fw.puts(info.join("\t"))
      elsif output_format == :fasta
        fw.puts(">#{probe.id_probe} #{probe.signal}")
        fw.puts(linker_suffix + probe.pbm_sequence)
      else
        raise "Unknown output format `#{output_format}`"
      end
    }
  }
}
