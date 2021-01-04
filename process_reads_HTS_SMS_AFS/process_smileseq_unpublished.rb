require 'parallel'
require 'fileutils'
require_relative 'fastq'
require_relative 'train_val_split'
require_relative '../shared/lib/index_by'

# UT380-185_SETBP1_DBD_1_AT_hook_SS018_BC07.fastq
def parse_filename_smileseq(filename)
  basename = File.basename(filename, '.fastq')
  # ['UT380-185', 'SETBP1', 'DBD', ['1', 'AT', 'hook'], 'SS018', 'BC07']
  lab_specific_id, tf, dbd_or_fl, *domain_parts, sequencing_id, barcode_index = basename.split('_')
  barcode_index = barcode_index.sub(/^BC0*(\d+)$/, 'BC\1') # BC07 --> BC7
  {
    tf: tf, protein_structure: dbd_or_fl, domain: domain_parts.join('_'),
    barcode_index: barcode_index, sequencing_id: sequencing_id, lab_specific_id: lab_specific_id,
    basename: basename, filename: filename
  }
end

def read_metadata(filename)
  File.readlines(filename).drop(1).map{|line|
    bbi_id, hughes_id, tf_family, ssid, barcode = line.chomp.split("\t")
    tf, *rest = info[:hughes_id].split('.')
    construct_type = (rest.size >= 1) ? rest[0] : 'NA'
    {
      tf: tf, construct_type: construct_type, unique_experiment_id: bbi_id,
      barcode: barcode.sub(/^BC0*(\d+)$/, 'BC\1'), # BC07 --> BC7
      hughes_id: hughes_id, tf_family: tf_family, ssid: ssid,
    }
  }
end

def read_barcodes(filename)
  File.readlines(filename).map{|l|
    barcode_index, barcode_seq = l.chomp.split("\t")
    [barcode_index, {flank_5: barcode_seq, flank_3: ''}]
  }.to_h
end

barcodes = read_barcodes('source_data_smileseq/unpublished/smileseq_barcode_file.txt')

metadata_fn = 'source_data_smileseq/unpublished/SMiLE_seq_metadata_temp_17DEC2020_newData.tsv'
smileseq_infos = read_metadata(metadata_fn).index_by{|info| info[:unique_experiment_id] }


# SmileSeq
results_folder = "results_smileseq"
FileUtils.mkdir_p "#{results_folder}/train_reads"
FileUtils.mkdir_p "#{results_folder}/validation_reads"

sample_filenames = Dir.glob('source_data_smileseq/smileseq_raw/*.fastq')

samples = sample_filenames.map{|fn| parse_filename_smileseq(fn) }


Parallel.each(samples, in_processes: 20) do |sample|
  barcode = barcodes[sample[:barcode_index]].values_at(:flank_5, :flank_3).join('+')

  bn = [*sample.values_at(:tf, :protein_structure, :domain, :lab_specific_id, :sequencing_id, :barcode_index), barcode].join('.')
  train_fn = "#{results_folder}/train_reads/#{bn}.smileseq.train.fastq"
  validation_fn = "#{results_folder}/validation_reads/#{bn}.smileseq.val.fastq"
  train_val_split(sample[:filename], train_fn, validation_fn)
end

File.open("#{results_folder}/stats.tsv", 'w') do |fw|
  header = ['tf', 'protein_structure', 'domain', 'lab_specific_id', 'sequencing_id', 'barcode_index', 'train/validation', 'filename', 'num_reads']
  fw.puts(header.join("\t"))
  samples.each{|sample|
    bn = [*sample.values_at(:tf, :protein_structure, :domain, :lab_specific_id, :sequencing_id, :barcode_index), barcode].join('.')
    train_fn = "#{results_folder}/train_reads/#{bn}.smileseq.train.fastq"

    column_infos = sample.values_at(:tf, :protein_structure, :domain, :lab_specific_id, :sequencing_id, :barcode_index)
    info_train = [*column_infos, 'train', train_fn, num_reads_in_fastq(train_fn)]
    fw.puts(info_train.join("\t"))

    validation_fn = "#{results_folder}/validation_reads/#{bn}.smileseq.val.fastq"
    info_validation = [*column_infos, 'validation', validation_fn, num_reads_in_fastq(validation_fn)]
    fw.puts(info_validation.join("\t"))
  }
end
