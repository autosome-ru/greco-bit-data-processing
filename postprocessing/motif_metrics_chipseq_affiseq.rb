require 'fileutils'

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
    dataset_bn = File.basename(dataset)
    dataset_narrowPeak = File.absolute_path("./tmp/#{dataset_bn}")

    # 10-th column should be relative summit position
    cmd_1 = "cat #{dataset} | tail -n+2 | cut -d $'\\t' -f 1-9 | awk -F $'\\t' -e '{print $0 \"\\t\" ($4-$2)}' > #{dataset_narrowPeak}"
    system(cmd_1)

    motifs_by_tf[tf].each{|motif|
      ext = File.extname(motif)
      cmd_2 = "echo -ne '#{dataset}\t#{motif}\t'; " \
        "docker run --rm " \
        " --security-opt apparmor=unconfined " \
        " --volume #{ASSEMBLY_PATH}:/assembly/ " \
        " --volume #{dataset_narrowPeak}:/peaks.narrowPeak:ro " \
        " --volume #{motif}:/motif#{ext}:ro " \
        " vorontsovie/pwmeval_chipseq:1.0.2 " \
        "  --assembly-name hg38  --top 1000 "
      puts cmd_2
    }
  }
}
