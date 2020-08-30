require 'fileutils'

def basename_wo_ext(fn)
  File.basename(fn, File.extname(fn))
end

def rename_motif(src_filename, dst_filename, transpose: false)
  new_motif_name = basename_wo_ext(dst_filename)
  lines = File.readlines(src_filename).map(&:chomp)
  if lines[0].start_with?('>')
    old_header = lines[0]
    lines.shift
    old_name, additional_info = old_header[1..-1].strip.split(/\s+/, 2)
    header = ">#{new_motif_name} #{additional_info}"
  else
    header = ">#{new_motif_name}"
  end

  if transpose
    lines = lines.map{|l| l.split }.transpose.map{|r| r.join("\t") }
  end

  File.open(dst_filename, 'w') {|fw|
    fw.puts header
    fw.puts lines.join("\n")
  }
end

# filename = ARGV[0]
# new_filename = ARGV[1]

results_folder = '/home_local/vorontsovie/greco-motifs/release_3_motifs_2020-08-30'
FileUtils.mkdir_p(results_folder)
['pbm', 'chipseq', 'affiseq_IVT', 'affiseq_Lysate', 'selex_IVT', 'selex_Lysate'].each{|dataset_type|
  ['pcm', 'ppm'].each{|motif_type|
    FileUtils.mkdir_p("#{results_folder}/#{dataset_type}/#{motif_type}")
    FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/#{motif_type}/")
  }
}

['pbm', 'chipseq', 'affiseq_IVT', 'affiseq_Lysate', 'selex_IVT', 'selex_Lysate'].each{|dataset_type|
  FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/ppm/mihaialbu/")
}

['pbm', 'chipseq', 'affiseq_IVT', 'affiseq_Lysate'].each{|dataset_type|
  FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/ppm/jangrau/")
}

['selex_IVT', 'selex_Lysate'].each{|dataset_type|
  FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/ppm/pbucher/")
  FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/pcm/arsen_l/") # philipp's protocol reimplementation
  FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/ppm/ajolma/")  # arsen_l splitted ajolma motifs from a single file
}

['chipseq', 'affiseq_IVT', 'affiseq_Lysate'].each{|dataset_type|
  FileUtils.mkdir_p("#{results_folder}/source_data/#{dataset_type}/pcm/pavelkrav/")
}

FileUtils.mkdir_p("#{results_folder}/source_data/pbm/pcm/vorontsovie/")

###################

# Here files are ok
Dir.glob("/home_local/jangrau/ppms/chipseq/*.ppm").each{|fn|
  dst_bn = File.basename(fn).sub('Dimont', 'Dimont@Halle')
  rename_motif(fn, "#{results_folder}/chipseq/ppm/#{dst_bn}")
  rename_motif(fn, "#{results_folder}/source_data/chipseq/ppm/jangrau/#{dst_bn}")
}

Dir.glob("/home_local/jangrau/ppms/affiseq_IVT/*.ppm").each{|fn|
  dst_bn = File.basename(fn).sub('Dimont', 'Dimont@Halle')
  rename_motif(fn, "#{results_folder}/affiseq_IVT/ppm/#{dst_bn}")
  rename_motif(fn, "#{results_folder}/source_data/affiseq_IVT/ppm/jangrau/#{dst_bn}")
}
Dir.glob("/home_local/jangrau/ppms/affiseq_Lysate/*.ppm").each{|fn|
  dst_bn = File.basename(fn).sub('Dimont', 'Dimont@Halle')
  rename_motif(fn, "#{results_folder}/affiseq_Lysate/ppm/#{dst_bn}")
  rename_motif(fn, "#{results_folder}/source_data/affiseq_Lysate/ppm/jangrau/#{dst_bn}")
}

