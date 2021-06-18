require 'json'
require 'sqlite3'
require_relative 'shared/lib/utils'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/plasmid_metadata'
require_relative 'shared/lib/insert_metadata'
require_relative 'shared/lib/random_names'
require_relative 'shared/lib/affiseq_metadata'
require_relative 'shared/lib/afs_peaks_biouml_meta'
require_relative 'process_PBM/pbm_metadata'
require_relative 'process_reads_HTS_SMS_AFS/hts'
require_relative 'process_reads_HTS_SMS_AFS/sms_published'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'process_peaks_CHS_AFS/chipseq_metadata'
require_relative 'process_peaks_CHS_AFS/experiment_info_chs'
require_relative 'process_peaks_CHS_AFS/experiment_info_afs'

RELEASE_FOLDER = '/home_local/vorontsovie/greco-data/release_6.2021-02-13'
SOURCE_FOLDER = '/home_local/vorontsovie/greco-bit-data-processing/source_data'
MYSQL_CONFIG = {host: 'localhost', username: 'vorontsovie', password: 'password', database: 'greco_affyseq'}

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
      experiment_meta = metadata_by_experiment_id[ experiment_id ]
      experiment_meta = experiment_meta.to_h.merge(_original_meta: experiment_meta)
      if experiment_meta.has_key?(:plasmid_id)
        plasmid_id = experiment_meta[:plasmid_id]
        plasmid = $plasmid_by_number[ plasmid_id ].to_h
        insert = $insert_by_plasmid_id[ plasmid_id ]
        plasmid[:insert] = insert.to_h
        experiment_meta[:plasmid] = plasmid
      elsif experiment_meta.has_key?(:insert_id)
        insert_id = experiment_meta[:insert_id]
        inserts = $inserts_by_insert_id[ insert_id ] || []
        keys = inserts.map(&:to_h).flat_map(&:keys).uniq
        joint_insert = keys.map{|k|
          v = inserts.map{|insert| insert[k] }.uniq.join('; ')
          [k,v]
        }.to_h
        experiment_meta[:plasmid] = {insert: joint_insert}
      end
      dataset_info[:experiment_meta] = experiment_meta
      dataset_info
    end
  end

  class PBMParser < BaseParser
    # {tf}.{construct_type}@PBM.{experiment_subtype}@{experiment_id}.5{flank_5}@{processing_type}.{uuid}.{slice_type}.{extension}
    # MTERF3.DBD@PBM.ME@PBM13862.5GTGAAATTGTTATCCGCTCT@QNZS.pasty-rust-tang.Train.tsv
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
    # {tf}.{construct_type}@HTS.{experiment_subtype}@{experiment_id}.C{cycle}.5{flank_5}.3{flank_3}@Reads.{uuid}.{slice_type}.{extension}
    # ZNF770.FL@HTS.Lys@AAT_A_GG40NGTGAGA.C3.5ACGACGCTCTTCCGATCTGG.3GTGAGAAGATCGGAAGAGCA@Reads.freaky-cyan-buffalo.Train.fastq.gz
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
      }
      result
    end
  end

  class CHSParser < BaseParser
    # {tf}.{construct_type}@CHS@{experiment_id}@Peaks.{uuid}.{slice_type}.{extension}
    # C11orf95.FL@CHS@THC_0197@Peaks.sunny-celadon-boar.Train.peaks
    def parse(fn)
      result = super(fn)
      result[:experiment_params] = { }
      result
    end
  end

  class SMSParser < BaseParser
    # {tf}.{construct_type}@SMS@{experiment_id}@Reads.{uuid}.{slice_type}.{extension}
    # AHCTF1.DBD@SMS@UT380-009.5TAAGAGACAGCGTATGAATC.3CTGTCTCTTATACACATCTC@Reads.wiggy-alizarin-albatross.Train.fastq.gz
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
      }
      result
    end
  end

  class AFSReadsParser < BaseParser
    # {tf}.{construct_type}@AFS.{experiment_subtype}@{experiment_id}@Reads.{uuid}.{slice_type}.{extension}
    # GLI4.DBD@AFS.IVT@AATBA_AffSeq_A9_GLI4.C1.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC@Reads.greasy-lilac-clam.Train.fastq.gz
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
      }
      result
    end
  end

  class AFSPeaksParser < BaseParser
    # {tf}.{construct_type}@AFS.{experiment_subtype}@{experiment_id}@Peaks.{uuid}.{slice_type}.{extension}
    # ZFP3.FL@AFS.Lys@AATA_AffSeq_E5_ZFP3.C3@Peaks.nerdy-razzmatazz-cichlid.Train.peaks
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
      }
      result
    end
  end
end

def create_spo_cache(db_filename)
  db ||= SQLite3::Database.new(db_filename)
  db.execute(<<-EOS
    CREATE TABLE IF NOT EXISTS spo_store(id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT, property TEXT, json_value TEXT);
    CREATE UNIQUE INDEX IF NOT EXISTS sp_uniq ON spo_store(entity, property);
    EOS
  )
  db
end

