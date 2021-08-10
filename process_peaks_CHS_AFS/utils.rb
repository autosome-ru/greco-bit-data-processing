require_relative '../shared/lib/utils'

def num_rows(filename, has_header: true)
  num_lines = File.readlines(filename).map(&:strip).reject(&:empty?).size
  has_header ? (num_lines - 1) : num_lines
rescue => e
  $stderr.puts "Original exception: #{e.full_message}"
  raise "Failed to count lines in `#{filename}`"
end

def get_bed_intervals(filename, has_header: true, drop_wrong: false)
  lines = File.readlines(filename)
  lines = lines.drop(1)  if has_header
  lines.map{|l|
    l.chomp.split("\t").first(3)
  }.reject{|r|
    drop_wrong && Integer(r[1]) < 0
  }
end

def store_table(filename, rows)
  File.open(filename, 'w'){|fw|
    rows.each{|l|
      fw.puts(l.join("\t"))
    }
  }
end
