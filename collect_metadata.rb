require 'json'
require_relative 'shared/lib/spo_cache'
require_relative 'shared/lib/dataset_counts'
require_relative 'shared/lib/dataset_name_parsers'
require_relative 'shared/lib/utils'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/plasmid_metadata'
require_relative 'shared/lib/insert_metadata'
require_relative 'shared/lib/random_names'
require_relative 'shared/lib/affiseq_metadata'
require_relative 'shared/lib/afs_peaks_biouml_meta'
require_relative 'shared/lib/affiseq_metadata_fetchers'
require_relative 'process_PBM/pbm_metadata'
require_relative 'process_reads_HTS_SMS_AFS/hts'
require_relative 'process_reads_HTS_SMS_AFS/sms_published'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'process_peaks_CHS_AFS/chipseq_metadata'
require_relative 'process_peaks_CHS_AFS/experiment_info_chs'
require_relative 'process_peaks_CHS_AFS/experiment_info_afs'

RELEASE_FOLDER = '/home_local/vorontsovie/greco-data/release_8c.2022-06-01/full'
SOURCE_FOLDER = '/home_local/vorontsovie/greco-bit-data-processing/source_data'
MYSQL_CONFIG = {host: 'localhost', username: 'vorontsovie', password: 'password'}

def collect_pbm_metadata(data_folder:, source_folder:)
  parser = DatasetNameParser::PBMParser.new
  metadata = PBM::SampleMetadata.each_in_file('source_data_meta/PBM/PBM.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

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
    dataset_info[:source_files] = source_files.map{|fn| {filename: fn, type: 'source'} }

    dataset_bn = File.basename(dataset_fn, '.gz')
    dataset_ext = File.extname(dataset_bn)
    if ['.fastq', '.fasta', '.fa', '.fq'].include?(dataset_ext)
      dataset_info[:stats] = {num_sequences: num_reads(dataset_fn)} # here are sequences, not reads
    elsif dataset_ext == '.tsv'
      dataset_info[:stats] = {num_probes: num_probes(dataset_fn), num_good_probes: num_good_probes(dataset_fn)}
    else
      raise "Unknown type of dataset `#{dataset_fn}`"
    end
    dataset_info
  }
end

def collect_hts_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  parser = DatasetNameParser::HTSParser.new
  metadata = Selex::SampleMetadata.each_in_file('source_data_meta/HTS/HTS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  dataset_files = ['Train', 'Val'].flat_map{|slice_type|
    Dir.glob("#{data_folder}/#{slice_type}_reads/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    cycle = dataset_info[:experiment_params][:cycle]
    ds_basename = dataset_info[:experiment_meta][:"cycle_#{cycle}_filename"]
    ds_filename = File.absolute_path("#{source_folder}/#{ds_basename}")
    if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && allow_broken_symlinks))
      raise "Missing file #{ds_filename} for #{dataset_fn}"
    end
    dataset_info[:source_files] = [ds_filename].map{|fn| {filename: fn, coverage: num_reads(fn), type: 'source'} }
    dataset_info[:stats] = {num_reads: num_reads(dataset_fn)}
    dataset_info
  }
end

def collect_sms_published_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  parser = DatasetNameParser::SMSParser.new
  metadata = SMSPublished::SampleMetadata.each_in_file('source_data_meta/SMS/published/SMS_published.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  dataset_files = ['Train', 'Val'].flat_map{|slice_type|
    Dir.glob("#{data_folder}/#{slice_type}_reads/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    # ds_basename = dataset_info[:experiment_meta][:"cycle_#{cycle}_filename"]
    ds_filename = Dir.glob("#{source_folder}/#{dataset_info[:experiment_id]}_*").take_the_only
    ds_filename = File.absolute_path(ds_filename)
    if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && allow_broken_symlinks))
      raise "Missing file #{ds_filename} for #{dataset_fn}"
    end
    dataset_info[:source_files] = [ds_filename].map{|fn| {filename: fn, coverage: num_reads(fn), type: 'source'} }
    dataset_info[:stats] = {num_reads: num_reads(dataset_fn)}
    dataset_info
  }
end

