require 'fileutils'

Signal.trap("PIPE", "EXIT")

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'
CMD_FOLDER = File.absolute_path(ARGV[2]) # './run_benchmarks_release_7/pwmeval_chipseq'
ASSEMBLY_PATH = '/home_local/vorontsovie/greco-processing/assembly/'

FileUtils.mkdir_p(CMD_FOLDER)

ppms = Dir.glob("#{MOTIFS_PATH}/**/*.ppm")
pcms = Dir.glob("#{MOTIFS_PATH}/**/*.pcm")
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
conv_to_narrowPeak_script = File.absolute_path('conv_to_narrowPeak.sh', __dir__)

container_names = []
tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  datasets_by_tf[tf].each{|dataset|
    dataset_abs_fn = File.absolute_path(dataset)
    dataset_bn = File.basename(dataset).split('@').last.split('.')[1]

    container_name = "pwmeval_chipseq.#{dataset_bn}"
    container_names << container_name
    File.open("#{CMD_FOLDER}/#{container_name}.sh", 'w') do |fw|
      cmd_1 = [
        "docker run --rm -d -i",  # we run /bin/sh and hangs it using `-d`, `-i` flags,
                                  # so that we can run other processes in the same container
            "--security-opt apparmor=unconfined",
            "--name #{container_name}",
            "--volume #{ASSEMBLY_PATH}:/assembly/:ro",
            "--volume #{MOTIFS_PATH}:/motifs:ro",
            "--volume #{dataset_abs_fn}:/peaks.interval:ro",
            "--volume #{conv_to_narrowPeak_script}:/app/conv_to_narrowPeak.sh:ro",
            "vorontsovie/pwmeval_chipseq:1.1.1",
                "/bin/sh",
        " >&2", # don't print container id into stdout
      ].join(" ")
      fw.puts(cmd_1)

      # 10-th column should be relative summit position
      # '"'"' means close open single-quoted string, concatenate with string "'" denoting single quote, and open single-quoted string again
      cmd_2 = "docker exec #{container_name} sh -c '/app/conv_to_narrowPeak.sh /peaks.interval > /peaks.narrowPeak'"
      fw.puts(cmd_2)

      cmd_3 = [
        "docker exec #{container_name} prepare",
            "--peaks /peaks.narrowPeak",
            "--assembly-name hg38",
            "--top 1000",
            "--positive-file /sequences/positive.fa", # It's more effective to use non-gzipped files
            "--negative-file /sequences/negative.fa",
      ].join(' ')
      fw.puts(cmd_3)


      motifs_by_tf[tf].each{|motif|
        ext = File.extname(motif)
        motif_rel = motif.sub(MOTIFS_PATH, "")
        cmd_4 = [
          "echo -ne '#{dataset}\t#{motif}\t'; ",
          "docker exec #{container_name} evaluate",
            "--motif /motifs/#{motif_rel}",
            "--positive-file /sequences/positive.fa",
            "--negative-file /sequences/negative.fa",
            "--json",
          " || echo",
        ].join(' ')
        fw.puts cmd_4
      }

      cmd_5 = "docker stop #{container_name} >&2" # don't print container id into stdout
      fw.puts cmd_5
    end
    File.chmod(0755, "#{CMD_FOLDER}/#{container_name}.sh")
  }
}

File.open("#{CMD_FOLDER}/run_all.sh", 'w') {|fw|
  container_names.each{|container_name|
    fw.puts "#{CMD_FOLDER}/#{container_name}.sh"
  }
}
