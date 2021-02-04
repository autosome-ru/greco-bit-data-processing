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

  # barcode_str example: 'GG40NCGTAGT'
  def self.parse_barcode(barcode_str)
    barcode_match = barcode_str.match(/^(?<flank_5>[ACGT]+)(?<insertion_length>\d+)N(?<flank_3>[ACGT]+)$/)
    {
      flank_5: barcode_match[:flank_5],
      flank_3: barcode_match[:flank_3],
      insertion_length: Integer(barcode_match[:insertion_length]),
    }
  end

  Sample = Struct.new(*[:tf, :barcode, :experiment_subtype, :batch, :cycle, :filename], keyword_init: true) do

    # AHCTF1_GG40NCGTAGT_IVT_BatchYWCB_Cycle3_R1.fastq.gz
    # SNAI1_AC40NGCTGCT_Lysate_BatchAATA_Cycle2_R1.fastq.gz
    def self.from_filename(filename)
      basename = File.basename(File.basename(filename, '.gz'), '.fastq')
      tf, barcode_str, experiment_subtype, batch, cycle, reads_part = basename.split('_')
      raise  unless reads_part == 'R1'
      raise  unless batch.start_with?('Batch')
      raise  unless cycle.start_with?('Cycle')
      raise "Unknown experiment subtype `#{experiment_subtype}`"  unless ['IVT', 'Lysate'].include?(experiment_subtype)
      experiment_subtype = experiment_subtype[0,3]
      self.new(tf: tf, experiment_subtype: experiment_subtype,
        cycle: Integer(cycle.sub(/^Cycle/, '')),
        barcode: Selex.parse_barcode(barcode_str),
        batch: batch.sub(/^Batch/, ''),
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
      Selex.parse_barcode( self.dna_library_id.split('_').first )
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
      # barcode_str = dna_library_id.sub(/_v1$/, '') # GT40NGCGTGT_v1 --> GT40NGCGTGT
      # barcode = Selex.parse_barcode(barcode_str)

      filename_or_nil = ->(fn){ (fn == 'No_Data') ? nil : fn }
      self.new(
        experiment_id: experiment_id, plasmid_id: plasmid_id, gene_name: gene_name,
        experiment_subtype: experiment_subtype, dna_library_id: dna_library_id,
        cycle_1_filename: filename_or_nil.(cycle_1_filename),
        cycle_2_filename: filename_or_nil.(cycle_2_filename),
        cycle_3_filename: filename_or_nil.(cycle_3_filename),
        well_on_plate: well_on_plate,
      )
    end

    def self.each_in_file(filename)
      return enum_for(:each_in_file, filename)  unless block_given?
      File.readlines(filename).drop(1).map{|line|
        yield self.from_string(line)
      }
    end
    def adapter_5; ADAPTER_5; end
    def adapter_3; ADAPTER_3; end
  end

  def self.match_metadata?(sample, sample_metadata)
    fields = [:tf, :experiment_subtype, :barcode]
    sample.to_h.values_at(*fields) == sample_metadata.to_h.values_at(*fields)
  end
end
