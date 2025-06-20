require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'

module Selex
  # Random insert sequences should be extended with sequences that were physically present during the binding experiments,
  # i.e. include parts of the primers (5′ ACACTCTTTCCCTACACGACGCTCTTCCGATCT and 3′ AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC) and barcodes.
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC'

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
    def self.from_filename(filename)
      basename = File.basename(File.basename(filename, '.gz'), '.fastq')
      basename = basename.sub('Ecoli_GST', 'Lysate')
      basename = basename.sub('eGFP_IVT', 'GFPIVT')
      basename = basename.sub('Batch_', 'Batch')
      case basename
      when /^\w+(-(DBD|FL|DBDwLinker)(-\d)?)?_[ACGT]+\d+N[ACGT]+_(IVT|Lysate)_Batch\w+_Cycle\d_R[12]$/
        # AHCTF1_GG40NCGTAGT_IVT_BatchYWCB_Cycle3_R1.fastq.gz
        # SNAI1_AC40NGCTGCT_Lysate_BatchAATA_Cycle2_R1.fastq.gz
        # ZNF384-FL_GT40NGCGTGT_Ecoli_GST_BatchYWDA_Cycle2_R1.fastq.gz
        tf_plus_fl_or_dbd, barcode_str, experiment_subtype, batch, cycle, reads_part = basename.split('_')
        tf = tf_plus_fl_or_dbd.sub(/-(FL|DBD|DBDwLinker)(-\d)?$/, '')
      when /^\w+_pTH\d+_[ACGT]+\d+N[ACGT]+_(IVT|Lysate)_Batch\w+_(Standard|LongWash)_Well_\w\d+_Cycle\d_Read[12]$/
        # ATMIN_pTH13619_CA40NAGCGTA_Lysate_Batch_YWKA_Standard_Well_C3_Cycle1_Read1.fastq.gz
        tf, plasmid_id, barcode_str, experiment_subtype, batch, standard_or_longwash, _well_word, well, cycle, reads_part = basename.split('_')
      when /^\w+_(FL|DBD|DBDwLinker)\d?_[ACGT]+\d+N[ACGT]+_Well_\w\d+_(IVT|Lysate|GFPIVT)_Batch\w+_Cycle\d_S\d+_R[12]_001$/
        # PRDM2_DBD2_GT40NGCGTGT_Well_F11_eGFP_IVT_BatchYWPA_Cycle1_S71_R1_001.fastq.gz
        # S71 — is probably lane number, but not sure
        tf, fl_or_dbd, barcode_str, _well_word, well, experiment_subtype, batch, cycle, lane, reads_part, _word_001 = basename.split('_')
        fl_or_dbd = fl_or_dbd.sub(/\d$/, '')
      when /^\w{3}_A_\w+(\.(FL|DBD|AThook)(\.\d)?)?_[ACGT]+\d+N[ACGT]+_Cycle\d_\w\d+_Read[12]$/
        # YWM_A_ADNP.DBD.1_CG40NGTTATT_Cycle1_D1_Read1.fastq.gz
        batch, _a_word, tf_plus_fl_or_dbd, barcode_str, cycle, well, reads_part = basename.split('_')
        tf = tf_plus_fl_or_dbd.split('.').first
        if batch == 'YWM'
          # ATTENTION!!! Hardcoded experiment subtype based on current metadata table!
          experiment_subtype = 'GFPIVT'
        elsif batch == 'YWL' || batch == 'YWN' || batch == 'YWO'
          # ATTENTION!!! Hardcoded experiment subtype based on current metadata table!
          experiment_subtype = 'Lysate'
        else
          raise 'Unknown batch!!!'
        end
      when /^YWDA_[ACGT]+\d+N[ACGT]+_\w+_cyc\d_\w+_Read[12]$/
        # YWDA_TA40NGAGGGT_G05_cyc1_ZMAT4_Read1.fastq.gz — the only sample (4 files)
        batch, barcode_str, well, cycle, tf, reads_part = basename.split('_')
        experiment_subtype = 'Lysate'  # ATTENTION!!! Hardcoded experiment subtype based on current metadata table!
      else
        raise
      end

      raise "Failed to parse filename `#{filename}`"  unless reads_part == 'R1' || reads_part == 'Read1'
