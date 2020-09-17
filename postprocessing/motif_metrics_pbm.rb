require 'fileutils'

Signal.trap("PIPE", "EXIT")

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


FileUtils.mkdir_p './tmp/'

# PBM

validation_datasets = [
  Dir.glob("#{DATA_PATH}/pbm/quantNorm_zscore/validation_intensities/*"),
  Dir.glob("#{DATA_PATH}/pbm/spatialDetrend_quantNorm/validation_intensities/*"),
].flatten.map{|fn| File.absolute_path(fn) }

datasets_by_tf = validation_datasets.group_by{|fn|
  tf = File.basename(fn).split('.').first
  TF_NAME_MAPPING.fetch(tf, tf)
}

tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  datasets_by_tf[tf].each{|dataset|
    dataset_bn = File.basename(dataset)
    dataset_txt = File.absolute_path("./tmp/#{dataset_bn}")

    cmd_1 = "cat #{dataset} | ruby extract_chip_sequences.rb --linker-length 6 > #{dataset_txt}"
    system(cmd_1)

    motifs_by_tf[tf].each{|motif|
      ext = File.extname(motif)
      cmd_2 = "echo -ne '#{dataset}\t#{motif}\t'; " \
        "docker run --rm " \
        " --security-opt apparmor=unconfined " \
        " --volume #{dataset_txt}:/pbm_data.txt:ro " \
        " --volume #{motif}:/motif#{ext}:ro " \
        " vorontsovie/pwmbench_pbm:1.2.1 " \
        " all /pbm_data.txt /motif#{ext} "
      puts cmd_2
    }
  }
}
