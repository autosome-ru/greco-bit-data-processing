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

## fix bug: different TF names for the same TF (e.g. CxxC4 --> CXXC4, zf-CXXC4 --> CXXC4)
TF_NAME_MAPPING = File.readlines('tf_name_mapping.txt').map{|l| l.chomp.split("\t") }.to_h

ppms = Dir.glob("#{MOTIFS_PATH}/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/*.pcm")
motifs = [ppms, pcms].flatten.map{|fn| File.absolute_path(fn) }
motifs_by_tf = motifs.group_by{|fn|
  tf = File.basename(fn).split('.').first
  TF_NAME_MAPPING.fetch(tf, tf)
}


FileUtils.mkdir_p './tmp/'

# SELEX

validation_datasets = [
  Dir.glob("#{DATA_PATH}/selex_IVT/results/validation_reads/*"),
  Dir.glob("#{DATA_PATH}/selex_Lysate/results/validation_reads/*"),
].flatten.map{|fn| File.absolute_path(fn) }

datasets_by_tf = validation_datasets.group_by{|fn|
  tf = File.basename(fn).split('.').first
  TF_NAME_MAPPING.fetch(tf, tf)
}

tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  tf_datasets = datasets_by_tf[tf]
  # concatenate cycles
  # e.g. ZNF997.Lysate.Cycle3.TA40NGTTAGC.BatchAATA.selex.val.fastq.gz
  dataset_groups = tf_datasets.group_by{|dataset|
    File.basename(dataset).sub(/\.Cycle\d+\./, '.AllCycles.')
  }
  dataset_groups.each{|grp, datasets|
    adapters = grp.split('.')[3]
    match = adapters.match(/^(?<flank_5>[ACGT]+)\d+N(?<flank_3>[ACGT]+)$/)
    flank_5 = ('ACACTCTTTCCCTACACGACGCTCTTCCGATCT' + match[:flank_5])[-20,20]
    flank_3 = (match[:flank_3] + 'AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC')[0,20]
    
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
        " vorontsovie/pwmeval_selex:1.0.0 " \
        " --seq-length 40 --non-redundant --top #{top_fraction} --bin 1000 " \
        " --pseudo-weight 0.0001 --flank-5 #{flank_5} --flank-3 #{flank_3} " \
        " --seed 1 "
      puts cmd_2
    }
  }
}
