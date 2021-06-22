rows = File.readlines('source_data_meta/shared/TFGenes.tsv').map{|l| l.chomp.split("\t", 12) }
rows[1..-1].each{|row|
  # `Present in ... sheet` columns
  (7..11).each{|col_idx|
    if (row[col_idx] == row[0]) || (row[col_idx] == 'true') || (row[col_idx] == 'yes')
      row[col_idx] = 'yes'
    elsif (row[col_idx] == '#N/A') || (row[col_idx] == 'false') || (row[col_idx] == 'no')
      row[col_idx] = 'no'
    else
      raise "Incorrect data in row #{row}, column #{col_idx + 1}: `#{row[col_idx]}`"
    end
  }
}
File.open('source_data_meta/shared/TFGenes.tsv', 'w') {|fw|
  rows.each{|row|
    fw.puts row.join("\t")
  }
}
