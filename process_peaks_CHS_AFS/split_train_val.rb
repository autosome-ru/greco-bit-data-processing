require 'set'
require 'fileutils'

def read_table(filename)
  header, rows = nil, nil
  File.open(filename) {|f|
    header = f.readline.chomp.split("\t")
    rows = f.readlines.map{|l| l.chomp.split("\t") }
  }
  [header, rows]
end

def store_table(filename, header, rows)
  File.open(filename, 'w'){|fw|
    fw.puts(header.join("\t"))
    rows.each{|row|
      fw.puts(row.join("\t"))
    }
  }
end

TRAIN_CHR = (1..21).step(2).to_set
VALIDATION_CHR = (2..22).step(2).to_set

peaks_fn, train_fn, validation_fn = ARGV.first(3)
FileUtils.mkdir_p(File.dirname(train_fn))
FileUtils.mkdir_p(File.dirname(validation_fn))

header, peaks = read_table(peaks_fn)

train_peaks = peaks.select{|peak_row| chr = peak_row[0]; TRAIN_CHR.include?(chr) }
validation_peaks = peaks.select{|peak_row| chr = peak_row[0]; VALIDATION_CHR.include?(chr) }
store_table(train_fn, header, train_peaks)
store_table(validation_fn, header, validation_peaks)
