require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'

module Selex
  # Random insert sequences should be extended with sequences that were physically present during the binding experiments,
  # i.e. include parts of the primers (5′ ACACTCTTTCCCTACACGACGCTCTTCCGATCT and 3′ AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC) and barcodes.
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC'

  def self.read_barcodes(filename)
    nil
    # File.readlines(filename).map{|l|
    #   barcode_index, barcode_seq = l.chomp.split("\t")
    #   [barcode_index, {flank_5: barcode_seq, flank_3: ''}]
    # }.to_h
  end

  # adapter_str example: 'GG40NCGTAGT'
  def self.parse_adapter(adapter_str)
    adapter_match = adapter_str.match(/^(?<flank_5>[ACGT]+)(?<insertion_length>\d+)N(?<flank_3>[ACGT]+)$/)
    {
      flank_5: adapter_match[:flank_5],
      flank_3: adapter_match[:flank_3],
      insertion_length: Integer(adapter_match[:insertion_length]),
    }
  end

  Sample = Struct.new(*[:tf, :adapter, :experiment_subtype, :batch, :cycle, :filename], keyword_init: true) do

    # AHCTF1_GG40NCGTAGT_IVT_BatchYWCB_Cycle3_R1.fastq.gz
    # SNAI1_AC40NGCTGCT_Lysate_BatchAATA_Cycle2_R1.fastq.gz
    def self.from_filename(filename)
      basename = File.basename(File.basename(filename, '.gz'), '.fastq')
      tf, adapter, experiment_subtype, batch, cycle, reads_part = basename.split('_')
      raise  unless reads_part == 'R1'
      raise  unless batch.start_with?('Batch')
      self.new(tf: tf, experiment_subtype: experiment_subtype, cycle: cycle,
        adapter: Selex.parse_adapter(adapter), batch: batch.sub(/^Batch/, ''),
        filename: filename)
    end
  end

  SampleMetadata = Struct.new(*[
        :experiment_id, :plasmid_id, :gene_name,
        :experiment_subtype, :dna_library_id,
        :cycle_1_filename, :cycle_2_filename, :cycle_3_filename,
        :well_on_plate,
      ], keyword_init: true) do

    def self.header_row;
      [
        'Experiment ID', 'Plasmid ID', 'Gene name', 'IVT or Lysate', 'DNA library ID',
        'Cycle 1 filename', 'Cycle 2 filename', 'Cycle 3 filename', 'Well on the 96 well plate',
      ]
    end

    def data_row
      self.to_h.values_at(*[
        :experiment_id, :plasmid_id, :gene_name, :experiment_subtype, :dna_library_id,
        :cycle_1_filename, :cycle_2_filename, :cycle_3_filename, :well_on_plate,
      ])
    end

    def barcode
      Selex.parse_adapter( self.dna_library_id.split('_').first )
    end

    def experiment_type; "HTS_#{experiment_subtype}"; end
    def tf; gene_name; end
    def construct_type; $plasmid_by_number[plasmid_id].construct_type; end

    def self.from_string(line)
      # Example:
      ## Experiment ID Plasmid ID  Gene name IVT or Lysate DNA library ID  Cycle 1 - file ID Cycle 2 - file ID Cycle 3 - file ID Well on the 96 well plate
      ## YWC_A_AC40NTCCTTG pTH13929  ZBED2 IVT AC40NTCCTTG_v1  ZBED2_AC40NTCCTTG_IVT_BatchYWCA1_Cycle1_R1.fastq.gz ZBED2_AC40NTCCTTG_IVT_BatchYWCA2_Cycle2_R1.fastq.gz ZBED2_AC40NTCCTTG_IVT_BatchYWCA3_Cycle3_R1.fastq.gz A12
      experiment_id, plasmid_id, gene_name, experiment_subtype, dna_library_id, cycle_1_filename, cycle_2_filename, cycle_3_filename, well_on_plate = line.chomp.split("\t")
      raise "Unknown experiment subtype `#{experiment_subtype}`"  unless ['IVT', 'Lysate'].include?(experiment_subtype)
      experiment_subtype = experiment_subtype[0,3]
      raise  unless dna_library_id.match?(/^[ACGT]+\d+N[ACGT]+_v1$/)
      # adapter_str = dna_library_id.sub(/_v1$/, '') # GT40NGCGTGT_v1 --> GT40NGCGTGT
      # adapter = Selex.parse_adapter(adapter_str)
      self.new(
        experiment_id: experiment_id, plasmid_id: plasmid_id, gene_name: gene_name,
        experiment_subtype: experiment_subtype, dna_library_id: dna_library_id,
        cycle_1_filename: cycle_1_filename, cycle_2_filename: cycle_2_filename, cycle_3_filename: cycle_3_filename,
        well_on_plate: well_on_plate,
      )
    end

    def self.each_in_file(filename)
      return enum_for(:each_in_file, filename)  unless block_given?
      File.readlines(filename).drop(1).map{|line|
        yield self.from_string(line)
      }
    end
  end

  def self.match_metadata?(sample, sample_metadata)
    fields = [:experiment_id, :tf, :construct_type, :barcode_index]
    sample.to_h.values_at(*fields) == sample_metadata.to_h.values_at(*fields)
  end
end

# # Selex::SampleMetadata.each_in_file


# # # SELEX (and without AffiSeq!)
# # ['IVT', 'Lysate'].each{|experiment_type|
# #   results_folder = "results_#{experiment_type}"
# #   FileUtils.mkdir_p "#{results_folder}/train_reads"
# #   FileUtils.mkdir_p "#{results_folder}/validation_reads"

# #   sample_filenames = Dir.glob('source_data/reads/*.fastq.gz')
# #   sample_filenames.select!{|fn| File.basename(fn).match?(/_#{experiment_type}_/) }
# #   sample_filenames.reject!{|fn| File.basename(fn).match?(/_AffSeq_/) }

# #   samples = sample_filenames.map{|fn| parse_filename_selex(fn) }
# #   Parallel.each(samples, in_processes: 20) do |sample|
# #     # In SELEX there are no paired reads, so we don't add it to filename
# #     bn = sample.values_at(:tf, :type, :cycle, :adapter, :batch).join('.')
# #     train_fn = "#{results_folder}/train_reads/#{bn}.selex.train.fastq.gz"
# #     validation_fn = "#{results_folder}/validation_reads/#{bn}.selex.val.fastq.gz"
# #     train_val_split(sample[:filename], train_fn, validation_fn)
# #   end

# #   File.open("#{results_folder}/stats.tsv", 'w') do |fw|
# #     header = ['tf', 'type', 'cycle', 'adapter', 'batch', 'train/validation', 'filename', 'num_reads']
# #     fw.puts(header.join("\t"))
# #     samples.each{|sample|
# #       bn = sample.values_at(:tf, :type, :cycle, :adapter, :batch).join('.')
# #       train_fn = "#{results_folder}/train_reads/#{bn}.selex.train.fastq.gz"
# #       info_train = sample.values_at(:tf, :type, :cycle, :adapter, :batch) + ['train', train_fn, num_reads_in_fastq(train_fn)]
# #       fw.puts(info_train.join("\t"))

# #       validation_fn = "#{results_folder}/validation_reads/#{bn}.selex.val.fastq.gz"
# #       info_validation = sample.values_at(:tf, :type, :cycle, :adapter, :batch) + ['validation', validation_fn, num_reads_in_fastq(validation_fn)]
# #       fw.puts(info_validation.join("\t"))
# #     }
# #   end
# # }
