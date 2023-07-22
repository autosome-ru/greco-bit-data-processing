require 'json'
used_ids = File.open('metadata_release_8d.patch1.json').each_line.map{|l| JSON.parse(l.chomp)['dataset_id'] }
missing = File.open('metadata_release_7b.json').each_line.select{|l|
  ds_id = JSON.parse(l.chomp)['dataset_id']
  !used_ids.include?(ds_id)
}
File.open('metadata_release_8d.patch2.json', 'w'){|fw|
  File.open('metadata_release_8d.patch1.json').each_line{|l| fw.puts l }
  missing.each{|l| fw.puts(l) }
}
