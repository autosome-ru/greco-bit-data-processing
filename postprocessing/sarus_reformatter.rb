filter_by_tf = ARGV.delete('--filter-by-tf')
raise 'Specify motif name'  unless motif = ARGV[0]

motif_tf = motif.split(".")[0]

infos = $stdin.each_line.each_slice(2).map{|hdr,scores|
  tf, exp_id, type = hdr.chomp[1..-1].split(":")
  logpval, pos, strand = scores.chomp.split("\t")
  [tf, exp_id, type, logpval, pos, strand]
}

if filter_by_tf
  infos = infos.select{|tf, *_rest|
    motif_tf == tf
  }
end

infos.each{|info|
  info = [motif, *info]
  puts info.join("\t")
}
