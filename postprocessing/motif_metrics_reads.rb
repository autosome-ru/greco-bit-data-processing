require 'fileutils'
require 'optparse'
require_relative '../shared/lib/utils'

Signal.trap("PIPE", "EXIT")

top_fraction = 0.1
option_parser = OptionParser.new{|opts|
  opts.on('--fraction X', "Take top X sequences"){|val|
    top_fraction = Float(val)
  }
}

option_parser.parse!(ARGV)

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'

ppms = Dir.glob("#{MOTIFS_PATH}/**/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/**/*.pcm")
motifs = [ppms, pcms].flatten.map{|fn| File.absolute_path(fn) }
motifs_by_tf = motifs.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}


FileUtils.mkdir_p './tmp/'

validation_datasets = [
  Dir.glob("#{DATA_PATH}/HTS/Val_reads/*"),
  Dir.glob("#{DATA_PATH}/AFS.Reads/Val_reads/*"),
  Dir.glob("#{DATA_PATH}/SMS/Val_reads/*"),
  Dir.glob("#{DATA_PATH}/SMS.published/Val_reads/*"),
].flatten.map{|fn| File.absolute_path(fn) }

datasets_by_tf = validation_datasets.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}

tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  tf_datasets = datasets_by_tf[tf]
  # concatenate cycles of the same experiment
  # e.g. AHCTF1.DBD@HTS.IVT@YWC_B_GG40NCGTAGT.C1.5ACGACGCTCTTCCGATCTGG.3CGTAGTAGATCGGAAGAGCA@Reads.chummy-taupe-coati.Val.fastq.gz
  dataset_groups = tf_datasets.group_by{|dataset|
    bn = File.basename(dataset)
    tf_info, exp_type, exp_info, ds_info = bn.split('@')
    exp_id, *rest = exp_info.split('.')
    rest_wo_cycle = rest.reject{|f| f.match? /^C\d$/ }
    [tf_info, exp_type, [exp_id, *rest_wo_cycle].join('.'), ].join('@')
  }
  dataset_groups.each{|grp, datasets|
    _grp_tf_info, _grp_exp_type, grp_exp_info = grp.split('@')
    _grp_exp_id, *grp_rest = grp_exp_info.split('.')
    flank_5 = grp_rest.select{|f| f.match? /^5[ACGT]+$/ }.take_the_only[1..-1]
    flank_3 = grp_rest.select{|f| f.match? /^3[ACGT]+$/ }.take_the_only[1..-1]

    dataset_infos = datasets.map{|dataset|
      bn = File.basename(dataset)
      _tf_info, _exp_type, exp_info, ds_info = bn.split('@')
      _exp_id, *rest = exp_info.split('.')
      cycles = rest.select{|f| f.match? /^C\d$/ }
      ds_id = ds_info.split('.')[1]
      {cycles: cycles, dataset_id: ds_id}
    }.sort_by{|info| Integer(info[:cycle][1..-1]) }
    
    cycles = dataset_infos.flat_map{|info| info[:cycles] }.join('+')
    dataset_ids = dataset_infos.map{|info| info[:dataset_id] }.join('+')

    joined_data_fn = "#{grp}.#{cycles}@Reads.#{dataset_ids}.Val.fastq.gz"

    dataset_fq = File.absolute_path("./tmp/#{joined_data_fn}")
    cmd_1 = "zcat #{datasets.join(' ')} | gzip -c > #{joined_data_fn}"
    system(cmd_1)

    motifs_by_tf[tf].each{|motif|
      ext = File.extname(motif)
      cmd_2 = "echo -ne '#{grp}\t#{motif}\t'; " \
        "docker run --rm " \
        " --security-opt apparmor=unconfined " \
        " --volume #{dataset_fq}:/seq.fastq.gz:ro " \
        " --volume #{motif}:/motif#{ext}:ro " \
        " vorontsovie/pwmeval_selex:1.0.1 " \
        " --non-redundant --top #{top_fraction} --bin 1000 " \
        " --pseudo-weight 0.0001 --flank-5 #{flank_5} --flank-3 #{flank_3} " \
        " --seed 1 || echo"
      puts cmd_2
    }
  }
}