def store_to_spo_cache(s,p,o)
  @spo_db ||= create_spo_cache('dataset_stats_spo_cache.db')
  @spo_db.execute("INSERT INTO spo_store(entity, property, json_value) VALUES (?,?,?)", [s,p,JSON.dump(o)] )
end

def load_from_spo_cache(s,p)
  @spo_db ||= create_spo_cache('dataset_stats_spo_cache.db')
  json_o, = @spo_db.execute("SELECT json_value FROM spo_store WHERE s = ? AND p = ?", [s,p])
  json_o ? JSON.parse(json_o) : nil
end

def num_reads(filename)
  return nil  if !File.exist?(filename)
  return cached_result  if cached_result = load_spo_cache(filename, 'num_reads')
  ext = File.extname(File.basename(filename, '.gz'))
  if ['.fastq', '.fq'].include?(ext)
    result = `./seqkit fq2fa #{filename} -w 0 | fgrep --count '>'`
    result = Integer(result)
    store_to_spo_cache(filename, 'num_reads', result)
    result
  else
    result = `./seqkit seq #{filename} -w 0 | fgrep --count '>'`
    result = Integer(result)
    store_to_spo_cache(filename, 'num_reads', result)
    result
  end
rescue
  nil
end

def num_peaks(filename)
  return nil  if !File.exist?(filename)
  File.readlines(filename).map(&:strip).reject{|l| l.start_with?('#') }.reject(&:empty?).count
rescue
  nil
end

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
    ds_filename = Dir.glob("#{source_folder}/#{exp_id}_*_#{ssid}_#{barcode}.fastq").take_the_only
    ds_filename = File.absolute_path(ds_filename)
    if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && allow_broken_symlinks))
      raise "Missing file #{ds_filename} for #{dataset_fn}"
    end
    dataset_info[:source_files] = [ds_filename].map{|fn| {filename: fn, coverage: num_reads(fn), type: 'source'} }
    dataset_info
  }
end

def collect_chs_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  parser = DatasetNameParser::CHSParser.new
  metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  experiment_infos = ExperimentInfoCHS.each_from_file("source_data_meta/CHS/metrics_by_exp.tsv").reject{|info|
    info.type == 'control'
  }.to_a
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
    exp_info = experiment_by_plate_id[plate_id].to_h
    reads_files = ((exp_info && exp_info[:raw_files]) || '').split(';').map{|fn|
      {filename: fn, coverage: num_reads(fn), type: 'source'}
    }
    peaks_files  = exp_info.fetch(:peaks, []).map{|fn|
      {filename: fn, num_peaks: num_peaks(fn), type: 'intermediate'}
    }
    dataset_info[:source_files] = reads_files + peaks_files
    dataset_info[:experiment_info] = exp_info
    dataset_info
  }
end

