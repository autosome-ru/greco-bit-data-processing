require 'optparse'
require_relative 'chip_probe'

linker_length = nil
option_parser = OptionParser.new{|opts|
  opts.on('--linker-length LENGTH') {|value| linker_length = Integer(value) }
}

option_parser.parse!(ARGV)

ChipProbe.each_in_stream($stdin, has_header: true).lazy.reject(&:flag).each{|probe|
  if linker_length
    seq = probe.linker_sequence[-linker_length..-1] + probe.pbm_sequence
  else
    seq = probe.pbm_sequence
  end

  info = [probe.signal, seq]
  puts info.join("\t")
}
