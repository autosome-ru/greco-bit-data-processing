require 'fileutils'

gene_mapping = {
  'ZNF788' => 'ZNF788P',
  'ZUFSP' => 'ZUP1',
  'TPRX' => 'TPRX1',
  'OKT4' => 'POU5F1',
  'cJUN' => 'JUN',
  'ZFAT1' => 'ZFAT',
  'C11orf95' => 'ZFTA',
}

fix_tf_info = ->(tf_info) {
  tf, construction_type = tf_info.split('.')
  tf = gene_mapping.fetch(tf, tf)
  "#{tf}.#{construction_type}"
}

resulting_folder = '/home_local/vorontsovie/greco-data/release_7a.2021-10-14/full'
source_folder = '/home_local/vorontsovie/greco-data/release_7.2021-08-14/full'

FileUtils.mkdir_p(resulting_folder)
Dir.glob("#{source_folder}/*/*").each{|dn|
  dst_dn = dn.sub(source_folder, resulting_folder)
  FileUtils.mkdir_p(dst_dn)  if File.directory?(dn)
}

Dir.glob("#{source_folder}/*/*/*").each{|fn|
  dn = File.dirname(fn).sub(source_folder, resulting_folder)
  bn = File.basename(fn)
  tf_info, rest_info = bn.split('@', 2)
  bn = "#{fix_tf_info.call(tf_info)}@#{rest_info}"
  dst_fn = "#{dn}/#{bn}"
  raise "Unexpected directory #{fn}" if File.directory?(fn)
  if File.symlink?(fn)
    # puts(File.readlink(fn), "-->", dst_fn)
    File.link(File.readlink(fn), dst_fn)
  elsif File.file?(fn)
    # puts(fn, "-->", dst_fn)
    File.link(fn, dst_fn)
  else
    raise "Unexpected non-regular file #{fn}"
  end
}
