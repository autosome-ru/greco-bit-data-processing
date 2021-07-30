require 'fileutils'
folder = ARGV[0]
dst = ARGV[1]
mode = (ARGV[2] || :symlink).to_sym

folder = File.absolute_path(folder)

fns = Dir.glob("#{folder}/**/*").map{|fn|
  File.absolute_path(fn)
}.select{|fn| File.file?(fn) }

fns.each{|fn|
  bn = fn.sub(/^#{folder}/, "")
  dn = File.dirname(bn)
  FileUtils.mkdir_p("#{dst}/#{dn}")
  case mode
  when :symlink
    FileUtils.ln_s(fn, "#{dst}/#{bn}")
  when :copy
    FileUtils.cp(fn, "#{dst}/#{bn}")
  else
    raise "Unknown mode `#{mode}`"
  end
}
