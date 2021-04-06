require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'
require_relative '../shared/lib/random_names'
require_relative 'chipseq_metadata'

module Chipseq
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
    raise 'Specify slice type (Train / Val-B / Val-A)'  unless [nil, 'Train', 'Val-B', 'Val-A'].include?(slice_type)
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
    slice_type = File.basename(sample_fn).split('.')[4]
    if slice_type
      case slice_type
      when 'train'
        slice_type = 'Train'
      when 'basic_val'
        slice_type = 'Val-B'
      when /^advanced_val/
        slice_type = 'Val-A'
      else
        raise "Unknown slice type #{slice_type}"
      end
    end

    if sample_metadata
      puts self.gen_name(sample_metadata, sample_fn, slice_type: slice_type, extension: extension, )
    end
  end
end

Chipseq.main