def collect_sms_unpublished_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  parser = DatasetNameParser::SMSParser.new
  metadata = SMSUnpublished::SampleMetadata.each_in_file('source_data_meta/SMS/unpublished/SMS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  dataset_files = ['Train', 'Val'].flat_map{|slice_type|
    Dir.glob("#{data_folder}/#{slice_type}_reads/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    exp_id = dataset_info[:experiment_id].split('-')[0,2].join('-')
    experiment_meta = dataset_info[:experiment_meta]
    ssid = experiment_meta[:ssid]
    barcode = experiment_meta[:barcode_index]
    barcode = "BC%02d" % barcode.match(/^BC(?<number>\d+)$/)[:number]
    # p "#{source_folder}/#{exp_id}_*_#{ssid}_#{barcode}.fastq"
    exp_id_guess = exp_id.sub('UT380-','UT380*')
    ssid_guess = ssid.sub(/SS(\d+)/, 'S*\1')
    ds_filename = Dir.glob("#{source_folder}/#{exp_id_guess}_*_#{ssid_guess}_#{barcode}.fastq").take_the_only
    ds_filename = File.absolute_path(ds_filename)
    if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && allow_broken_symlinks))
      raise "Missing file #{ds_filename} for #{dataset_fn}"
    end
    dataset_info[:source_files] = [ds_filename].map{|fn| {filename: fn, coverage: num_reads(fn), type: 'source'} }
    dataset_info[:stats] = {num_reads: num_reads(dataset_fn)}
    dataset_info
  }
end

def source_file_candidates_by_basename(glob)
  all_source_files = Dir.glob(glob).map{|fn|
    File.symlink?(fn) ? File.readlink(fn) : fn
  }.map{|fn|
    File.absolute_path(fn)
  }.uniq

  all_source_files.uniq.group_by{|fn| File.basename(fn) }
end

def collect_chs_metadata(data_folder:, source_folder:, metrics_fns:, allow_broken_symlinks: false)
  parser = DatasetNameParser::CHSParser.new
  metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  experiment_infos = metrics_fns.flat_map{|metrics_fn|
    ExperimentInfoCHS.each_from_file(metrics_fn).reject{|info|
      info.type == 'control'
    }.to_a
  }
  experiment_infos.each{|info|
    info.confirmed_peaks_folder = "./results_databox_chs/complete_data"
  }
  experiment_by_plate_id = experiment_infos.index_by{|info|
    info.normalized_id
  }
  # raise 'Non-uniq peak ids'  unless experiment_infos.map(&:peak_id).uniq.size == experiment_infos.map(&:peak_id).uniq.size
  # experiment_by_peak_id = experiment_infos.map{|info| [info.peak_id, info] }.to_h


  dataset_files = ['Train', 'Val'].product(['intervals', 'sequences']).flat_map{|slice_type, outcome|
    Dir.glob("#{data_folder}/#{slice_type}_#{outcome}/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    plate_id = dataset_info[:experiment_meta][:_original_meta].normalized_id
    replica = dataset_info[:experiment_params][:replica]
    normalized_id = [plate_id, replica].compact.join('-')
    exp_info = experiment_by_plate_id[normalized_id].to_h
    reads_files = ((exp_info && exp_info[:raw_files]) || []).map{|fn|
      if !File.exist?(fn)
        if (fn.start_with?('DIANA') || fn.start_with?('MICHELLE')) && File.exist?("/mnt/space/hughes/Feb2021/#{fn}")
          fn = "/mnt/space/hughes/Feb2021/#{fn}"
        else
          filename_candidates = $source_files_by_basename[File.basename(fn)]
          fn = filename_candidates[0]  if filename_candidates && filename_candidates.size == 1
        end
      end
      # $stderr.puts "Source file #{fn} for CHS not found"  unless File.exist?(fn)
      {filename: fn, coverage: num_reads(fn), type: 'source'}
    }
    peaks_files  = exp_info.fetch(:peaks, []).flat_map{|peak_id|
      Dir.glob("source_data/CHS/peaks-intervals/*/#{peak_id}.interval").map{|fn|
        {filename: fn, num_peaks: num_peaks(fn), type: 'intermediate'}
      }
    }
    dataset_info[:source_files] = reads_files + peaks_files
    dataset_info[:experiment_info] = exp_info

    dataset_bn = File.basename(dataset_fn, '.gz')
    dataset_ext = File.extname(dataset_bn)
    if ['.fastq', '.fasta', '.fa', '.fq'].include?(dataset_ext)
      dataset_info[:stats] = {num_sequences: num_reads(dataset_fn)} # here are sequences, not reads
    elsif dataset_ext == '.peaks'
      dataset_info[:stats] = {num_peaks: num_peaks(dataset_fn)}
    else
      raise "Unknown type of dataset `#{dataset_fn}`"
    end
    dataset_info
  }
end

def afs_read_files_info(exp_info)
  original_files = ((exp_info && exp_info[:raw_files]) || [])
  original_files.map{|fn|
    # Dir.glob("/mnt/space/hughes/June1st2021/**/#{fn}").first || File.join('/mnt/space/hughes/June1st2021/SELEX_RawData/Phase1/', fn)
    $source_files_by_basename[ File.basename(fn) ]
    filename_candidates = $source_files_by_basename[File.basename(fn)]
    if filename_candidates && filename_candidates.size == 1
      filename_candidates[0]
    else
      $stderr.puts "Can't choose a candidate file for #{fn}"
      fn
    end
  }.map{|fn|
    {filename: fn, coverage: num_reads(fn), type: 'source'}
  }
end

def afs_peaks_files_info(exp_info)
  peak_id = exp_info[:peak_id]
  Dir.glob("source_data/AFS/peaks-intervals/*/#{peak_id}.interval").map{|fn|
    {filename: fn, num_peaks: num_peaks(fn), type: 'intermediate'}
  }
end

def afs_peak_reads_info(exp_info, read_fn_fetcher)
  return []  unless read_fn_fetcher
  exp_id = exp_info[:experiment_id]
  read_fn_fetcher.fetch_validated_abspaths!(exp_id).map{|fn|
    {filename: fn, coverage: num_reads(fn), type: 'intermediate'}
  }
end

def collect_afs_metadata(dataset_name_parser:, data_folder:, outcome_types:, fetchers: [])
  metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  dataset_files = ['Train', 'Val'].product(outcome_types).flat_map{|slice_type, outcome|
    Dir.glob("#{data_folder}/#{slice_type}_#{outcome}/*")
  }

  dataset_infos = dataset_files.map{|dataset_fn|
    dataset_info = dataset_name_parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)

    appropriate_fetchers = fetchers.select{|fetcher| fetcher[:experiment_info_fetcher].fetch(dataset_info) }
    if appropriate_fetchers.size == 1
      [dataset_fn, dataset_info, appropriate_fetchers.take_the_only]
    else
      $stderr.puts "Error: Can't choose a single fetcher for dataset `#{dataset_fn}`. Instead there were #{appropriate_fetchers.size} fetchers"
      nil
    end
  }.compact

  dataset_infos.map{|dataset_fn, dataset_info, fetcher|
    exp_info = fetcher[:experiment_info_fetcher].fetch(dataset_info)
    dataset_info[:experiment_info] = exp_info
    dataset_info[:source_files] = [
      *afs_read_files_info(exp_info),
      *afs_peaks_files_info(exp_info),
      *afs_peak_reads_info(exp_info, fetcher[:read_filenames_fetcher]),
    ]

    dataset_bn = File.basename(dataset_fn, '.gz')
    dataset_ext = File.extname(dataset_bn)
    if ['.fastq', '.fasta', '.fa', '.fq'].include?(dataset_ext)
      dataset_info[:stats] = {num_reads: num_reads(dataset_fn)}
    elsif dataset_ext == '.peaks'
      dataset_info[:stats] = {num_peaks: num_peaks(dataset_fn)}
    else
      raise "Unknown type of dataset `#{dataset_fn}`"
    end
    dataset_info
  }