#      raise "Failed to parse filename `#{filename}`"  unless batch.start_with?('Batch')
      raise "Failed to parse filename `#{filename}`"  unless cycle.start_with?('Cycle') || cycle.start_with?('cyc')
      raise "Unknown experiment subtype `#{experiment_subtype}` for filename `#{filename}`"  unless ['IVT', 'Lysate', 'GFPIVT'].include?(experiment_subtype)
      experiment_subtype = {'IVT' => 'IVT', 'Lysate' => 'Lys', 'GFPIVT' => 'GFPIVT'}[experiment_subtype]
      tf = tf.sub(/-(FL|DBD|DBDwLinker)(-\d)?$/, '')
      self.new(tf: tf, experiment_subtype: experiment_subtype,
        cycle: Integer(cycle.sub(/^Cycle/, '').sub(/^cyc/, '')),
        barcode: Selex.parse_barcode(barcode_str),
        batch: batch.sub(/^Batch/, ''),
        filename: filename)
    end
  end

  DNA_LIBRARY_PATTERN = /^(Toronto_)?(?<barcode>[ACGT]+\d+N[ACGT]+)0?_v1$/
  SampleMetadata = Struct.new(*[
        :experiment_id, :plasmid_id, :temporary_note, :gene_name,
        :experiment_subtype, :dna_library_id,
        :cycle_1_filename, :cycle_2_filename, :cycle_3_filename, :cycle_4_filename,
        :well_on_plate, :experimental_note, :batch,
      ], keyword_init: true) do

    def self.header_row;
      [
        'Experiment ID', 'Plasmid ID', 'Temporary edit note to GreCo side', 'Gene name', 'IVT or Lysate', 'DNA library ID',
        'Cycle 1 filename', 'Cycle 2 filename', 'Cycle 3 filename', 'Cycle 4 filename', 'Well on the 96 well plate', 'Experimental note',
        'Batch'
      ]
    end

    def data_row
      self.to_h.values_at(*[
        :experiment_id, :plasmid_id, :temporary_note, :gene_name, :experiment_subtype, :dna_library_id,
        :cycle_1_filename, :cycle_2_filename, :cycle_3_filename, :cycle_4_filename, :well_on_plate, :experimental_note,
        :batch,
      ])
    end

    def barcode
      Selex.parse_barcode( DNA_LIBRARY_PATTERN.match(self.dna_library_id)[:barcode] )
    end

    def experiment_type; "HTS.#{experiment_subtype}"; end
    def tf; gene_name; end
    def construct_type
      $plasmid_by_number[plasmid_id].construct_type
    rescue => e
      $stderr.puts "Can't get construct_type, use NA. Probably missing plasmid #{plasmid_id}. Recovered from error:\n#{e}"
      'NA'
    end

    def filenames; [cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename].compact; end
    def normalized_basenames
      filenames.map{|fn|
        File.basename(fn, '.fastq.gz')
      }.map{|bn|
        bn.sub(/_001$/, '').sub(/_(S\d+_)?R(ead)?[12]$/, '').sub(/_(Cycle|cyc)\d/, '')
      }.uniq
    end

    def self.from_string(line)
      # Example:
      ## Experiment ID Plasmid ID  Temporary edit note to GreCo side  Gene name IVT or Lysate DNA library ID  Cycle 1 - file ID Cycle 2 - file ID Cycle 3 - file ID  Experimental note  Well on the 96 well plate
      ## YWC_A_AC40NTCCTTG pTH13929  ZBED2 IVT AC40NTCCTTG_v1  ZBED2_AC40NTCCTTG_IVT_BatchYWCA1_Cycle1_R1.fastq.gz ZBED2_AC40NTCCTTG_IVT_BatchYWCA2_Cycle2_R1.fastq.gz ZBED2_AC40NTCCTTG_IVT_BatchYWCA3_Cycle3_R1.fastq.gz A12
      experiment_id, plasmid_id, temporary_note, gene_name, experiment_subtype, dna_library_id, cycle_1_filename, cycle_2_filename, cycle_3_filename, cycle_4_filename, well_on_plate, experimental_note = line.chomp.split("\t", 12)
      raise "Unknown experiment subtype `#{experiment_subtype}`"  unless ['IVT', 'Lysate', 'eGFP_IVT'].include?(experiment_subtype)
      experiment_subtype = {'IVT' => 'IVT', 'Lysate' => 'Lys', 'eGFP_IVT' => 'GFPIVT'}[experiment_subtype]
      raise  unless dna_library_id.match?(DNA_LIBRARY_PATTERN)
      # barcode_str = dna_library_id.sub(/_v1$/, '') # GT40NGCGTGT_v1 --> GT40NGCGTGT
      # barcode = Selex.parse_barcode(barcode_str)

      filename_or_nil = ->(fn){ (fn == 'No_Data') ? nil : fn }
      result = self.new(
        experiment_id: experiment_id, plasmid_id: plasmid_id, gene_name: gene_name,
        experiment_subtype: experiment_subtype, dna_library_id: dna_library_id,
        cycle_1_filename: filename_or_nil.(cycle_1_filename),
        cycle_2_filename: filename_or_nil.(cycle_2_filename),
        cycle_3_filename: filename_or_nil.(cycle_3_filename),
        cycle_4_filename: filename_or_nil.(cycle_4_filename),
        well_on_plate: well_on_plate,
        temporary_note: temporary_note,
        experimental_note: experimental_note,
      )
      result[:batch] = result.normalized_basenames.map{|bn| bn[/Batch([^_]+)/, 1] }.join('+')
      result
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
    fields.all?{|f| sample.send(f) == sample_metadata.send(f) }
  end
end
