BN_PATTERN = /^(?<tf>[^.@]+\.[^.@]+)@(?<exp_type>HTS\.IVT|HTS\.Lys|AFS\.IVT|AFS\.Lys|PBM\.ME|PBM\.HK|SMS|CHS)@(?<dataset>[-+a-z]+)@(?<tool>[^@.]+\.[^@.]+)@(?<motif_subname>[^@.]+)$/
PPM_TOLERANCE = 0.05
filelist = $stdin.readlines.map(&:chomp)
filelist.select{|fn|
  File.file?(fn)
}.each{|fn|
  bn = File.basename(fn)
  ext = File.extname(bn)
  bn_wo_ext = File.basename(bn, ext)
  report = []
  content = File.readlines(fn).map(&:chomp)
  header = content.first
  report << "Filename has incorrect extension `#{ext}`"  unless ['.pcm', '.ppm', '.pwm'].include?(ext)
  report << "Filename doesn't match pattern tf.construct@{PBM.HK,PBM.ME,CHS,SMS,HTS.IVT,HTS.Lys,AFS.Lys,AFS.IVT}@dataset_id@team.tool@motif_name_wo_dots"  unless bn_wo_ext.match(BN_PATTERN)
  report << "No header"  unless header.start_with?('>')
  # report << "Header `#{header}` doesn't follow pattern >motif_name[ optional infos]"  unless (header == ">#{bn_wo_ext}") || header.start_with?(">#{bn_wo_ext} ") || (header == "> #{bn_wo_ext}") || header.start_with?("> #{bn_wo_ext} ")
  begin
    matrix_rows = content.drop(1).map{|l| l.split("\t") }
    report << "Format motifs in non-scientific format"  unless matrix_rows.all?{|r| r.match?(/^[-+]?\d+(\.\d+)$/) }
    matrix = matrix_rows.map{|r| r.map{|x| Float(x) } }
    report << "Each line should have 4-columns"  unless matrix.all?{|r| r.size == 4 }
    report << "Not all lines of probabiities matrix sum to 1.0"  if ext == '.ppm' && !matrix.all?{|r| (r.sum - 1.0).abs < PPM_TOLERANCE }
  rescue
    report << "Failed to parse matrix"
  end
  if report.empty?
    puts "OK #{fn}"
  else
    puts '---------------------'
    puts "ERROR #{fn}"
    puts report.join("\n")
  end
}
