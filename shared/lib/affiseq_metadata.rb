require_relative 'utils'

module Affiseq
#  Library after PCR (for Affiseq). This is what the TF sees
# ACACTCTTTCCCTACACGAC GCTCTTCCGATCT(Random Genomic fragment)AGATCGGAAGAGC ACACGTCTG AACTCCAG 3'
# TGTGAGAAAGGGATGTGCTG CGAGAAGGCTAGA(Random Genomic fragment)TCTAGCCTTCTCG TGTGCAGAC TTGAGGTC 5'
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'AGATCGGAAGAGCACACGTCTGAACTCCAG'

  SampleMetadata = Struct.new(*[
        :experiment_id, :plasmid_id, :gene_name, :ivt_or_lysate, :dna_library_id, :well,
        :cycle_1_filename, :cycle_2_filename, :cycle_3_filename, :cycle_4_filename,
        :cycle_1_read_2_filename, :cycle_2_read_2_filename, :cycle_3_read_2_filename,
        :folder,
      ], keyword_init: true) do

    def construct_type; $plasmid_by_number[plasmid_id].construct_type; end

    def filenames # known to be highly incomplete
      [
        cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename,
        cycle_1_read_2_filename, cycle_2_read_2_filename, cycle_3_read_2_filename,
      ].compact
    end

    def supposed_filenames
      (1..4).flat_map{|cycle|
        (1..2).map{|read_number|
          "#{normalized_basename}_Cycle#{cycle}_R#{read_number}.fastq.gz"
        }
      }
    end

    def normalized_basename
      [
        cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename,
        cycle_1_read_2_filename, cycle_2_read_2_filename, cycle_3_read_2_filename,
      ].compact.map{|fn|
        fn.sub(/_Cycle\d_R[12].fastq.gz$/, '')
      }.uniq.take_the_only
    end

    def self.from_string(line)
      # Example:
      ## Experiment ID Plasmid ID  Gene name IVT or Lysate DNA library ID  Well  Filename Read1 Cycle1 Filename Read1 Cycle2 Filename Read1 Cycle3
      ## AATA_AffSeq_D5_GLI4 pTH15820  GLI4  Lysate  AffiSeqV1 D5  GLI4_AffSeq_Lysate_BatchAATA_Cycle1_R1.fastq.gz GLI4_AffSeq_Lysate_BatchAATA_Cycle2_R1.fastq.gz GLI4_AffSeq_Lysate_BatchAATA_Cycle3_R1.fastq.gz
      fn_converter = ->(fn){ (fn.start_with?('No cycle ') || fn.start_with?('No read ')) ? nil : fn }

      experiment_id, plasmid_id, gene_name, ivt_or_lysate, dna_library_id, well, \
        cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename, \
        cycle_1_read_2_filename, cycle_2_read_2_filename, cycle_3_read_2_filename, \
        folder = line.chomp.split("\t")
      raise "Unknown type #{ivt_or_lysate} (should be IVT/Lysate)"  unless ['IVT', 'Lysate'].include?(ivt_or_lysate)
      self.new(
        experiment_id: experiment_id, plasmid_id: plasmid_id, gene_name: gene_name,
        ivt_or_lysate: ivt_or_lysate[0,3], dna_library_id: dna_library_id, well: well,
        cycle_1_filename: fn_converter.call(cycle_1_filename), cycle_2_filename: fn_converter.call(cycle_2_filename),
        cycle_3_filename: fn_converter.call(cycle_3_filename), cycle_4_filename: fn_converter.call(cycle_4_filename),
        cycle_1_read_2_filename: fn_converter.call(cycle_1_read_2_filename),
        cycle_2_read_2_filename: fn_converter.call(cycle_2_read_2_filename),
        cycle_3_read_2_filename: fn_converter.call(cycle_3_read_2_filename),
        folder: folder,
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
    def barcode; {flank_5: '', flank_3: '', insertion_length: nil}; end
    def tf; gene_name; end
  end
end
