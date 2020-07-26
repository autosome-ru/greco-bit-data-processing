require 'parallel'
require 'fileutils'
require_relative 'fastq'

def num_reads_in_fastq(filename)
  open_fastq_read(filename){|f|
    f.each_line.count / 4
  }
end

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

# AHCTF1_GG40NCGTAGT_IVT_BatchYWCB_Cycle3_R1.fastq.gz
# SNAI1_AC40NGCTGCT_Lysate_BatchAATA_Cycle2_R1.fastq.gz
# SNAI1_AffSeq_IVT_BatchAATBA_Cycle1_R1.fastq.gz
# GLI4_AffSeq_Lysate_BatchAATA_Cycle1_R2.fastq.gz
def parse_filename(filename)
  basename = File.basename(File.basename(filename, '.gz'), '.fastq')
  tf, adapter, type, batch, cycle, read = basename.split('_')
  {tf: tf, adapter: adapter, type: type, batch: batch, cycle: cycle, read: read, filename: filename, basename: basename}
end

['IVT', 'Lysate'].each{|experiment_type|
  results_folder = "results_#{experiment_type}"
  FileUtils.mkdir_p "#{results_folder}/train_reads"
  FileUtils.mkdir_p "#{results_folder}/validation_reads"

  sample_filenames = Dir.glob('source_data/reads/*.fastq.gz')
  sample_filenames.select!{|fn| File.basename(fn).match?(/_#{experiment_type}_/) }
  sample_filenames.reject!{|fn| File.basename(fn).match?(/_AffSeq_/) }

  samples = sample_filenames.map{|fn| parse_filename(fn) }
  Parallel.each(samples, in_processes: 20) do |sample|
    # In SELEX there are no paired reads, so we don't add it to filename
    bn = sample.values_at(:tf, :type, :cycle, :adapter, :batch).join('.')
    train_fn = "#{results_folder}/train_reads/#{bn}.selex.train.fastq.gz"
    validation_fn = "#{results_folder}/validation_reads/#{bn}.selex.val.fastq.gz"
    train_val_split(sample[:filename], train_fn, validation_fn)
  end

  File.open('results/stats.tsv', 'w') do |fw|
    header = ['tf', 'type', 'cycle', 'adapter', 'batch', 'train/validation', 'filename', 'num_reads']
    fw.puts(header.join("\t"))
    samples.each{|sample|
      bn = sample.values_at(:tf, :type, :cycle, :adapter, :batch).join('.')
      train_fn = "#{results_folder}/train_reads/#{bn}.selex.train.fastq.gz"
      info_train = sample.values_at(:tf, :type, :cycle, :adapter, :batch) + ['train', train_fn, num_reads_in_fastq(train_fn)]
      fw.puts(info_train.join("\t"))

      validation_fn = "#{results_folder}/validation_reads/#{bn}.selex.val.fastq.gz"
      info_validation = sample.values_at(:tf, :type, :cycle, :adapter, :batch) + ['validation', validation_fn, num_reads_in_fastq(validation_fn)]
      fw.puts(info_validation.join("\t"))
    }
  end
}
