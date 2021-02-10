require 'fileutils'
folder = ARGV[0]
dst = ARGV[1]

fns = Dir.glob("#{folder}/**/*").map{|fn|
  File.absolute_path(fn)
}.select{|fn| File.file?(fn) }

fns.each{|fn|
  bn = fn.sub(/^#{folder}/, "")
  dn = File.dirname(bn)
  FileUtils.mkdir_p("#{dst}/#{dn}")
  FileUtils.ln_s(fn, "#{dst}/#{bn}")
}
