require 'optparse'

linker_length = nil
option_parser = OptionParser.new{|opts|
  opts.on('--linker-length LENGTH') {|value| linker_length = Integer(value) }
}

option_parser.parse!(ARGV)

$stdin.each_line.lazy.drop(1).map{|l|
  l.chomp.split("\t")
}.reject{|row|
  flag = row[9]
  flag == "1"
}.each{|row|
  probe_seq = row[5]
  linker_seq = row[6]
  signal = row[7]
  if linker_length
    seq = linker_seq[-linker_length..-1] + probe_seq
  else
    seq = probe_seq
  end

  puts [signal, seq].join("\t")
}
