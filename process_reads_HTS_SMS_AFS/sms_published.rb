require_relative '../shared/lib/index_by'

module SMSPublished
  # Library composition:
  # ACACTCTTTCCCTACACGACGCTCTTCCGATCT - [BC-half1, 7bp e.g. BC1=CATGCTC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - [BC-half2, 7bp e.g. BC1=GAGCATG] - GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG'

  def self.read_barcodes(filename)
    File.readlines(filename).map{|l|
      barcode_index, barcode_seq_flank5, barcode_seq_flank3 = l.chomp.split("\t")
      [barcode_index, {flank_5: barcode_seq_flank5, flank_3: barcode_seq_flank3}]
    }.to_h
  end

  Sample = Struct.new(*[:experiment_id, :tf_non_normalized, :barcode_index, :filename], keyword_init: true) do
    # SRR3405054_CEBPb_BC15.fastq or SRR3405138_cJUN_FOSL2_2_BC11.fastq
    def self.from_filename(filename)
      basename = File.basename(filename, '.fastq')
      # ['SRR3405138', ['cJUN', 'FOSL2', '2'], 'BC11']
      experiment_id, *tf_parts, barcode_index = basename.split('_')
      self.new(experiment_id: experiment_id, tf_non_normalized: tf_parts.join('_'), barcode_index: barcode_index, filename: filename)
    end
  end

  SampleMetadata = Struct.new(*[:tfs, :construct_type, :experiment_id, :barcode_index, :tf_non_normalized], keyword_init: true) do
    def self.header_row; ['Experiment ID', 'TF(s)', 'Construct type', 'Barcode', 'TF non-normalized name']; end
    def data_row; to_h.values_at(*[:experiment_id, :tf_normalized, :construct_type, :barcode_index, :tf_non_normalized]); end
    def tf_normalized; tfs.join(';'); end
    def experiment_type; 'SMS'; end

    def self.from_string(line)
      # Example:
      ## SRR_ID  Barcode TF_name_(replicate) tf_normalized
      ## SRR3405054  BC15  CEBPb CEBPB
      srr_id, barcode_index, tf_non_normalized, tf_normalized = l.chomp.split("\t")
      tfs = tf_normalized.split(';')
      self.new(tfs: tfs, construct_type: 'NA', experiment_id: srr_id, barcode_index: barcode_index, tf_non_normalized: tf_non_normalized)
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
    fields = [:experiment_id, :tf_non_normalized, :barcode_index]
    sample.to_h.values_at(*fields) == sample_metadata.to_h.values_at(*fields)
  end
end
