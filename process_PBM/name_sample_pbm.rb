require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'
require_relative '../shared/lib/random_names'
require_relative 'chip_probe'
require_relative 'pbm_metadata'

module PBM
  def self.sample_basename(sample_metadata, sample_fn, processing_type:)
    linker = Chip.from_file(sample_fn).linker_sequence
    adapter_5 = linker.size >= 20 ? linker[-20,20] : linker
    experiment_id = sample_metadata.experiment_id
    tf = sample_metadata.gene_id
    experiment_subtype = sample_metadata.chip_type
    construct_type = sample_metadata.construct_type
    "#{tf}.#{construct_type}@PBM.#{experiment_subtype}@#{experiment_id}.5#{adapter_5}@#{processing_type}"
  end

  def self.generate_name(sample_metadata, sample_fn, processing_type:, slice_type:, extension:)
    basename = sample_basename(sample_metadata, sample_fn, processing_type: processing_type)

    uuid = take_dataset_name!
    "#{basename}.#{uuid}.#{slice_type}.#{extension}"
  end


  def self.find_names(folder, sample_metadata, sample_fn, processing_type:, slice_type:, extension:)
    basename = sample_basename(sample_metadata, sample_fn, processing_type: processing_type)
    Dir.glob(File.join(folder, "#{basename}.*.#{slice_type}.#{extension}"))
  end

  def self.find_name(folder, sample_metadata, sample_fn, processing_type:, slice_type:, extension:)
    fns = find_names(folder, sample_metadata, sample_fn, processing_type: processing_type, slice_type: slice_type, extension: extension)
    if fns.size == 1
      File.basename(fns.first)
    else
      $stderr.puts "Can't choice a candidate from multiple variants: #{fns.join(', ')}"  if fns.size > 1
      nil
    end
  end

  def self.find_or_generate_name(folder, sample_metadata, sample_fn, processing_type:, slice_type:, extension:)
    basename = sample_basename(sample_metadata, sample_fn, processing_type: processing_type)

    fns = Dir.glob(File.join(folder, "#{basename}.*.#{slice_type}.#{extension}"))
    if fns.size == 1
      File.basename(fns.first)
    else
      $stderr.puts "Can't choice a candidate from multiple variants: #{fns.join(', ')}"  if fns.size > 1
      uuid = take_dataset_name!
      "#{basename}.#{uuid}.#{slice_type}.#{extension}"
    end
  end

  def self.main
    slice_type = nil
    extension = nil
    processing_type = nil
    source_mode = 'original'
    action = 'find-or-generate'
    lookup_folder = Dir.pwd
    argparser = OptionParser.new{|o|
      o.on('--source-mode VAL', 'original or normalized') {|v| source_mode = v }
      o.on('--slice-type VAL', 'Train or Val') {|v| slice_type = v }
      o.on('--extension VAL', 'fa or tsv') {|v| extension = v }
      o.on('--processing-type VAL', 'SDQN or QNZS') {|v| processing_type = v }
      o.on('--action VAL', 'find/find-or-generate/generate (default: find-or-generate)'){|v| action = v }
      o.on('--lookup-folder VAL', 'Folder used for find action'){|v| lookup_folder = v }
    }

    argparser.parse!(ARGV)

    chip_filename = ARGV[0]
    raise 'Specify slice type (Train or Val)'  unless ['Train', 'Val'].include?(slice_type)
    raise 'Specify extension (fa or tsv)'  unless ['fa', 'tsv'].include?(extension)
    raise 'Specify processing type (SDQN or QNZS)'  unless ['SD', 'SDQN', 'QNZS'].include?(processing_type)
    raise 'Source mode should be one of `original` or `normalized`'  unless ['original', 'normalized'].include?(source_mode)
    raise 'Action should be one of `find`, `generate`, `find-or-generate`'  unless ['find', 'generate', 'find-or-generate'].include?(action)
    raise 'Specify chip filename'  unless chip_filename
    raise 'Chip file not exists'  unless File.exist?(chip_filename)

    plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
    $plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

    metadata = PBM::SampleMetadata.each_in_file('source_data_meta/PBM/PBM.tsv').to_a

    if source_mode == 'original'
      assay_id = File.basename(chip_filename).split('_')[0]
      sample_metadata = metadata.detect{|m| m.pbm_assay_num == assay_id }
    elsif source_mode == 'normalized'
      experiment_id = File.basename(chip_filename).split('@')[2].split('.').first
      sample_metadata = metadata.detect{|m| m.experiment_id == experiment_id }
    end

    if sample_metadata
      kwargs = {slice_type: slice_type, extension: extension, processing_type: processing_type}
      case action
      when 'generate'
        resulting_fn = self.generate_name(sample_metadata, chip_filename, **kwargs)
      when 'find'
        resulting_fn = self.find_name(lookup_folder, sample_metadata, chip_filename, **kwargs)
      when 'find-or-generate'
        resulting_fn = self.find_or_generate_name(lookup_folder, sample_metadata, chip_filename, **kwargs)
      end
      puts resulting_fn
    end
  end
end

PBM.main
