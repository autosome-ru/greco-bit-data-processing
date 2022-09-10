require 'optparse'
require_relative '../shared/lib/utils'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'
require_relative '../shared/lib/random_names'
require_relative 'chipseq_metadata'

module Chipseq
  def self.gen_name(sample_metadata, slice_type:, extension:)
    experiment_id = sample_metadata.experiment_id
    tf = sample_metadata.gene_id
    construct_type = sample_metadata.construct_type
    basename = "#{tf}.#{construct_type}@CHS@#{experiment_id}@Peaks"

    uuid = take_dataset_name!
    "#{basename}.#{uuid}.#{slice_type}.#{extension}"
  end

  def self.sample_basename(sample_metadata, replica:)
    experiment_id = sample_metadata.experiment_id
    tf = sample_metadata.gene_id
    construct_type = sample_metadata.construct_type
    if replica
      if replica == :any
        "#{tf}.#{construct_type}@CHS@#{experiment_id}*@Peaks"
      else
        "#{tf}.#{construct_type}@CHS@#{experiment_id}.Rep-#{replica}@Peaks"
      end
    else
      "#{tf}.#{construct_type}@CHS@#{experiment_id}@Peaks"
    end
  end

  def self.generate_name(sample_metadata, slice_type:, extension:, replica:, uuid: nil)
    basename = sample_basename(sample_metadata, replica: replica)

    uuid ||= take_dataset_name!
    "#{basename}.#{uuid}.#{slice_type}.#{extension}"
  end

  def self.find_names(folder, sample_metadata, slice_type:, extension:, replica:)
    basename = sample_basename(sample_metadata, replica: replica)
    Dir.glob(File.join(folder, "#{basename}.*.#{slice_type}.#{extension}"))
  end

  def self.find_name(folder, sample_metadata, slice_type:, extension:, replica:)
    fns = find_names(folder, sample_metadata, slice_type: slice_type, extension: extension, replica: replica)
    if fns.size == 1
      fns.first
    else
      $stderr.puts "Can't choice a candidate from multiple variants: #{fns.join(', ')}"  if fns.size > 1
      nil
    end
  end

  def self.determine_slice_type(sample_fn)
    orig_slice_type = File.basename(sample_fn).split('.')[4]
    case orig_slice_type
    when 'train'
      'Train'
    when 'basic_val'
      # 'Val-B'
      'Val'
    when /^advanced_val/
      # 'Val-A'
      raise "Slice type `advanced_val` is reserved for a competition stage"
    else
      raise "Unknown slice type `#{orig_slice_type}` for `#{sample_fn}`"
    end
  end

  def self.main
    slice_type = nil
    extension = nil
    has_slice_type = true
    uuid = nil
    mode = :generate
    folder = nil
    argparser = OptionParser.new{|o|
      o.on('--slice-type VAL', 'Train or Val') {|v| slice_type = v }
      o.on('--extension VAL', 'fa or peaks') {|v| extension = v }
      o.on('--no-slice-type', 'slice type part is missing from input sample name') {|v| has_slice_type = false }
      o.on('--uuid VALUE', 'Specify fixed string instead of random UUID') {|v| uuid = v }
      o.on('--mode MODE', 'Specify mode: generate/find name (default: generate)') {|v|
        mode = v.downcase.to_sym
        raise  unless [:generate, :find].include?(mode)
      }
      o.on('--folder PATH', 'Specify folder to find samples (in `find` mode)') {|v|
        folder = v
      }
    }

    argparser.parse!(ARGV)
    sample_fn = ARGV[0]
    raise 'Specify slice type (Train / Val-B / Val-A)'  unless [nil, 'Train', 'Val-B', 'Val-A'].include?(slice_type)
    raise 'Specify extension (fa or peaks)'  unless ['fa', 'peaks'].include?(extension)
    raise 'Specify sample filename'  unless sample_fn
    raise 'Sample file not exists'  unless File.exist?(sample_fn)
    raise 'Specify folder'  if mode == :find && !folder
    raise "Folder #{folder} doesn't exist"  if folder && !File.exist?(folder)
    raise "Path #{folder} is not a folder"  if !File.directory?(folder)

    plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
    $plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

    metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').to_a

    slice_type ||= determine_slice_type(sample_fn)  if has_slice_type
    data_file_id, replica = File.basename(sample_fn).split('.')[1].split('@')
    normalized_id = data_file_id.sub(/_L\d+(\+L\d+)?$/, "").sub(/_\d_pf(\+\d_pf)?$/,"").sub(/_[ACGT]{6}$/, "").sub(/_S\d+$/, "")
    
    sample_metadata_variants = metadata.select{|m| m.normalized_id == normalized_id }
    if sample_metadata_variants.empty?
      sample_metadata = nil
    elsif sample_metadata_variants.size == 1
      sample_metadata = sample_metadata_variants[0]
    else
      raise "Several metadata variants for normalized_id `#{normalized_id}`:\n#{sample_metadata_variants.join("\n") }"
    end

    if sample_metadata
      case mode
      when :generate
        puts self.generate_name(sample_metadata, slice_type: slice_type, extension: extension, replica: replica, uuid: uuid)
      when :find
        names = self.find_names(folder, sample_metadata, slice_type: slice_type, extension: extension, replica: replica)
        names.each{|name| puts name }
      else
      end
    else
      $stderr.puts "Metadata for sample `#{sample_fn}` (normalized_id: `#{normalized_id}`) not found"
    end
  end
end
