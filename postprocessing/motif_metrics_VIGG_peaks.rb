require 'fileutils'
require 'shellwords'

Signal.trap("PIPE", "EXIT")

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'
ASSEMBLY_PATH = '/home_local/vorontsovie/greco-processing/assembly/'

## fix bug: different TF names for the same TF (e.g. CxxC4 --> CXXC4, zf-CXXC4 --> CXXC4)
TF_NAME_MAPPING = File.readlines('tf_name_mapping.txt').map{|l| l.chomp.split("\t") }.to_h

ppms = Dir.glob("#{MOTIFS_PATH}/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/*.pcm")
motifs = [ppms, pcms].flatten.map{|fn| File.absolute_path(fn) }
motifs_by_tf = motifs.group_by{|fn|
  tf = File.basename(fn).split('.').first
  TF_NAME_MAPPING.fetch(tf, tf)
}


FileUtils.mkdir_p './assembly/'
FileUtils.mkdir_p './tmp/'

# affiseq + chipseq

validation_datasets = [
  Dir.glob("#{DATA_PATH}/chipseq/results/validation_intervals/*"),
  Dir.glob("#{DATA_PATH}/affiseq_IVT/results/validation_intervals/*"),
  Dir.glob("#{DATA_PATH}/affiseq_Lysate/results/validation_intervals/*"),
].flatten.map{|fn| File.absolute_path(fn) }

datasets_by_tf = validation_datasets.group_by{|fn|
  tf = File.basename(fn).split('.').first
  TF_NAME_MAPPING.fetch(tf, tf)
}

tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  datasets_by_tf[tf].each{|dataset|
    motifs_by_tf[tf].each{|motif|
      ext = File.extname(motif)
      cmd_2 = "echo -ne #{dataset.shellescape}'\\t'#{motif.shellescape}'\\t'; " \
        "docker run --rm " \
        " --security-opt apparmor=unconfined " \
        " --volume #{ASSEMBLY_PATH.shellescape}:/assembly " \
        " --volume #{dataset.shellescape}:/peaks:ro " \
        " --volume #{motif.shellescape}:/motif#{ext}:ro " \
        " vorontsovie/motif_pseudo_roc:v2.0.0 " \
        " --assembly-name hg38 --peak-format 1,2,3,summit:abs:4; "
      puts cmd_2
    }
  }
}
