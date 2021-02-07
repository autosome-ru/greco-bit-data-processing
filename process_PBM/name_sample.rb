require 'optparse'
require_relative '../shared/lib/index_by'
require_relative '../shared/lib/plasmid_metadata'
require_relative '../shared/lib/random_names'
require_relative 'chip_probe'

PBMSampleMetadata = Struct.new(*[
      :experiment_id, :chip_type, :plasmid_id,
      :gene_id, :date, :qc, :notes, :data_file_name, :pbm_assay_num
    ], keyword_init: true) do

  def experiment_subtype; chip_type; end
  def experiment_type; "PBM.#{experiment_subtype}"; end
  def construct_type; $plasmid_by_number[plasmid_id].construct_type; end

  def self.from_string(line)
    # Example:
    ## Experiment UNIQID (PBM ID)  ME/HK Plasmid ID  Gene ID Date  QC  Notes Data file name  PBM assay no
    ## PBM13817  ME  pTH13911  KDM5B 2018-11-13  Reject    2018-11-13_252207110444_S02_R0_GA1_Cy5  13817
    experiment_id, chip_type, plasmid_id, gene_id, date, qc, notes, data_file_name, pbm_assay_num = line.chomp.split("\t")
    self.new(
      experiment_id: experiment_id, chip_type: chip_type, plasmid_id: plasmid_id,
      gene_id: gene_id, date: date, qc: qc, notes: notes,
      data_file_name: data_file_name, pbm_assay_num: pbm_assay_num,
    )
  end

  def self.each_in_file(filename)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.readlines(filename).drop(1).map{|line|
      yield self.from_string(line)
    }
  end
end

def verify_sample_metadata_match!
  samples = Dir.glob('source_data/PBM/chips/*.txt')
  sample_metadata_pairs = full_join_by(
    samples, metadata,
    key_proc_1: ->(fn){ File.basename(fn).split('_').first },
    key_proc_2: ->(m){ m.pbm_assay_num }
  )

  sample_metadata_pairs.reject{|key, sample_fn, sample_metadata|
    sample_fn && sample_metadata
  }.each{|key, sample_fn, sample_metadata|
    puts(File.basename(sample_fn) + " has no metadata")  if sample_fn
    puts("no sample for metadata: #{sample_metadata}")   if sample_metadata
  }
end

def gen_name(sample_metadata, sample_fn, slice_type:, extension:, processing_type:)
  linker = Chip.from_file(sample_fn).linker_sequence
  adapter_5 = linker.size >= 20 ? linker[-20,20] : linker
  experiment_id = sample_metadata.experiment_id
  tf = sample_metadata.gene_id
  experiment_subtype = sample_metadata.chip_type
  construct_type = sample_metadata.construct_type
  basename = "#{tf}.#{construct_type}@PBM.#{experiment_subtype}@#{experiment_id}.5#{adapter_5}"

  uuid = take_dataset_name!
  "#{basename}@#{processing_type}.#{uuid}.#{slice_type}.#{extension}"
end

slice_type = nil
extension = nil
processing_type = nil
argparser = OptionParser.new{|o|
  o.on('--slice-type VAL', 'Train or Val') {|v| slice_type = v }
  o.on('--extension VAL', 'fa or tsv') {|v| extension = v }
  o.on('--processing-type VAL', 'SDQN or QNZS') {|v| processing_type = v }
}

argparser.parse!(ARGV)
chip_filename = ARGV[0]
raise 'Specify slice type (Train or Val)'  unless ['Train', 'Val'].include?(slice_type)
raise 'Specify extension (fa or tsv)'  unless ['fa', 'tsv'].include?(extension)
raise 'Specify processing type (SDQN or QNZS)'  unless ['SDQN', 'QNZS'].include?(processing_type)
raise 'Specify chip filename'  unless chip_filename
raise 'Chip file not exists'  unless File.exist?(chip_filename)

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

metadata = PBMSampleMetadata.each_in_file('source_data_meta/PBM/PBM.tsv').to_a

assay_id = File.basename(chip_filename).split('_')[0]
sample_metadata = metadata.detect{|m| m.pbm_assay_num == assay_id }
puts gen_name(sample_metadata, chip_filename, slice_type: slice_type, extension: extension, processing_type: processing_type)
