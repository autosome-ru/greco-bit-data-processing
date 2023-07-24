require 'csv'
require 'json'
require 'set'
require 'fileutils'

def exp_qual_name(exp, rep)
  rep ? "#{exp}.Rep-#{rep}" : exp
end

raise 'Specify freeze file'  unless freeze_fn = ARGV[0]
raise 'Specify motif_infos.tsv file'  unless motif_infos_fn = ARGV[1]
raise 'Specify src folder'  unless src = ARGV[2]
raise 'Specify dest folder'  unless dest = ARGV[3]

experiments_in_freeze = File.readlines(freeze_fn).drop(1).map{|l| l.chomp.split("\t").last }.to_set

motif_lines = File.readlines(motif_infos_fn).map(&:chomp)
header = motif_lines.shift

motif_idx = header.split("\t").index('motif')
exp_idx = header.split("\t").index('experiment_id')
rep_idx = header.split("\t").index('replicate')

final_motif_lines = motif_lines.select{|l|
  row = l.chomp.split("\t")
  exp_fullname = exp_qual_name(row[exp_idx], row[rep_idx].then{|v| v.empty? ? nil : v })
  experiments_in_freeze.include?(exp_fullname)
}

puts(header)
final_motif_lines.each{|l|
  puts(l)
}

motifs_to_get = final_motif_lines.map{|l| l.chomp.split("\t")[motif_idx] }.to_set

FileUtils.mkdir_p(dest)

Dir.glob("#{src}/*").each{|fn|
  FileUtils.cp(fn, dest)  if motifs_to_get.include?( File.basename(fn) )
}