def collect_afs_peaks_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  parser = DatasetNameParser::AFSPeaksParser.new
  metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  experiment_infos = ExperimentInfoAFS.each_from_file("source_data_meta/AFS/metrics_by_exp.tsv").reject{|info|
    info.type == 'control'
  }.to_a
  experiment_infos.each{|info|
    info.confirmed_peaks_folder = "./results_databox_afs_#{info.type}/complete_data"
  }

  # keys like ["GLI4", "Lys", "Cycle1"]
  experiment_by_tf_and_cycle = experiment_infos.index_by{|exp|
    [exp.tf, exp.type[0,3], exp.cycle_number]
  }

  dataset_files = ['Train', 'Val'].product(['intervals', 'sequences']).flat_map{|slice_type, outcome|
    Dir.glob("#{data_folder}/#{slice_type}_#{outcome}/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    exp_key = dataset_info.yield_self{|d| [d[:tf], d[:experiment_subtype], "Cycle#{d[:experiment_params][:cycle]}"] }
    exp_info = experiment_by_tf_and_cycle[exp_key].to_h
    original_files = ((exp_info && exp_info[:raw_files]) || '').split(';')
    original_files = original_files.map{|fn| File.join('/mnt/space/hughes/June1st2021/SELEX_RawData/Phase1/', fn) }

    reads_files = original_files.map{|fn|
      {filename: fn, coverage: num_reads(fn), type: 'source'}
    }

    peak_id = exp_info[:peak_id]
    peaks_files  = Dir.glob("/home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval/*/#{peak_id}.interval").map{|fn|
      {filename: fn, num_peaks: num_peaks(fn), type: 'intermediate'}
    }
    dataset_info[:source_files] = reads_files + peaks_files
    dataset_info[:experiment_info] = exp_info
    dataset_info
  }
end

def collect_afs_reads_metadata(data_folder:, source_folder:, allow_broken_symlinks: false)
  client = Mysql2::Client.new(MYSQL_CONFIG)

  records = get_experiment_infos(client)
  experiments, alignment_by_experiment, reads_by_experiment = infos_by_alignment(records)

  parser = DatasetNameParser::AFSReadsParser.new
  metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
  metadata_by_experiment_id = metadata.index_by(&:experiment_id)

  experiment_infos = ExperimentInfoAFS.each_from_file("source_data_meta/AFS/metrics_by_exp.tsv").reject{|info|
    info.type == 'control'
  }.to_a
  experiment_infos.each{|info|
    info.confirmed_peaks_folder = "./results_databox_afs_#{info.type}/complete_data"
  }

  # keys like ["GLI4", "Lys", "Cycle1"]
  experiment_by_tf_and_cycle = experiment_infos.index_by{|exp|
    [exp.tf, exp.type[0,3], exp.cycle_number]
  }

  dataset_files = ['Train', 'Val'].flat_map{|slice_type|
    Dir.glob("#{data_folder}/#{slice_type}_reads/*")
  }
  dataset_files.map{|dataset_fn|
    dataset_info = parser.parse_with_metadata(dataset_fn, metadata_by_experiment_id)
    cycle = dataset_info[:experiment_params][:cycle]
    ds_basename = dataset_info[:experiment_meta][:"cycle_#{cycle}_filename"]

    exp_key = dataset_info.yield_self{|d| [d[:tf], d[:experiment_subtype], "Cycle#{d[:experiment_params][:cycle]}"] }
    exp_info = experiment_by_tf_and_cycle[exp_key].to_h
    exp_id = exp_info[:experiment_id]
    reads_fns = reads_by_experiment[exp_id]

    original_files = ((exp_info && exp_info[:raw_files]) || '').split(';')
    original_files = original_files.map{|fn| File.join('/mnt/space/hughes/June1st2021/SELEX_RawData/Phase1/', fn) }

    peak_reads_files = reads_fns.map{|reads_fn|
      ds_filename = File.absolute_path("#{source_folder}/#{reads_fn}.fastq.gz")
      if ! (File.exist?(ds_filename) || (File.symlink?(ds_filename) && allow_broken_symlinks))
        raise "Missing file #{ds_filename} for #{dataset_fn}"
      end
      ds_filename
    }.map{|fn|
      {filename: fn, coverage: num_reads(fn), type: 'intermediate'}
    }
    # dataset_info[:source_files] = {peak_files: peak_files, original_files: original_files, type: 'source'}

    reads_files = original_files.map{|fn|
      {filename: fn, coverage: num_reads(fn), type: 'source'}
    }

    peak_id = exp_info[:peak_id]
    peaks_files  = Dir.glob("/home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval/*/#{peak_id}.interval").map{|fn|
      {filename: fn, num_peaks: num_peaks(fn), type: 'intermediate'}
    }
    dataset_info[:source_files] = reads_files + peaks_files + peak_reads_files
    dataset_info[:experiment_info] = exp_info

    dataset_info
  }
end

plasmids_metadata = PlasmidMetadata.each_in_file('source_data_meta/shared/Plasmids.tsv').to_a
$plasmid_by_number = plasmids_metadata.index_by(&:plasmid_number)

insert_metadata = InsertMetadata.each_in_file('source_data_meta/shared/Inserts.tsv').to_a
raise 'Non-unique plasmid ids for inserts'  if insert_metadata.map(&:plasmid_numbers).flatten.yield_self{|vs| vs.size != vs.uniq.size }
$insert_by_plasmid_id = insert_metadata.flat_map{|insert|
  insert.plasmid_numbers.map{|plasmid_id| [plasmid_id, insert] }
}.to_h
$inserts_by_insert_id = insert_metadata.group_by(&:insert_id)


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

chs_metadata_list = collect_chs_metadata(
  data_folder: "#{RELEASE_FOLDER}/CHS/",
  source_folder: "#{SOURCE_FOLDER}/CHS/",
  allow_broken_symlinks: true
)

sms_published_metadata_list = collect_sms_published_metadata(
  data_folder: "#{RELEASE_FOLDER}/SMS.published/",
  source_folder: "#{SOURCE_FOLDER}/SMS/reads/published",
  allow_broken_symlinks: true
)

sms_unpublished_metadata_list = collect_sms_unpublished_metadata(
  data_folder: "#{RELEASE_FOLDER}/SMS/",
  source_folder: "#{SOURCE_FOLDER}/SMS/reads/unpublished",
  allow_broken_symlinks: true
)

afs_peaks_metadata_list = collect_afs_peaks_metadata(
  data_folder: "#{RELEASE_FOLDER}/AFS.Peaks",
  source_folder: "#{SOURCE_FOLDER}/AFS",
  allow_broken_symlinks: true
)

afs_reads_metadata_list = collect_afs_reads_metadata(
  data_folder: "#{RELEASE_FOLDER}/AFS.Reads",
  source_folder: "#{SOURCE_FOLDER}/AFS/fastq",
  allow_broken_symlinks: true
)

metadata_list = pbm_metadata_list + hts_metadata_list + chs_metadata_list + sms_published_metadata_list + sms_unpublished_metadata_list + afs_peaks_metadata_list + afs_reads_metadata_list
metadata_list = metadata_list.map{|info| info.reject{|k,v| k == :_original_meta } }

metadata_list.each{|metadata|
  puts metadata.to_json
}
