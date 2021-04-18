require 'fileutils'

Signal.trap("PIPE", "EXIT")

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'
ASSEMBLY_PATH = '/home_local/vorontsovie/greco-processing/assembly/'

ppms = Dir.glob("#{MOTIFS_PATH}/**/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/**/*.pcm")
motifs = [ppms, pcms].flatten.map{|fn| File.absolute_path(fn) }
motifs_by_tf = motifs.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}

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
      ext = File.extname(motif)
      cmd = "echo -ne '#{dataset}\t#{motif}\t'; " \
        "docker run --rm " \
        " --security-opt apparmor=unconfined " \
        " --volume #{ASSEMBLY_PATH}:/assembly/ " \
        " --volume #{dataset}:/peaks.narrowPeak:ro " \
        " --volume #{motif}:/motif#{ext}:ro " \
        " vorontsovie/centrimo_bench:1.1.1 " \
        "  --assembly-name hg38 " \
        "  --peak-format 1,2,3,summit:abs:4 " \
        "  --json " \
        "  || echo"
      puts cmd
    }
  }
}