# missing suffix {spatialDetrend_quantNorm,quantNorm_zscore} of pbm preprocessing subtype (came from an error in previous version of source files)
['spatialDetrend_quantNorm', 'quantNorm_zscore'].each do |pbm_subtype|
  Dir.glob("/home_local/jangrau/ppms/pbm/#{pbm_subtype}/*.pbm.train.*.ppm").each{|fn|
    dst_bn = File.basename(fn).sub('Dimont', 'Dimont@Halle').sub('.pbm.', ".#{pbm_subtype}.pbm.")
    rename_motif(fn, "#{results_folder}/pbm/ppm/#{dst_bn}")
    rename_motif(fn, "#{results_folder}/source_data/pbm/ppm/jangrau/#{dst_bn}")
  }
end

# These are ok too
['spatialDetrend_quantNorm', 'quantNorm_zscore'].each do |pbm_subtype|
  Dir.glob("/home_local/vorontsovie/greco_pbm/release_3_motifs/#{pbm_subtype}/pcms/*.pcm").each{|fn|
    dst_bn = File.basename(fn).sub('chipmunk', 'ChIPMunk@VIGG')
    rename_motif(fn, "#{results_folder}/pbm/pcm/#{dst_bn}")
    rename_motif(fn, "#{results_folder}/source_data/pbm/pcm/vorontsovie/#{dst_bn}")
  }
end

# model names contain dots, replace with underscores
['selex_IVT', 'selex_Lysate'].each{|selex_type|
  Dir.glob("/home_local/pbucher/ppms/#{selex_type}/*.train.*.ppm").each{|fn|
    bn = basename_wo_ext(fn)
    m = bn.match(/^(?<prefix>.*)\.selex\.train\.meme\.(?<model_name>.+)$/)
    model_name = m[:model_name].split('.').join('_')
    dst_bn = "#{m[:prefix]}.selex.train.MEME@SIB.#{model_name}.ppm"
    rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/#{dst_bn}")
    rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/pbucher/#{dst_bn}")
  }
}

# transpose matrix, fix header
Dir.glob("/home_local/pavelkrav/pcms/chipseq/*.train.*.pcm").each{|fn|
  # ZNF35.IVT.Cycle3.PEAKS991110.affiseq.train.unified.109seq_25to7_m1.pcm
  dst_bn = File.basename(fn).sub('unified', 'ChIPMunk@VIGG')
  rename_motif(fn, "#{results_folder}/chipseq/pcm/#{dst_bn}", transpose: true)
  rename_motif(fn, "#{results_folder}/source_data/chipseq/pcm/pavelkrav/#{dst_bn}", transpose: true)
}

['affiseq_Lysate', 'affiseq_IVT'].each do |affiseq_type|
  Dir.glob("/home_local/pavelkrav/pcms/affiseq/#{affiseq_type}/*.train.*.pcm").each{|fn|
    dst_bn = File.basename(fn).sub('unified', 'ChIPMunk@VIGG')
    rename_motif(fn, "#{results_folder}/#{affiseq_type}/pcm/#{dst_bn}", transpose: true)
    rename_motif(fn, "#{results_folder}/source_data/#{affiseq_type}/pcm/pavelkrav/#{dst_bn}", transpose: true)
  }
end

# no separation of selex_IVT/selex_Lysate
# no separation of tool and model name
Dir.glob("/home_local/arsen_l/greco-bit/motifs/selex/pcms/*.train.*.pcm").each{|fn|
  bn = File.basename(fn)
  case bn.split('.')[1]
  when 'IVT'
    selex_type = 'selex_IVT'
  when 'Lysate'
    selex_type = 'selex_Lysate'
  else
    raise
  end
  rename_motif(fn, "#{results_folder}/#{selex_type}/pcm/#{bn}")
  rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/pcm/arsen_l/#{bn}")
}

