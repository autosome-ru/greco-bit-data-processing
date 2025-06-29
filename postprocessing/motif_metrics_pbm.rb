require 'fileutils'

Signal.trap("PIPE", "EXIT")

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'
CMD_FOLDER = File.absolute_path(ARGV[2]) # './run_benchmarks_release_7/pwmbench_pbm'
FileUtils.mkdir_p(CMD_FOLDER)

ppms = Dir.glob("#{MOTIFS_PATH}/**/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/**/*.pcm")
motifs = [ppms, pcms].flatten.map{|fn| File.absolute_path(fn) }
motifs_by_tf = motifs.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}


FileUtils.mkdir_p './tmp/'

validation_datasets = [
  Dir.glob("#{DATA_PATH}/PBM.SD/Val_intensities/*"),
  Dir.glob("#{DATA_PATH}/PBM.QNZS/Val_intensities/*"),
  Dir.glob("#{DATA_PATH}/PBM.SDQN/Val_intensities/*"),
].flatten.map{|fn| File.absolute_path(fn) }

datasets_by_tf = validation_datasets.group_by{|fn|
  tf = File.basename(fn).split('.').first
  tf
}

tfs = motifs_by_tf.keys & datasets_by_tf.keys

File.open("#{CMD_FOLDER}/prepare_all.sh", 'w') do |fw|
  tfs.each{|tf|
    datasets_by_tf[tf].each{|dataset|
      dataset_bn = File.basename(dataset)
      dataset_txt = File.absolute_path("./tmp/#{dataset_bn}")
      cmd_1 = "cat #{dataset} | ruby #{__dir__}/extract_chip_sequences.rb --linker-length 6 > #{dataset_txt}"
      fw.puts(cmd_1)
    }
  }
end

container_names = []
tfs.each{|tf|
  tf_motifs_txt = File.absolute_path("./tmp/#{tf}.motifs.txt")
  File.open(tf_motifs_txt, 'w') do |fw|
    motifs_by_tf[tf].each{|motif|
      motif_rel = motif.sub(MOTIFS_PATH, "")
      fw.puts("/motifs/#{motif_rel}")
    }
  end

  datasets_by_tf[tf].each{|dataset|
    dataset_bn = File.basename(dataset)
    dataset_txt = File.absolute_path("./tmp/#{dataset_bn}")

    dataset_abs_fn = File.absolute_path(dataset)
    dataset_bn_id = dataset_bn.split('@').last.split('.')[1]

    container_name = "pwmbench_pbm.#{dataset_bn_id}"
    container_names << container_name

    File.open("#{CMD_FOLDER}/#{container_name}.sh", 'w') do |fw|
      cmd = [
        "cat #{tf_motifs_txt} | docker run --rm -i",  # we run /bin/sh and hangs it using `-d`, `-i` flags,
                                  # so that we can run other processes in the same container
            "--security-opt apparmor=unconfined",
            "--name #{container_name}",
            "--volume #{MOTIFS_PATH}:/motifs/:ro",
            "--volume #{dataset_txt}:/pbm_data/#{dataset_bn}:ro",
            "--env JAVA_OPTIONS=-Xmx2G",
            "vorontsovie/pwmbench_pbm:1.3.2",
            "ROC,PR", "/pbm_data/#{dataset_bn}", "-",
      ].join(" ")
      fw.puts("#{cmd} || echo")
    end
    File.chmod(0755, "#{CMD_FOLDER}/#{container_name}.sh")
  }
}

File.open("#{CMD_FOLDER}/run_all.sh", 'w') {|fw|
  container_names.each{|container_name|
    fw.puts "#{CMD_FOLDER}/#{container_name}.sh"
  }
}
