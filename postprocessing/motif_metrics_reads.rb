require 'fileutils'
require 'optparse'

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
  # concatenate cycles
  # e.g. ZNF997.Lysate.Cycle3.TA40NGTTAGC.BatchAATA.selex.val.fastq.gz
  dataset_groups = tf_datasets.group_by{|dataset|
    File.basename(dataset).sub(/\.C\d+\./, '.AllCycles.')
  }
  dataset_groups.each{|grp, datasets|
    flank_5 = grp.match(/\.5(?<flank_5>[ACGT]+)[.@]/)[:flank_5]
    flank_3 = grp.match(/\.3(?<flank_3>[ACGT]+)[.@]/)[:flank_3]
    
    dataset_fq = File.absolute_path("./tmp/#{grp}")
    cmd_1 = "zcat #{datasets.join(' ')} | gzip -c > #{dataset_fq}"
    system(cmd_1)

    motifs_by_tf[tf].each{|motif|
      ext = File.extname(motif)
      cmd_2 = "echo -ne '#{grp}\t#{motif}\t'; " \
        "docker run --rm " \
        " --security-opt apparmor=unconfined " \
        " --volume #{dataset_fq}:/seq.fastq.gz:ro " \
        " --volume #{motif}:/motif#{ext}:ro " \
        " vorontsovie/pwmeval_selex:1.0.1 " \
        " --seq-length 40 --non-redundant --top #{top_fraction} --bin 1000 " \
        " --pseudo-weight 0.0001 --flank-5 #{flank_5} --flank-3 #{flank_3} " \
        " --seed 1 "
      puts cmd_2
    }
  }
}
