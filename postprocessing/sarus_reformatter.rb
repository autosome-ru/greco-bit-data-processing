raise 'Specify motif name'  unless motif = ARGV[0]

motif_tf = motif.split(".")[0]

$stdin.each_line.each_slice(2).map{|hdr,scores|
  tf, exp_id, type = hdr.chomp[1..-1].split(":")
  logpval, pos, strand = scores.chomp.split("\t")
  [tf, exp_id, type, logpval, pos, strand]
}.select{|tf, *_rest|
  motif_tf == tf
}.each{|info|
  info = [motif, *info]
  puts info.join("\t")
}
