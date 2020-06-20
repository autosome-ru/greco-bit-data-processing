weighted = ARGV.delete('--weighted')

nuc_idx = {'A' => 0, 'C' => 1, 'G' => 2, 'T' => 3}
matrix = []
ARGF.each_line.map(&:chomp).each_slice(2).map{|hdr,seq|
  weight = weighted ? Float(hdr[1..-1].strip) : 1
  seq.upcase!
  seq.each_char.each_with_index{|letter, pos|
    matrix[pos] ||= [0,0,0,0]
    matrix[pos][nuc_idx[letter]] += weight
  }
}

matrix.each{|row|
  puts row.join("\t")
}