end

$source_files_by_basename = source_file_candidates_by_basename('/mnt/space/hughes/**/*')

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

insert_metadata = InsertMetadata.each_in_file('source_data_meta/shared/Inserts.tsv').to_a
raise 'Non-unique plasmid ids for inserts'  if insert_metadata.map(&:plasmid_numbers).flatten.yield_self{|vs| vs.size != vs.uniq.size }
$insert_by_plasmid_id = insert_metadata.flat_map{|insert|
  insert.plasmid_numbers.map{|plasmid_id| [plasmid_id, insert] }
}.to_h
$inserts_by_insert_id = insert_metadata.group_by(&:insert_id)

$stderr.puts "loaded meta"

pbm_metadata_list = ['SD', 'QNZS'].flat_map{|processing_type|
  collect_pbm_metadata(
    data_folder: "#{RELEASE_FOLDER}/PBM.#{processing_type}/",
    source_folder: "#{SOURCE_FOLDER}/PBM/chips/"
  )
}

$stderr.puts "loaded PBM"

hts_metadata_list = collect_hts_metadata(
  data_folder: "#{RELEASE_FOLDER}/HTS/",
  source_folder: "#{SOURCE_FOLDER}/HTS/reads/",
  allow_broken_symlinks: true
)

$stderr.puts "loaded HTS"

chs_metadata_list = collect_chs_metadata(
  data_folder: "#{RELEASE_FOLDER}/CHS/",
  source_folder: "#{SOURCE_FOLDER}/CHS/",
  metrics_fns: [
    "source_data_meta/CHS/metrics_by_exp.tsv",
    "source_data_meta/CHS/metrics_by_exp_chipseq_feb2021.tsv",
    "source_data_meta/CHS/metrics_by_exp_chipseq_jun2021.tsv",
    "source_data_meta/CHS/metrics_by_exp_chipseq_apr2022.tsv",
  ],
  allow_broken_symlinks: true
)

