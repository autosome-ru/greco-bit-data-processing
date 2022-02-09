counter = {}
File.open('source_data_meta/SMS/unpublished/SMS_fix_2022-02-09.tsv', 'w'){|fw|
  File.readlines('source_data_meta/SMS/unpublished/SMS.tsv').map(&:chomp).map{|l|
    l.split("\t")
  }.each{|row|
    exp_id = row[0].split('-').first(2).join('-')
    if counter.has_key?(exp_id)
      counter[exp_id] += 1
      corrected_exp_id = "#{exp_id}-#{counter[exp_id]}"
    else
      counter[exp_id] = 1
      corrected_exp_id = row[0]
    end
    fw.puts( [corrected_exp_id, *row.drop(1), *Array.new(8 - row.length)].join("\t") )
  }
}
