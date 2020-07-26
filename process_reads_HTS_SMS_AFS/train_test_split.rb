require 'fileutils'
require_relative 'fastq'

def train_test_split(input_filename, train_filename, test_filename, &criteria)
  reads = FastqRecord.each_in_file(input_filename).to_a
  criteria = ->(read, idx){ idx % 3 < 2 }  unless block_given?
  train_reads = reads.each_with_index.select(&criteria)
  test_reads  = reads.each_with_index.reject(&criteria)
  FastqRecord.store_to_file(train_filename, train_reads)
  FastqRecord.store_to_file(test_filename, test_reads)
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

FileUtils.mkdir_p 'results/train_reads'
FileUtils.mkdir_p 'results/test_reads'

sample_filenames = Dir.glob('source_data/reads/*.fastq.gz')
sample_filenames.select!{|fn| File.basename(fn).match?(/_(IVT|Lysate)_/) }
sample_filenames.reject!{|fn| File.basename(fn).match?(/_AffSeq_/) }

samples = sample_filenames.map{|fn| parse_filename(fn) }
samples.group_by{|info| [info[:tf], info[:type]] }.each{|(tf, type), tf_samples|
  tf_samples.each{|sample|
    train_test_split(sample[:filename], "results/train_reads/#{sample[:basename]}.fastq.gz", "results/test_reads/#{sample[:basename]}.fastq.gz")
  }
}


# seqkit  sample          sample sequences by number or proportion
# seqkit  common          find common sequences of multiple files by id/name/sequence
