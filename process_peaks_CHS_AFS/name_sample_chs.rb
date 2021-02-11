require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'
require_relative '../shared/lib/random_names'

module Chipseq
  SampleMetadata = Struct.new(*[
        :experiment_id, :plasmid_id, :gene_id, :sample_id, :sample_label,
        :chip_or_input, :replicate, :comments, :data_file_id, :sequencing_facility,
      ], keyword_init: true) do

    def construct_type; $plasmid_by_number[plasmid_id].construct_type; end
    def normalized_id
      data_file_id && data_file_id.sub(/\.fastq\.gz$/, "").sub(/_001$/, "").sub(/_R\d$/, "")
    end

    def self.from_string(line)
      # Example:
      ## ChIP experiment uinque ID Plasmid ID  Gene ID Sample ID Submitted sample label  ChIP/INPUT  Replicate # Comments  Data File ID  Sequencing Facility     
      ## SI0140  pTH16498  SNAI1 pTH16498.1.1  SNAI1-rep1  ChIP  1   Hughes_2_SNAI1_FS0169 DSC 
      experiment_id, plasmid_id, gene_id, sample_id, sample_label, \
        chip_or_input, replicate, comments, data_file_id, sequencing_facility = line.chomp.split("\t")
      self.new(
        experiment_id: experiment_id, plasmid_id: plasmid_id, gene_id: gene_id,
        sample_id: sample_id, sample_label: sample_label,
        chip_or_input: chip_or_input, replicate: Integer(replicate), comments: comments,
        data_file_id: data_file_id, sequencing_facility: sequencing_facility,
      )
    end

    def self.each_in_file(filename)
      return enum_for(:each_in_file, filename)  unless block_given?
      File.readlines(filename).drop(1).map{|line|
        yield self.from_string(line)
      }
    end
  end

  def self.verify_sample_metadata_match!
    samples = Dir.glob('results_databox_chs/train_intensities/*')
    metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').to_a
    sample_metadata_pairs = full_join_by(
      samples, metadata,
      key_proc_1: ->(fn){ File.basename(fn).split('.')[1].sub(/_L\d+(\+L\d+)?$/, "").sub(/_[ACGT]{6}$/, "") },
      key_proc_2: ->(m){ m.normalized_id }
    )

    sample_metadata_pairs.reject{|key, sample_fn, sample_metadata|
      sample_fn && sample_metadata
    }.each{|key, sample_fn, sample_metadata|
      puts(File.basename(sample_fn) + " has no metadata")  if sample_fn
      puts("no sample for metadata: #{sample_metadata}")   if sample_metadata
    }
  end

  def self.gen_name(sample_metadata, sample_fn, slice_type:, extension:)
    experiment_id = sample_metadata.experiment_id
    tf = sample_metadata.gene_id
    construct_type = sample_metadata.construct_type
    basename = "#{tf}.#{construct_type}@CHS@#{experiment_id}"

    uuid = take_dataset_name!
    "#{basename}@Peaks.#{uuid}.#{slice_type}.#{extension}"
  end

  def self.main
    slice_type = nil
    extension = nil
    processing_type = nil
    argparser = OptionParser.new{|o|
      o.on('--slice-type VAL', 'Train or Val') {|v| slice_type = v }
      o.on('--extension VAL', 'fa or peaks') {|v| extension = v }
    }

    argparser.parse!(ARGV)
    sample_fn = ARGV[0]
    raise 'Specify slice type (Train or Val)'  unless ['Train', 'Val'].include?(slice_type)
    raise 'Specify extension (fa or peaks)'  unless ['fa', 'peaks'].include?(extension)
    raise 'Specify sample filename'  unless sample_fn
    raise 'Sample file not exists'  unless File.exist?(sample_fn)

    plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
    $plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

    metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').to_a

    # assay_id = File.basename(sample_fn).split('_')[0]
    data_file_id = File.basename(sample_fn).split('.')[1]
    normalized_id = data_file_id.sub(/_L\d+(\+L\d+)?$/, "").sub(/_\d_pf(\+\d_pf)?$/,"").sub(/_[ACGT]{6}$/, "")
    sample_metadata = metadata.detect{|m| m.normalized_id == normalized_id }
    if sample_metadata
      puts self.gen_name(sample_metadata, sample_fn, slice_type: slice_type, extension: extension, )
    end
  end
end

Chipseq.main
