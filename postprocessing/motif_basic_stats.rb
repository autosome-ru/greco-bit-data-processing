def information_content(pos)
  total = pos.sum
  freqs = pos.map{|v| Float(v) / total }
  2.0 + freqs.map{|p| (p == 0) ? 0 : p * Math.log2(p)}.sum
end

def total_ic(matrix)
  matrix.map{|pos| information_content(pos) }.sum
end

def gc_content(matrix)
  matrix.map{|pos| pos[1] + pos[2] }.sum.to_f / matrix.map(&:sum).sum
end


motifs_folder = ARGV[0]

header = ['motif', 'length', 'GC-content', 'total-IC', 'IC-per-position']
puts(header.join("\t"))

[
  *Dir.glob("#{motifs_folder}/*.pcm"),
  *Dir.glob("#{motifs_folder}/*.pfm"),
].sort.each{|fn|
  matrix = File.readlines(fn).reject{|l| l.start_with?('>') }.map{|l| l.chomp.split("\t").map{|v| Float(v) } }
  name = File.basename(fn, File.extname(fn))
  infos = [name, matrix.length, gc_content(matrix), total_ic(matrix), total_ic(matrix) / matrix.length]
  puts(infos.join("\t"))
}
