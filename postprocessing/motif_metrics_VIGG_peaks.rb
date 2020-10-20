require 'fileutils'
require 'shellwords'

Signal.trap("PIPE", "EXIT")

ASSEMBLY_PATH = '/home_local/vorontsovie/greco-processing/assembly/'
DATA_PATH = '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'

## fix bug: different TF names for the same TF (e.g. CxxC4 --> CXXC4, zf-CXXC4 --> CXXC4)
TF_NAME_MAPPING = File.readlines('tf_name_mapping.txt').map{|l| l.chomp.split("\t") }.to_h

ppms = Dir.glob('data/all_motifs/*.ppm')
pcms = Dir.glob('data/all_motifs/*.pcm')
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
        " --assembly-name hg38  --bed --peak-format 1,2,3,summit:abs:4; "
      puts cmd_2
    }
  }
}
