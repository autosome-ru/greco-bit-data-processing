require 'optparse'
require_relative '../lib/utils'
require_relative '../lib/index_by'
require_relative '../lib/plasmid_metadata'
require_relative '../lib/random_names'
require_relative '../../process_peaks_CHS_AFS/experiment_info_afs'
require_relative '../lib/affiseq_metadata'

module AffiseqPeaks
#  Library after PCR (for Affiseq). This is what the TF sees
# ACACTCTTTCCCTACACGAC GCTCTTCCGATCT(Random Genomic fragment)AGATCGGAAGAGC ACACGTCTG AACTCCAG 3'
# TGTGAGAAAGGGATGTGCTG CGAGAAGGCTAGA(Random Genomic fragment)TCTAGCCTTCTCG TGTGCAGAC TTGAGGTC 5'
  ADAPTER_5 = 'ACACTCTTTCCCTACACGACGCTCTTCCGATCT'
  ADAPTER_3 = 'AGATCGGAAGAGCACACGTCTGAACTCCAG'


  def self.verify_sample_metadata_match!
    # samples = Dir.glob('results_databox_chs/train_intensities/*') # TODO: FIX !!!
    metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
    sample_metadata_pairs = full_join_by(
      samples, metadata,
      key_proc_1: ->(fn){ File.basename(fn).split('.')[1].sub(/_L\d+(\+L\d+)?$/, "").sub(/_[ACGT]{6}$/, "") }, # ToDo: FIX !!!
      key_proc_2: ->(m){ m.normalized_id }
    )

    sample_metadata_pairs.reject{|key, sample_fn, sample_metadata|
      sample_fn && sample_metadata
    }.each{|key, sample_fn, sample_metadata|
      puts(File.basename(sample_fn) + " has no metadata")  if sample_fn
      puts("no sample for metadata: #{sample_metadata}")   if sample_metadata
    }
  end

  def self.sample_basename(sample_metadata, cycle:, processing_type:)
    experiment_id = sample_metadata.experiment_id.gsub('.', '-')
    tf = sample_metadata.gene_name
    construct_type = sample_metadata.construct_type
    flank_5 = (ADAPTER_5 + '')[-20,20] # no inner barcodes are present
    flank_3 = ('' + ADAPTER_3)[0,20]
    "#{tf}.#{construct_type}@AFS.#{sample_metadata.ivt_or_lysate}@#{experiment_id}.C#{cycle}.5#{flank_5}.3#{flank_3}@#{processing_type}"
  end

  def self.generate_name(sample_metadata, sample_fn, processing_type:, slice_type:, extension:, cycle:, uuid: nil)
    basename = sample_basename(sample_metadata, cycle: cycle)
    uuid ||= take_dataset_name!
    "#{basename}.#{uuid}.#{slice_type}.#{extension}"
  end

  def self.find_names(folder, sample_metadata, processing_type:, slice_type:, extension:, cycle:)
    basename = sample_basename(sample_metadata, cycle: cycle, processing_type: processing_type)
    pattern = [basename.gsub('_', '{_,-}'), '*', slice_type, extension].compact.join('.')
    Dir.glob(File.join(folder, pattern))
  end

  def self.main
    slice_type = nil
    extension = nil
    processing_type = nil
    qc_filenames = []  # "#{__dir__}/../../source_data_meta/AFS/metrics_by_exp.tsv"
    has_slice_type = true
    uuid = nil
    mode = :generate
    folders = []
    argparser = OptionParser.new{|o|
      o.on('--slice-type VAL', 'Train or Val') {|v| slice_type = v }
      o.on('--processing-type VAL', 'Peaks or Reads') {|v| processing_type = v }
      o.on('--extension VAL', 'fa or peaks or fastq.gz') {|v| extension = v }
      o.on('--qc-file FILE', 'path to metrics_by_exp.tsv. Can be specified several times') {|v|
        raise "QC file #{v} not exists"  unless File.exists?(v)
        qc_filenames << v
      }
      o.on('--no-slice-type', 'slice type part is missing from input sample name') {|v| has_slice_type = false }
      o.on('--uuid VALUE', 'Specify fixed string instead of random UUID') {|v| uuid = v }
      o.on('--mode MODE', 'Specify mode: generate/find name (default: generate)') {|v|
        mode = v.downcase.to_sym
        raise  unless [:generate, :find].include?(mode)
      }
      o.on('--folder PATH', 'Specify folder to find samples (in `find` mode)') {|v|
        folders << v
      }
    }

    argparser.parse!(ARGV)
    sample_fn = ARGV[0]
    raise 'Specify processing type (Peaks or Reads)'  unless ['Peaks', 'Reads'].include?(processing_type)
    raise 'Specify slice type (Train or Val)'  if has_slice_type && !['Train', 'Val'].include?(slice_type)
    raise 'Specify extension (fa or peaks or fastq.gz)'  unless ['fa', 'peaks', 'fastq.gz'].include?(extension)
    raise 'Specify sample filename'  unless sample_fn
    raise 'Sample file not exists'  unless File.exist?(sample_fn)
    raise 'QC files not specified'  if qc_filenames.empty?
    raise 'Specify at least one folder'  if mode == :find && folders.empty?
    folders.each{|folder| # if folders are not specified, that's ok
      raise "Folder #{folder} doesn't exist"  if !File.exist?(folder)
      raise "Path #{folder} is not a folder"  if !File.directory?(folder)
    }


    plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
    $plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

    metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
    experiment_infos = qc_filenames.flat_map{|fn| ExperimentInfoAFS.each_from_file(fn, metadata).to_a }
    experiment_infos = experiment_infos.reject{|info| info.type == 'control' }.to_a

    peak_id = File.basename(sample_fn).split(".")[3]
    cycle = Integer(File.basename(sample_fn).split(".")[2].sub(/^Cycle/, ""))
    exp_info = experiment_infos.detect{|info| info.peak_id == peak_id }
    exp_filename = exp_info.raw_files.first
    exp_basename = File.basename(exp_filename)
    sample_metadata_variants = metadata.select{|m| m.supposed_filenames.include?(exp_basename) }
    if sample_metadata_variants.empty?
      sample_metadata = nil
    elsif sample_metadata_variants.size == 1
      sample_metadata = sample_metadata_variants[0]
    else
      raise "Several metadata variants for experiment `#{exp_basename}`:\n#{sample_metadata_variants.join("\n") }"
    end

    if sample_metadata
      case mode
      when :generate
        puts self.generate_name(sample_metadata, sample_fn, processing_type: processing_type, slice_type: slice_type, extension: extension, cycle: cycle, uuid: uuid)
      when :find
        names = folders.flat_map{|folder|
          self.find_names(folder, sample_metadata, slice_type: slice_type, processing_type: processing_type, extension: extension, cycle: cycle)
        }
        names.each{|name| puts name }
      else
        raise 'Unknown mode'
      end
    else
      $stderr.puts "Metadata for sample `#{sample_fn}` not found"
    end
  end
end

AffiseqPeaks.main  if __FILE__ == $0
