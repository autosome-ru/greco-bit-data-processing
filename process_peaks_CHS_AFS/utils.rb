def take_the_only(vs)
  raise "Size of #{vs} should be 1 but was #{vs.size}" unless vs.size == 1
  vs[0]
end

def num_rows(filename, has_header: true)
  num_lines = File.readlines(filename).map(&:strip).reject(&:empty?).size
  has_header ? (num_lines - 1) : num_lines
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

def make_merged_intervals(filename, intervals)
  intervals_unsorted = Tempfile.new("intervals_unsorted.bed").tap(&:close)
  store_table(intervals_unsorted.path, intervals)
  system("cat #{intervals_unsorted.path} | sort -k1,1 -k2,2n | ./bedtools merge > #{filename}")
  intervals_unsorted.unlink
end
