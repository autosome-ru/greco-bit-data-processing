require 'fileutils'
require 'tempfile'
require_relative 'process_peaks_CHS_AFS/utils'
require_relative 'process_peaks_CHS_AFS/peak_preparation_utils'
require_relative 'process_peaks_CHS_AFS/experiment_info_extension'
require_relative 'process_peaks_CHS_AFS/experiment_info_chs'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/plasmid_metadata'
require_relative 'shared/lib/random_names'
require_relative 'process_peaks_CHS_AFS/chipseq_metadata'
require_relative 'process_peaks_CHS_AFS/naming_chs'

PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel', 'cpics', 'gem', 'sissrs']
MAIN_PEAK_CALLERS = ['macs2-pemode', 'macs2-nomodel']
SUPPLEMENTARY_PEAK_CALLERS = PEAK_CALLERS - MAIN_PEAK_CALLERS

SOURCE_FOLDER = './source_data/CHS/'
INTERMEDIATE_FOLDER = './results_databox_chs/complete_data'
RESULTS_FOLDER = './source_data_prepared/CHS'

experiment_infos = ExperimentInfoCHS.each_from_file("./source_data_meta/CHS/metrics_by_exp.tsv").reject{|info| info.type == 'control' }.to_a
experiment_infos.each{|info|
  info.confirmed_peaks_folder = INTERMEDIATE_FOLDER
}

tfs_at_start = experiment_infos.map(&:tf).uniq

raise 'Non-uniq peak ids'  unless experiment_infos.map(&:peak_id).uniq.size == experiment_infos.map(&:peak_id).uniq.size
experiment_by_peak_id = experiment_infos.map{|info| [info.peak_id, info] }.to_h

confirmed_peaks_mappings = experiment_infos.flat_map{|info|
  transformations = info.confirmed_peaks_transformations(
    source_folder: SOURCE_FOLDER,
    main_peak_callers: MAIN_PEAK_CALLERS,
    supplementary_peak_callers: SUPPLEMENTARY_PEAK_CALLERS,
  )
  transformations.map{|transformation|
    transformation.merge({experiment_info: info})
  }
}.compact; nil

tf_infos = experiment_infos.group_by(&:tf).map{|tf, infos|
  sorted_peaks_infos = infos.sort_by(&:num_confirmed_peaks).reverse
  best_peak_info = sorted_peaks_infos.first
  rest_peak_infos = sorted_peaks_infos.drop(1)
  {tf: tf, best_peak: best_peak_info, rest_peaks: rest_peak_infos}
}; nil

split_train_transformations = tf_infos.flat_map{|tf_info|
  transformations = split_train_val_transformations(tf_info, INTERMEDIATE_FOLDER)
  transformations.map{|transformation|
    transformation.merge({tf_info: tf_info})
  }
}; nil

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').to_a

def final_files_for_sample(sample_fn, all_metadata, results_folder, slice_type:)
  return []  unless sample_fn
  slice_type ||= Chipseq.determine_slice_type(sample_fn)
  data_file_id = File.basename(sample_fn).split('.')[1]
  normalized_id = data_file_id.sub(/_L\d+(\+L\d+)?$/, "").sub(/_\d_pf(\+\d_pf)?$/,"").sub(/_[ACGT]{6}$/, "")
  sample_metadata = all_metadata.detect{|m| m.normalized_id == normalized_id }
  if !sample_metadata
    $stderr.puts "No metadata for #{sample_fn}"  
    return []
  end
  [
    {
      filename: Chipseq.find_name("#{results_folder}/#{slice_type}_intervals", sample_metadata, slice_type: slice_type, extension: 'peaks'),
      type: 'intervals',
      slice_type: slice_type,
    },
    {
      sequences: Chipseq.find_name("#{results_folder}/#{slice_type}_sequences", sample_metadata, slice_type: slice_type, extension: 'fa'),
      type: 'sequences',
      slice_type: slice_type,
    },
  ]
end

final_files = split_train_transformations.flat_map{|transformation|
  [
    final_files_for_sample(transformation[:train_fn], metadata, RESULTS_FOLDER, slice_type: 'Train'),
    final_files_for_sample(transformation[:validation_fn], metadata, RESULTS_FOLDER, slice_type: 'Val')
  ].flatten(1).map{|files_info|
    files_info.merge(transformation: transformation)
  }
}.compact.select{|fn| fn[:filename] }


# confirmed_peaks_mappings.first.reject{|k,v| k == :supporting_intervals}
  # {:main_peaks_fn=>"./source_data/CHS//peaks-intervals/macs2-pemode/PEAKS990000.interval", 
  # :resulting_peaks_fn=>"./results_databox_chs/complete_data/AKAP8L.Plate_2_D8_S156.PEAKS990000.chipseq.interval", 
  # :tempfile_fn=>"PEAKS990000.supplementary_callers.bed", 
  # :experiment_info=>#<struct ExperimentInfoCHS 
  #     experiment_id="EXP990000", peak_id="PEAKS990000", tf="AKAP8L", 
  #     raw_files="/home_local/mihaialbu/Codebook/ChIPSeq_1/RawData/Plate_2_D8_S156_R1_001.fastq.gz;/home_local/mihaialbu/Codebook/ChIPSeq_1/RawData/Plate_2_D8_S156_R2_001.fastq.gz",
  #     peaks=["/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/macs2-nomodel/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/gem/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/sissrs/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/cpics/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/macs2-pemode/PEAKS990000.interval"], 
  #     type="paired_end", plate_id="Plate_2_D8_S156">}

# split_train_transformations.first
  #  => {:original_fn=>"./results_databox_chs/complete_data/AKAP8L.Plate_2_B8_S154.PEAKS990001.chipseq.interval",
  #   :train_fn=>"\"./results_databox_chs/complete_data\"/Train_intervals/AKAP8L.Plate_2_B8_S154.PEAKS990001.chipseq.train.interval",
  #   :validation_fn=>"\"./results_databox_chs/complete_data\"/Val_intervals/AKAP8L.Plate_2_B8_S154.PEAKS990001.chipseq.basic_val.interval",
  #   :tf_info => {
  #     :tf=>"AKAP8L", 
  #     :best_peak=>#<struct ExperimentInfoCHS experiment_id="EXP990001", peak_id="PEAKS990001", tf="AKAP8L", raw_files="/home_local/mihaialbu/Codebook/ChIPSeq_1/RawData/Plate_2_B8_S154_R1_001.fastq.gz;/home_local/mihaialbu/Codebook/ChIPSeq_1/RawData/Plate_2_B8_S154_R2_001.fastq.gz", peaks=["/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/macs2-nomodel/PEAKS990001.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/gem/PEAKS990001.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/sissrs/PEAKS990001.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/cpics/PEAKS990001.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/macs2-pemode/PEAKS990001.interval"], type="paired_end", plate_id="Plate_2_B8_S154">, 
  #     :rest_peaks=>[
  #       #<struct ExperimentInfoCHS experiment_id="EXP990000", peak_id="PEAKS990000", tf="AKAP8L", raw_files="/home_local/mihaialbu/Codebook/ChIPSeq_1/RawData/Plate_2_D8_S156_R1_001.fastq.gz;/home_local/mihaialbu/Codebook/ChIPSeq_1/RawData/Plate_2_D8_S156_R2_001.fastq.gz", peaks=["/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/macs2-nomodel/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/gem/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/sissrs/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/cpics/PEAKS990000.interval", "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/macs2-pemode/PEAKS990000.interval"], type="paired_end", plate_id="Plate_2_D8_S156">
  #     ]
  #   }
  # } 