require_relative '../shared/lib/index_by'

module Selex
  # Random insert sequences should be extended with sequences that were physically present during the binding experiments,
  # i.e. include parts of the primers (5′ ACACTCTTTCCCTACACGACGCTCTTCCGATCT and 3′ AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC) and barcodes.
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC'

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

  SampleMetadata = Struct.new(*[:experiment_id, :plasmid_id, :gene_name, :hughes_experiment_id, :experiment_subtype, :dna_library_id, :cycle_1_filename, :adapter], keyword_init: true) do
    def self.header_row; ['Experiment ID', 'Gene name', 'IVT or Lysate', 'Plasmid ID', 'ExperimentID from Hughes lab', 'DNA library ID', 'Cycle 1 - file ID etc.']; end
    def data_row; to_h.values_at(*[:experiment_id, :gene_name, :experiment_subtype, :plasmid_id, :hughes_experiment_id, :dna_library_id, :cycle_1_filename]); end
    def experiment_type; "HTS_#{experiment_subtype}"; end

    def self.from_string(line)
      # Example:
      ## Experiment ID Plasmid ID  Gene name ExperimentID from Hughes lab  IVT or Lysate DNA library ID  Cycle 1 - file ID etc.
      ## YWC_086 pTH13926  C11orf95  YWC_A_GT40NGCGTGT IVT GT40NGCGTGT_v1  C11orf95_GT40NGCGTGT_IVT_BatchYWCA_Cycle1_R1.fastq.gz 
      experiment_id, plasmid_id, gene_name, hughes_experiment_id, experiment_subtype, dna_library_id, cycle_1_filename = line.chomp.split("\t")
      raise "Unknown experiment subtype `#{experiment_subtype}`"  unless ['IVT', 'Lys'].include?(experiment_subtype)
      raise  unless dna_library_id.match?(/^[ACGT]+\d+N[ACGT]+_v1$/)
      adapter_str = dna_library_id.sub(/_v1$/, '') # GT40NGCGTGT_v1 --> GT40NGCGTGT
      adapter = Selex.parse_adapter(adapter_str)
      self.new(experiment_id: experiment_id, experiment_subtype: experiment_subtype, 
        plasmid_id: plasmid_id, gene_name: gene_name, hughes_experiment_id: hughes_experiment_id, 
        dna_library_id: dna_library_id, cycle_1_filename: cycle_1_filename, adapter: adapter)
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
