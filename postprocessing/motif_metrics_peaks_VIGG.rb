require 'fileutils'
require 'shellwords'

Signal.trap("PIPE", "EXIT")

DATA_PATH = File.absolute_path(ARGV[0]) # '/home_local/vorontsovie/greco-data/release_3.2020-08-08/'
MOTIFS_PATH = File.absolute_path(ARGV[1]) # 'data/all_motifs'
CMD_FOLDER = File.absolute_path(ARGV[2]) # './run_benchmarks_release_7/viggroc'
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

container_names = []
tfs = motifs_by_tf.keys & datasets_by_tf.keys
tfs.each{|tf|
  datasets_by_tf[tf].each{|dataset|
    dataset_abs_fn = File.absolute_path(dataset)
    dataset_bn = File.basename(dataset).split('@').last.split('.')[1]

    container_name = "motif_pseudo_roc.#{dataset_bn}"
    container_names << container_name
    File.open("#{CMD_FOLDER}/#{container_name}.sh", 'w') do |fw|
      cmd_1 = [
        "docker run --rm -d -i",  # we run /bin/sh and hangs it using `-d`, `-i` flags,
                                  # so that we can run other processes in the same container
            "--security-opt apparmor=unconfined",
            "--name #{container_name}",
            "--volume #{ASSEMBLY_PATH}:/assembly/:ro",
            "--volume #{MOTIFS_PATH}:/motifs/:ro",
            "--volume #{dataset_abs_fn}:/peaks:ro",
            "vorontsovie/motif_pseudo_roc:2.1.0",
                "/bin/sh",
        " >&2", # don't print container id into stdout
      ].join(" ")
      fw.puts(cmd_1)

      cmd_2 = [
        "docker exec #{container_name} prepare",
            "--peaks /peaks",
            "--assembly-name hg38",
            "--top 1000",
            "--positive-file /sequences/positive.fa",
            "--store-background /background.txt"
      ].join(' ')
      fw.puts(cmd_2)


      motifs_by_tf[tf].each{|motif|
        ext = File.extname(motif)
        motif_rel = motif.sub(MOTIFS_PATH, "")
        cmd_3 = [
          "echo -ne '#{dataset}\t#{motif}\t'; ",
          "docker exec #{container_name} evaluate",
            "--motif /motifs/#{motif_rel}",
            "--positive-file /sequences/positive.fa",
            "--background file:/background.txt",
          " || echo",
        ].join(' ')
        fw.puts cmd_3
      }

      cmd_5 = "docker stop #{container_name} >&2" # don't print container id into stdout
      fw.puts cmd_5
    end
    File.chmod(0755, "#{CMD_FOLDER}/#{container_name}.sh")
  }
}
