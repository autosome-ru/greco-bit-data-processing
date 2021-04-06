require 'json'
require_relative 'shared/lib/utils'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/plasmid_metadata'
require_relative 'shared/lib/random_names'
require_relative 'process_PBM/pbm_metadata'
require_relative 'process_reads_HTS_SMS_AFS/hts'

RELEASE_FOLDER = '/home_local/vorontsovie/greco-data/release_6.2021-02-13'
SOURCE_FOLDER = '/home_local/vorontsovie/greco-bit-data-processing/source_data'

module DatasetNameParser
  class BaseParser
    # {tf}.{construct_type}@{experiment_type}.{experiment_subtype}@{experiment_id}.{param1}.{param2}@{processing_type}.{uuid}.{slice_type}.{extension}
    def parse(fn)
      bn = File.basename(fn)
      tf_info, exp_type_info, exp_info, processing_type_uuid_etc = bn.split('@')
      tf, construct_type = tf_info.split('.')
      exp_type, exp_subtype = exp_type_info.split('.')
      exp_id, *exp_params = exp_info.split('.')
      processing_type, uuid, slice_type, extension = processing_type_uuid_etc.split('.')
      {
        dataset_name: bn,
        dataset_id: uuid, 
        tf: tf, construct_type: construct_type, 
        experiment_type: exp_type, experiment_subtype: exp_subtype,
        experiment_id: exp_id, experiment_params: exp_params,
        processing_type: processing_type,
        slice_type: slice_type, extension: extension,
      }
    end

    def parse_with_metadata(dataset_fn, metadata_by_experiment_id)
      dataset_info = self.parse(dataset_fn)
      experiment_id = dataset_info[:experiment_id]
      experiment_meta = metadata_by_experiment_id[ experiment_id ].to_h
      plasmid = $plasmid_by_number[ experiment_meta[:plasmid_id] ].to_h
      experiment_meta[:plasmid] = plasmid
      dataset_info[:experiment_meta] = experiment_meta
      dataset_info
    end
  end

  class PBMParser < BaseParser
    # {tf}.{construct_type}@PBM.{experiment_subtype}@{experiment_id}.5{flank_5}@{processing_type}.{uuid}.{slice_type}.{extension}
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
      }
      result
    end
  end

  class HTSParser < BaseParser
    # {tf}.{construct_type}@HTS.{experiment_subtype}@{experiment_id}.C{cycle}.5{flank_5}.3{flank_3}@{processing_type}.{uuid}.{slice_type}.{extension}
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
      }
      result
    end
  end
end

def collect_pbm_metadata(data_folder:, source_folder:)
  parser = DatasetNameParser::PBMParser.new
  metadata = PBM::SampleMetadata.each_in_file('source_data_meta/PBM/PBM.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  # MTERF3.DBD@PBM.ME@PBM13862.5GTGAAATTGTTATCCGCTCT@QNZS.pasty-rust-tang.Train.tsv
  dataset_files = ['Train', 'Val'].product(['intensities', 'sequences']).flat_map{|slice_type, outcome|
    Dir.glob("#{data_folder}/#{slice_type}_#{outcome}/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    experiment_meta = dataset_info[:experiment_meta]
    source_files = Dir.glob("#{source_folder}/#{experiment_meta[:pbm_assay_num]}_*").map{|fn|
      File.absolute_path(fn)
    }
    raise "No source files for dataset #{dataset_fn}"  if source_files.empty?
    dataset_info[:source_files] = source_files
    dataset_info
  }
end

def collect_hts_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  parser = DatasetNameParser::HTSParser.new
  metadata = Selex::SampleMetadata.each_in_file('source_data_meta/HTS/HTS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  # ZNF770.FL@HTS.Lys@AAT_A_GG40NGTGAGA.C3.5ACGACGCTCTTCCGATCTGG.3GTGAGAAGATCGGAAGAGCA@Reads.freaky-cyan-buffalo.Train.fastq.gz
  dataset_files = ['Train', 'Val'].flat_map{|slice_type|
    Dir.glob("#{data_folder}/#{slice_type}_reads/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    cycle = dataset_info[:experiment_params][:cycle]
    ds_basename = dataset_info[:experiment_meta][:"cycle_#{cycle}_filename"]
    # p dataset_info
    # p dataset_info[:experiment_meta]
    # p :"cycle_#{cycle}_filename"
    # p ds_basename
    ds_filename = File.absolute_path("#{source_folder}/#{ds_basename}")
    if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && allow_broken_symlinks))
      raise "Missing file #{ds_filename} for #{dataset_fn}"
    end
    dataset_info[:source_files] = [ds_filename]
    dataset_info
  }
end

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)


pbm_metadata_list = ['SDQN', 'QNZS'].flat_map{|processing_type|
  collect_pbm_metadata(
    data_folder: "#{RELEASE_FOLDER}/PBM.#{processing_type}/", 
    source_folder: "#{SOURCE_FOLDER}/PBM/chips/"
  )
}

hts_metadata_list = collect_hts_metadata(
  data_folder: "#{RELEASE_FOLDER}/HTS/",
  source_folder: "#{SOURCE_FOLDER}/HTS/reads/",
  allow_broken_symlinks: true
)

metadata_list = pbm_metadata_list + hts_metadata_list

metadata_list.each{|metadata|
  puts metadata.to_json
}