$stderr.puts "loaded CHS"

sms_published_metadata_list = collect_sms_published_metadata(
  data_folder: "#{RELEASE_FOLDER}/SMS.published/",
  source_folder: "#{SOURCE_FOLDER}/SMS/reads/published",
  allow_broken_symlinks: true
)

$stderr.puts "loaded SMS.published"

sms_unpublished_metadata_list = collect_sms_unpublished_metadata(
  data_folder: "#{RELEASE_FOLDER}/SMS/",
  source_folder: "#{SOURCE_FOLDER}/SMS/reads/unpublished",
  allow_broken_symlinks: true
)

$stderr.puts "loaded SMS"

afs_metrics_fetcher_1 = ExperimentInfoAFSFetcherPack1.load('source_data_meta/AFS/metrics_by_exp.tsv')
afs_metrics_fetcher_2 = ExperimentInfoAFSFetcherPack2.load(
                          'source_data_meta/AFS/metrics_by_exp_affseq_jun2021.tsv',
                          MYSQL_CONFIG.merge({database: 'greco_affiseq_jun2021'})
                        )
afs_metrics_fetcher_3 = ExperimentInfoAFSFetcherPack2.load(
                          'source_data_meta/AFS/metrics_by_exp_affseq_apr2022.tsv',
                          MYSQL_CONFIG.merge({database: 'greco_affiseq_apr2022'})
                        )

afs_read_fn_fetcher_1 = ReadFilenamesFetcher.load(
                          MYSQL_CONFIG.merge({database: 'greco_affyseq'}),
                          source_folder: "#{SOURCE_FOLDER}/AFS/trimmed",
                          allow_broken_symlinks: true,
                        )
afs_read_fn_fetcher_2 = ReadFilenamesFetcher.load(
                          MYSQL_CONFIG.merge({database: 'greco_affiseq_jun2021'}),
                          source_folder: "#{SOURCE_FOLDER}/AFS/trimmed",
                          allow_broken_symlinks: true,
                        )
afs_read_fn_fetcher_3 = ReadFilenamesFetcher.load(
                          MYSQL_CONFIG.merge({database: 'greco_affiseq_apr2022'}),
                          source_folder: "#{SOURCE_FOLDER}/AFS/trimmed",
                          allow_broken_symlinks: true,
                        )
$stderr.puts "loaded AFS fetchers"

afs_peaks_metadata_list = collect_afs_metadata(
  dataset_name_parser: DatasetNameParser::AFSPeaksParser.new,
  data_folder: "#{RELEASE_FOLDER}/AFS.Peaks",
  outcome_types: ['intervals', 'sequences'],
  fetchers: [
    { experiment_info_fetcher: afs_metrics_fetcher_1, read_filenames_fetcher: nil },
    { experiment_info_fetcher: afs_metrics_fetcher_2, read_filenames_fetcher: nil },
    { experiment_info_fetcher: afs_metrics_fetcher_3, read_filenames_fetcher: nil },
  ],
)

$stderr.puts "loaded AFS.Peaks"

afs_reads_metadata_list = collect_afs_metadata(
  dataset_name_parser: DatasetNameParser::AFSReadsParser.new,
  data_folder: "#{RELEASE_FOLDER}/AFS.Reads",
  outcome_types: ['sequences'],
  fetchers: [
    { experiment_info_fetcher: afs_metrics_fetcher_1, read_filenames_fetcher: afs_read_fn_fetcher_1 },
    { experiment_info_fetcher: afs_metrics_fetcher_2, read_filenames_fetcher: afs_read_fn_fetcher_2 },
    { experiment_info_fetcher: afs_metrics_fetcher_3, read_filenames_fetcher: afs_read_fn_fetcher_3 },
  ],
)

$stderr.puts "loaded AFS.Reads"

metadata_list = pbm_metadata_list + hts_metadata_list + chs_metadata_list + sms_published_metadata_list + sms_unpublished_metadata_list + afs_peaks_metadata_list + afs_reads_metadata_list
metadata_list.each{|info|
  info[:experiment_meta].delete(:_original_meta)
  info[:source_files].each{|data|
    data[:filename] = File.readlink(data[:filename])  if File.symlink?(data[:filename])
    data[:filename] = File.absolute_path(data[:filename])
    $stderr.puts("File #{data} not found") unless File.exist?(data[:filename])
  }
}

metadata_list.each{|metadata|
  puts metadata.to_json
}
