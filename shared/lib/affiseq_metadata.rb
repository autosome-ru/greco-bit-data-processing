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
        :cycle_1_read_2_filename, :cycle_2_read_2_filename, :cycle_3_read_2_filename, :cycle_4_read_2_filename,
        :folder, :experimental_note,
        :batch,
      ], keyword_init: true) do

    def construct_type; $plasmid_by_number[plasmid_id].construct_type; end

    def filenames # known to be highly incomplete
      [
        cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename,
        cycle_1_read_2_filename, cycle_2_read_2_filename, cycle_3_read_2_filename, cycle_4_read_2_filename,
      ].compact
    end

    def supposed_filenames
      template = filenames.first

      guesses = (1..4).flat_map{|cycle|
        (1..2).map{|read_number|
          # Known problem: S-part can't be derived
          # POU5F2-FL_GHTSELEX-Well-A5_eGFP-IVT_BatchYWQB_Cycle1_S293_R1_001.fastq.gz
          # POU5F2-FL_GHTSELEX-Well-A5_eGFP-IVT_BatchYWQB_Cycle3_S1061_R1_001.fastq.gz
            template.sub(/_Cycle\d(_\w\d+)?_R(ead)?[12]\.fastq(\.gz)?$/, "_Cycle#{cycle}\\1_R\\2#{read_number}.fastq\\3") \
                    .sub(/_Cycle\d_(S\d+)_R[12]_001\.fastq(\.gz)?$/, "_Cycle#{cycle}_\\1_R#{read_number}_001.fastq\\2") \
                    .sub(/_cyc\d_read[12]\.fastq(\.gz)?$/, "_cyc#{cycle}_read#{read_number}.fastq\\1")
        }
      }
      (filenames + guesses).uniq
    end

    def normalized_basename
      filenames.map{|fn|
        # ZNF490_AffSeq_Lysate_BatchAATA_Cycle1_R1.fastq.gz
        # ZNF672_pTH13735_AffiSeq_Lysate_Batch_YWKB_Standard_Well_G11_Cycle1_Read1.fastq.gz
        # ZNF850-DBD2_GHTSELEX-Well-C12_eGFP-IVT_BatchYWSB_Cycle1_S1476_R1_001.fastq.gz
        # YWDB_AffSeq_G05_ZMAT4_cyc2_read1.fastq.gz
        fn.sub(/_Cycle\d(_\w\d+)?_R(ead)?[12]\.fastq(\.gz)?$/, '') \
          .sub(/_Cycle\d_S\d+_R[12]_001\.fastq(\.gz)?$/, '') \
          .sub(/_cyc\d_read[12]\.fastq(\.gz)?$/, '')

      }.uniq.take_the_only
    end

    def self.from_string(line)
      # Example:
      ## Experiment ID Plasmid ID  Gene name IVT or Lysate DNA library ID  Well  Filename Read1 Cycle1 Filename Read1 Cycle2 Filename Read1 Cycle3
      ## AATA_AffSeq_D5_GLI4 pTH15820  GLI4  Lysate  AffiSeqV1 D5  GLI4_AffSeq_Lysate_BatchAATA_Cycle1_R1.fastq.gz GLI4_AffSeq_Lysate_BatchAATA_Cycle2_R1.fastq.gz GLI4_AffSeq_Lysate_BatchAATA_Cycle3_R1.fastq.gz
      fn_converter = ->(fn){ (fn.start_with?('No cycle ') || fn.start_with?('No read ') || fn.start_with?('No_Data') || fn.empty? || fn.downcase == 'no') ? nil : fn }

      experiment_id, plasmid_id, _temp_note, gene_name, ivt_or_lysate, dna_library_id, well, \
        cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename, \
        cycle_1_read_2_filename, cycle_2_read_2_filename, cycle_3_read_2_filename, cycle_4_read_2_filename, experimental_note, \
        folder = line.chomp.split("\t")
      raise "Unknown type #{ivt_or_lysate} (should be IVT/Lysate)"  unless ['IVT', 'Lysate', 'eGFP_IVT'].include?(ivt_or_lysate)

      ivt_or_lysate = {'IVT' => 'IVT', 'Lysate' => 'Lys', 'eGFP_IVT' => 'GFPIVT'}.fetch(ivt_or_lysate, ivt_or_lysate)
      result = self.new(
        experiment_id: experiment_id.sub('.', '_').sub('-', '_'), plasmid_id: plasmid_id, gene_name: gene_name,
        ivt_or_lysate: ivt_or_lysate, dna_library_id: dna_library_id, well: well,
        cycle_1_filename: fn_converter.call(cycle_1_filename), cycle_2_filename: fn_converter.call(cycle_2_filename),
        cycle_3_filename: fn_converter.call(cycle_3_filename), cycle_4_filename: fn_converter.call(cycle_4_filename),
        cycle_1_read_2_filename: fn_converter.call(cycle_1_read_2_filename),
        cycle_2_read_2_filename: fn_converter.call(cycle_2_read_2_filename),
        cycle_3_read_2_filename: fn_converter.call(cycle_3_read_2_filename),
        cycle_4_read_2_filename: fn_converter.call(cycle_4_read_2_filename),
        folder: folder,
        experimental_note: experimental_note,
      )
      result[:batch] = result.normalized_basename[/Batch([^_]+)/, 1]
      result
    end

    def to_s
      ivt_or_lysate_mapping = {'IVT' => 'IVT', 'Lys' => 'Lysate', 'GFPIVT' => 'eGFP_IVT'}
      [experiment_id, plasmid_id, gene_name,
        ivt_or_lysate_mapping.fetch(ivt_or_lysate, ivt_or_lysate),
        dna_library_id, well,
        *[
          cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename,
          cycle_1_read_2_filename, cycle_2_read_2_filename, cycle_3_read_2_filename, cycle_4_read_2_filename,
        ].map{|fn| fn || 'no' },
        folder].join("\t")
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
