require 'parallel'
require 'fileutils'
require_relative 'fastq'
require_relative 'train_val_split'

# AHCTF1_GG40NCGTAGT_IVT_BatchYWCB_Cycle3_R1.fastq.gz
# SNAI1_AC40NGCTGCT_Lysate_BatchAATA_Cycle2_R1.fastq.gz
def parse_filename_selex(filename)
  basename = File.basename(File.basename(filename, '.gz'), '.fastq')
  tf, adapter, type, batch, cycle, reads_part = basename.split('_')
  raise  unless reads_part == 'R1'
  {tf: tf, adapter: adapter, type: type, batch: batch, cycle: cycle, filename: filename, basename: basename}
end

# SELEX (and without AffiSeq!)
['IVT', 'Lysate', 'eGFP_IVT'].each{|experiment_type|
  results_folder = "results_#{experiment_type}"
  FileUtils.mkdir_p "#{results_folder}/train_reads"
  FileUtils.mkdir_p "#{results_folder}/validation_reads"

  sample_filenames = Dir.glob('source_data/reads/*.fastq.gz')
  sample_filenames.select!{|fn| File.basename(fn).match?(/_#{experiment_type}_/) }
  sample_filenames.reject!{|fn| File.basename(fn).match?(/_AffSeq_/) }

  samples = sample_filenames.map{|fn| parse_filename_selex(fn) }
  Parallel.each(samples, in_processes: 20) do |sample|
    # In SELEX there are no paired reads, so we don't add it to filename
    bn = sample.values_at(:tf, :type, :cycle, :adapter, :batch).join('.')
    train_fn = "#{results_folder}/train_reads/#{bn}.selex.train.fastq.gz"
    validation_fn = "#{results_folder}/validation_reads/#{bn}.selex.val.fastq.gz"
    train_val_split(sample[:filename], train_fn, validation_fn)
  end

  File.open("#{results_folder}/stats.tsv", 'w') do |fw|
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
