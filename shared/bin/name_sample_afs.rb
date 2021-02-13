require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'
require_relative '../shared/lib/random_names'
require_relative 'experiment_info_afs'
require_relative '../shared/lib/affiseq_metadata'

module AffiseqPeaks
  def self.verify_sample_metadata_match!
    samples = Dir.glob('results_databox_chs/train_intensities/*') # TODO: FIX !!!
    metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
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

  def self.gen_name(sample_metadata, processing_type: processing_type, sample_fn, slice_type:, extension:, cycle:)
    experiment_id = sample_metadata.experiment_id
    tf = sample_metadata.gene_name
    construct_type = sample_metadata.construct_type
    basename = "#{tf}.#{construct_type}@AFS.#{sample_metadata.ivt_or_lysate}@#{experiment_id}.C#{cycle}"

    uuid = take_dataset_name!
    "#{basename}@#{processing_type}.#{uuid}.#{slice_type}.#{extension}"
  end

  def self.main
    slice_type = nil
    extension = nil
    processing_type = nil
    argparser = OptionParser.new{|o|
      o.on('--slice-type VAL', 'Train or Val') {|v| slice_type = v }
      o.on('--processing-type VAL', 'Peaks or Reads') {|v| processing_type = v }
      o.on('--extension VAL', 'fa or peaks') {|v| extension = v }
    }

    argparser.parse!(ARGV)
    sample_fn = ARGV[0]
    raise 'Specify processing type (Peaks or Reads)'  unless ['Peaks', 'Reads'].include?(processing_type)
    raise 'Specify slice type (Train or Val)'  unless ['Train', 'Val'].include?(slice_type)
    raise 'Specify extension (fa or peaks)'  unless ['fa', 'peaks'].include?(extension)
    raise 'Specify sample filename'  unless sample_fn
    raise 'Sample file not exists'  unless File.exist?(sample_fn)

    plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
    $plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

    metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
    experiment_infos = ExperimentInfo.each_from_file("#{__dir__}/../source_data_meta/AFS/metrics_by_exp.tsv").reject{|info| info.type == 'control' }.to_a

    peak_id = File.basename(sample_fn).split(".")[3]
    cycle = Integer(File.basename(sample_fn).split(".")[2].sub(/^Cycle/, ""))
    exp_info = experiment_infos.detect{|exp_info| exp_info.peak_id == peak_id }
    exp_filename = exp_info.raw_files.split(';').first
    sample_metadata = metadata.detect{|m| m.filenames.include?(exp_filename) }

    if sample_metadata
      puts self.gen_name(sample_metadata, sample_fn, processing_type: processing_type, slice_type: slice_type, extension: extension, cycle: cycle)
    end
  end
end

AffiseqPeaks.main
