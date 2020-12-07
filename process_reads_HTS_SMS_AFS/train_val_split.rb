require_relative 'fastq'

# def train_val_split(input_filename, train_filename, test_filename, &criteria)
#   reads = FastqRecord.each_in_file(input_filename).to_a
#   criteria = ->(read, idx){ idx % 3 < 2 }  unless block_given?
#   train_reads = reads.each_with_index.select(&criteria)
#   validation_reads  = reads.each_with_index.reject(&criteria)
#   FastqRecord.store_to_file(train_filename, train_reads)
#   FastqRecord.store_to_file(test_filename, validation_reads)
# end

def train_val_split(input_filename, train_filename, test_filename, &criteria)
  open_fastq_write(train_filename){|train_fw|
    open_fastq_write(test_filename){|test_fw|
      open_fastq_read(input_filename).each_line.each_slice(4).each_with_index{|slice, idx|
        output_stream = (idx % 3 < 2) ? train_fw : test_fw
        slice.each{|line| output_stream.puts(line) }
      }
    }
  }
end
