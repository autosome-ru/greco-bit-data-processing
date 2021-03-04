#!/usr/bin/env ruby

require_relative 'chip_probe'
require 'optparse'

linker_length = 0 # Take `linker_length` nucleotides from linker sequence
output_format = :tsv
take_top = nil
option_parser = OptionParser.new{|opts|
  opts.on('--linker-length LENGTH') {|val| linker_length = Integer(val) }
  opts.on('--fasta'){ output_format = :fasta }
  opts.on('--take-top NUMBER'){|val| take_top = Integer(val) }
}
option_parser.parse!(ARGV)

raise "Specify source chip" unless src = ARGV[0]

chip = Chip.from_file(src)

sorted_probes = chip.probes.reject(&:flag).sort_by(&:signal).reverse
sorted_probes = sorted_probes.first(take_top)  if take_top
sorted_probes.each{|probe|
  linker_suffix = probe.linker_suffix(linker_length)
  seq = linker_suffix + probe.pbm_sequence
  if output_format == :tsv
    info = [probe.id_probe, seq, probe.signal]
    puts(info.join("\t"))
  elsif output_format == :fasta
    puts(">#{probe.id_probe} #{probe.signal}")
    puts(seq)
  else
    raise "Unknown output format `#{output_format}`"
  end
}
