ARGF.each_line.each_slice(2){|hdr, seq|
  hdr = hdr[1..-1]
  summit, pos = hdr.split('::')
  start = pos.split(':')[1].split('-')[0]
  relative_summit = Integer(summit) - Integer(start)
  puts "> #{relative_summit}"
  puts seq
}
