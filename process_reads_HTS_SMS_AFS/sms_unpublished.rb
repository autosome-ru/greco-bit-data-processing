require_relative '../shared/lib/index_by'

module SMSUnpublished
  # The library is designed as follows:
  # TCGTCGGCAGCGTCAGATGTGTATAAGAGACAG -[BC 1-12, 10bp e.g. CGTATGAATC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - CTGTCTCTTATACACATCTCCGAGCCCA
  ADAPTER_5 = 'TCGTCGGCAGCGTCAGATGTGTATAAGAGACAG'
  ADAPTER_3 = 'CTGTCTCTTATACACATCTCCGAGCCCA'

  def self.read_barcodes(filename)
    File.readlines(filename).map{|l|
      barcode_index, barcode_seq = l.chomp.split("\t")
      [barcode_index, {flank_5: barcode_seq, flank_3: ''}]
    }.to_h
  end

  Sample = Struct.new(*[:experiment_id, :tf, :construct_type, :barcode_index, :domain, :sequencing_id, :filename], keyword_init: true) do
    # UT380-185_SETBP1_DBD_1_AT_hook_SS018_BC07.fastq
    def self.from_filename(filename)
      basename = File.basename(filename, '.fastq')
      experiment_id_match = basename.match(/^(UT\d\d\d)[-_]?(\d\d\d)_/)
      basename_wo_experiment_id = basename[experiment_id_match[0].length..-1]
      experiment_id = experiment_id_match[1] + '-' + experiment_id_match[2] # UT380_501 --> UT380-501, UT380408 --> UT380-408
      # ['SETBP1', 'DBD', ['1', 'AT', 'hook'], 'SS018', 'BC07']
      tf, dbd_or_fl, *domain_parts, sequencing_id, barcode_index = basename_wo_experiment_id.split('_')
      unless ['FL', 'DBD', 'AThook'].include?(dbd_or_fl)
        domain_parts = [dbd_or_fl, *domain_parts]
        dbd_or_fl = 'NA'
      end
      barcode_index = barcode_index.sub(/^BC0*(\d+)$/, 'BC\1') # BC07 --> BC7
      self.new(experiment_id: experiment_id, tf: tf, construct_type: dbd_or_fl,
        barcode_index: barcode_index, domain: domain_parts.join('_'), sequencing_id: sequencing_id,
        filename: filename)
    end
    def cycle; nil; end
  end

  # Hughes ID is same as insert_id
  SampleMetadata = Struct.new(*[:experiment_id, :tf, :construct_type, :barcode_index, :hughes_id, :tf_family, :ssid, :hgnc, :clone_suffix, :clone_suffix_pt2, :instance_of_hgnc, :insert_id], keyword_init: true) do
    def self.header_row; ['Experiment ID', 'TF', 'Construct type', 'Barcode', 'Hughes ID', 'TF family', 'SSID', 'HGNC', 'Clone suffix', 'Clone suffix Pt2', 'Instance of the HGNC']; end
    def data_row; to_h.values_at(*[:experiment_id, :tf, :construct_type, :barcode_index, :hughes_id, :tf_family, :ssid, :hgnc, :clone_suffix, :clone_suffix_pt2, :instance_of_hgnc]); end
    def experiment_type; 'SMS'; end
    def cycle; nil; end

    def self.from_string(line)
      # Example:
      ## BBI_ID  Hughes_ID TF_family SSID  Barcode
      ## UT380-009 AHCTF1.DBD  AT hook SS001 BC01
      bbi_id, hughes_id, tf_family, ssid, barcode_index, hgnc, clone_suffix, clone_suffix_pt2, instance_of_hgnc = line.chomp.split("\t")
      tf, *rest = hughes_id.split('.')  # hughes_id examples: `MBD4`, `BHLHA9.FL`, `CASZ1.DBD.1`
      construct_type = (rest.size >= 1) ? rest[0] : 'NA'
      self.new(experiment_id: bbi_id, tf: tf, construct_type: construct_type,
        barcode_index: barcode_index.sub(/^BC0*(\d+)$/, 'BC\1'), # BC07 --> BC7
        hughes_id: hughes_id, tf_family: tf_family, ssid: ssid,
        hgnc: hgnc, clone_suffix: clone_suffix, clone_suffix_pt2: clone_suffix_pt2, instance_of_hgnc: instance_of_hgnc,
        insert_id: hughes_id)
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
    fields = [:tf, :construct_type, :barcode_index]
    return false  unless sample.to_h.values_at(*fields) == sample_metadata.to_h.values_at(*fields)
    return false  unless sample.experiment_id.split('-')[0,2] == sample_metadata.experiment_id.split('-')[0,2]
    true
  end
end
