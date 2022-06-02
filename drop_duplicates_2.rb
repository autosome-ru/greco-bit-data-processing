
all_files = Dir.glob('/mnt/space/hughes/**/*').select{|fn|
  File.file?(fn)
};nil

real_files = all_files.reject{|fn|
  File.symlink?(fn)
}.reject{|fn|
  ext = File.extname(fn)
  ['.pcm', '.ppm', '.txt', '.csv', '.list', '.tar'].include?(ext)
};nil

dup_files = real_files.group_by{|fn|
  File.basename(fn)
}.reject{|bn, fns|
  fns.size == 1
}.flat_map{|bn, fns|
  fns.group_by{|fn|
    md5 = `md5sum #{fn}`.split.first
    [bn, md5]
  }.to_a
}.select{|(bn,md5),fns|
  fns.size > 1
}; nil


dup_files.map{|(bn,md5), fns|
  fns
}.each{|fns|
  fns = fns.sort_by{|fn|
    abs_fn = File.absolute_path(fn)
    [abs_fn.length, abs_fn]
  }
  basic_fn = File.absolute_path(fns.first)

  fns.drop(1).each{|fn|
    abs_fn = File.absolute_path(fn)
    bn = abs_fn.sub('/mnt/space/', '')
    dst_fn = "/mnt/space/vorontsovie/backup/#{bn}"

    raise "#{bn} used twice"  if used_filenames.include?(bn)
    used_filenames << bn

    if File.symlink?(abs_fn)
      raise "File #{abs_fn} follows to #{File.readlink(abs_fn)} but should follow to #{basic_fn}"  if File.readlink(abs_fn) != basic_fn

      if File.exist?(dst_fn)
        $stderr.puts("File #{abs_fn} is already a symlink. Destination #{dst_fn} exists")
      else
        $stderr.puts("File #{abs_fn} is already a symlink. But follows to nowhere!!!")
      end
      next
    end

    if File.exist?(dst_fn)
      $stderr.puts("Destination file #{dst_fn} for #{fn} already exists")
      next
    end

    FileUtils.mkdir_p(File.dirname(dst_fn))
    cmd = "mv #{abs_fn} #{dst_fn} && ln -s #{basic_fn} #{abs_fn}"
    puts cmd
  }
}