# no separation of selex_IVT/selex_Lysate
# no separation of tool and model name
Dir.glob("/home_local/arsen_l/greco-bit/motifs/ajolma/ppms/*.train.*.ppm").each{|fn|
  bn = File.basename(fn)
  m = bn.match(/^(?<prefix>.*)\.selex\.train\.seqAjolmaAutoseed_(?<model_name>.+).ppm$/)
    if m[:prefix].include?('.IVT.')
    selex_type = 'selex_IVT'
  elsif m[:prefix].include?('.Lysate.')
    selex_type = 'selex_Lysate'
  else
    raise
  end
  dst_bn = "#{m[:prefix]}.selex.train.Autoseed@Codebook.#{m[:model_name]}.ppm"
  rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/#{dst_bn}")
  rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/ajolma/#{dst_bn}")
}

# no model name
Dir.glob("/home_local/mihaialbu/Codebook/ppms/pbm/*.train.Zscore.ppm").each{|fn| # here .val. motifs also exist
  bn = File.basename(fn)
  dst_bn = bn.sub('Zscore', 'PBMZscore@Codebook.model1')
  rename_motif(fn, "#{results_folder}/pbm/ppm/#{dst_bn}")
  rename_motif(fn, "#{results_folder}/source_data/pbm/ppm/mihaialbu/#{dst_bn}")
}

['selex_Lysate', 'selex_IVT'].each do |selex_type|
  # seqAjolmaAutoseed / BEESEM_KL in the same folder.
  # no model name (BEESEM_KL)
  # no separation of tool and model name (seqAjolmaAutoseed)

  # We drop these Autoseed occurences as they are already included in Arttu's data
  # Dir.glob("/home_local/mihaialbu/Codebook/ppms/#{selex_type}/*.train.seqAjolmaAutoseed*.ppm").each{|fn|
  #   bn = basename_wo_ext(fn)
  #   m = bn.match(/^(?<prefix>.*)\.train\.seqAjolmaAutoseed_(?<model_name>.+)$/)
  #   dst_bn = "#{m[:prefix]}.train.Autoseed@Codebook.#{m[:model_name]}.ppm"
  #   rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/#{dst_bn}")
  #   rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/mihaialbu/#{dst_bn}")
  # }

  Dir.glob("/home_local/mihaialbu/Codebook/ppms/#{selex_type}/*.train.BEESEM_KL.ppm").each{|fn| # seqAjolmaAutoseed / BEESEM_KL in the same folder
    dst_bn = File.basename(fn).sub('BEESEM_KL', 'BEESEM_KL@Codebook.model1')
    rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/#{dst_bn}")
    rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/mihaialbu/#{dst_bn}")
  }
end

# incorrect header
['affiseq_Lysate', 'affiseq_IVT'].each do |affiseq_type|
  Dir.glob("/home_local/mihaialbu/Codebook/ppms/#{affiseq_type}/*.train.*.ppm").each{|fn|
    bn = File.basename(fn)
    m = bn.match(/^(?<prefix>.*)\.train\.(?<tool>[^.]+)\.(?<model_name>.+).ppm$/)
    dst_bn = "#{m[:prefix]}.train.#{m[:tool]}@Codebook.#{m[:model_name]}.ppm"
    rename_motif(fn, "#{results_folder}/#{affiseq_type}/ppm/#{dst_bn}") # it will fix header
    rename_motif(fn, "#{results_folder}/source_data/#{affiseq_type}/ppm/mihaialbu/#{dst_bn}") # it will fix header
  }
end

Dir.glob("/home_local/mihaialbu/Codebook/ppms/chipseq/*.train.*.ppm").each{|fn|
  bn = File.basename(fn)
  m = bn.match(/^(?<prefix>.*)\.train\.(?<tool>[^.]+)\.(?<model_name>.+).ppm$/)
  dst_bn = "#{m[:prefix]}.train.#{m[:tool]}@Codebook.#{m[:model_name]}.ppm"
  rename_motif(fn, "#{results_folder}/chipseq/ppm/#{dst_bn}") # it will fix header
  rename_motif(fn, "#{results_folder}/source_data/chipseq/ppm/mihaialbu/#{dst_bn}") # it will fix header
}
