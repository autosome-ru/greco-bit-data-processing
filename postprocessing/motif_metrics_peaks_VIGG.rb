require 'fileutils'
require 'shellwords'

Signal.trap("PIPE", "EXIT")

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'
ASSEMBLY_PATH = '/home_local/vorontsovie/greco-processing/assembly/'

ppms = Dir.glob("#{MOTIFS_PATH}/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/*.pcm")
motifs = [ppms, pcms].flatten.map{|fn| File.absolute_path(fn) }
motifs_by_tf = motifs.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}


FileUtils.mkdir_p './assembly/'
FileUtils.mkdir_p './tmp/'

validation_datasets = [
  Dir.glob("#{DATA_PATH}/CHS/Val_intervals/*"),
  Dir.glob("#{DATA_PATH}/AFS.Peaks/Val_intervals/*"),
].flatten.map{|fn| File.absolute_path(fn) }

datasets_by_tf = validation_datasets.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}

tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  datasets_by_tf[tf].each{|dataset|
    motifs_by_tf[tf].each{|motif|
      cmd = "./run_vigg_metrics.sh #{dataset.shellescape} #{motif.shellescape} #{ASSEMBLY_PATH.shellescape} hg38"
      puts cmd
    }
  }
}
