module Affiseq
  SampleMetadata = Struct.new(*[
        :experiment_id, :plasmid_id, :gene_name, :ivt_or_lysate, :dna_library_id, :well,
        :cycle_1_filename, :cycle_2_filename, :cycle_3_filename,
      ], keyword_init: true) do

    def construct_type; $plasmid_by_number[plasmid_id].construct_type; end
    def filenames
      [cycle_1_filename, cycle_2_filename, cycle_3_filename].compact
    end

    def self.from_string(line)
      # Example:
      ## Experiment ID Plasmid ID  Gene name IVT or Lysate DNA library ID  Well  Filename Read1 Cycle1 Filename Read1 Cycle2 Filename Read1 Cycle3
      ## AATA_AffSeq_D5_GLI4 pTH15820  GLI4  Lysate  AffiSeqV1 D5  GLI4_AffSeq_Lysate_BatchAATA_Cycle1_R1.fastq.gz GLI4_AffSeq_Lysate_BatchAATA_Cycle2_R1.fastq.gz GLI4_AffSeq_Lysate_BatchAATA_Cycle3_R1.fastq.gz
      experiment_id, plasmid_id, gene_name, ivt_or_lysate, dna_library_id, well, \
        cycle_1_filename, cycle_2_filename, cycle_3_filename, = line.chomp.split("\t")
      raise "Unknown type #{ivt_or_lysate} (should be IVT/Lysate)"  unless ['IVT', 'Lysate'].include?(ivt_or_lysate)
      self.new(
        experiment_id: experiment_id, plasmid_id: plasmid_id, gene_name: gene_name,
        ivt_or_lysate: ivt_or_lysate[0,3], dna_library_id: dna_library_id, well: well,
        cycle_1_filename: cycle_1_filename, cycle_2_filename: cycle_2_filename, cycle_3_filename: cycle_3_filename,
      )
    end

    def self.each_in_file(filename)
      return enum_for(:each_in_file, filename)  unless block_given?
      File.readlines(filename).drop(1).map{|line|
        yield self.from_string(line)
      }
    end
  end
end
