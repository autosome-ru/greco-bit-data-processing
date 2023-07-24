require 'csv'
require 'json'
require 'set'
require 'fileutils'

def exp_qual_name(exp, rep)
  rep ? "#{exp}.Rep-#{rep}" : exp
end

raise 'Specify freeze file'  unless freeze_fn = ARGV[0]
raise 'Specify dest folder'  unless dest = ARGV[1]

experiments_in_freeze = File.readlines(freeze_fn).drop(1).map{|l| l.chomp.split("\t").last }.to_set

dataset_files = [
  {src: '/home_local/vorontsovie/greco-data/release_8d.2022-07-31/full/', prefix: nil},
  {src: '/home_local/vorontsovie/greco-data/release_7b.2022-02-21/full/PBM.SDQN/Train_intensities', prefix: 'PBM.SDQN/Train_intensities'},
  {src: '/home_local/vorontsovie/greco-data/release_7b.2022-02-21/full/PBM.SDQN/Train_sequences', prefix: 'PBM.SDQN/Train_sequences'},
].flat_map{|src_info|
  src = src_info[:src]
  Dir.glob("#{src}/**/*").map{|fn|
    bn = File.basename(fn)
    dn = File.absolute_path(File.dirname(fn))
    rel_dn = [src_info[:prefix], dn.sub(File.absolute_path(src), '')].compact.join('/')
    [fn, bn, rel_dn]
  }
}.select{|fn, bn, rel_dn|
  File.file?(fn) && bn.match?(/^(.+)@(.+)@(.+)@(.+)$/)
}

files_to_copy = dataset_files.map{|fn, bn, rel_dn|
  exp = bn.split('@')[2].split('.')[0]
  rep = bn.split('@')[2].split('.')[1]
  rep = nil  unless rep && rep.start_with?('Rep-')
  exp = [exp, rep].compact.join('.')
  [fn, bn, rel_dn, exp]
}.select{|fn, bn, rel_dn, exp|
  experiments_in_freeze.include?(exp)
}

files_to_copy.map{|fn, bn, rel_dn, exp| rel_dn }.uniq.each{|rel_dn| FileUtils.mkdir_p("#{dest}/#{rel_dn}") }

files_to_copy.each{|fn, bn, rel_dn, exp|
  FileUtils.ln_s(fn, "#{dest}/#{rel_dn}/#{bn}")
}
