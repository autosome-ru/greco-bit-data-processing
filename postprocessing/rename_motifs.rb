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

results_folder = '/home_local/vorontsovie/greco-motifs/'
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
  FileUtils.cp(fn, "#{results_folder}/chipseq/ppm/")
  FileUtils.cp(fn, "#{results_folder}/source_data/chipseq/ppm/jangrau/")
}

Dir.glob("/home_local/jangrau/ppms/affiseq_IVT/*.ppm").each{|fn|
  FileUtils.cp(fn, "#{results_folder}/affiseq_IVT/ppm/")
  FileUtils.cp(fn, "#{results_folder}/source_data/affiseq_IVT/ppm/jangrau/")
}
Dir.glob("/home_local/jangrau/ppms/affiseq_Lysate/*.ppm").each{|fn|
  FileUtils.cp(fn, "#{results_folder}/affiseq_Lysate/ppm/")
  FileUtils.cp(fn, "#{results_folder}/source_data/affiseq_Lysate/ppm/jangrau/")
}

['spatialDetrend_quantNorm', 'quantNorm_zscore'].each do |pbm_subtype|
  Dir.glob("/home_local/vorontsovie/greco_pbm/release_3_motifs/#{pbm_subtype}/pcms/*.pcm").each{|fn|
    FileUtils.cp(fn, "#{results_folder}/pbm/pcm/")
    FileUtils.cp(fn, "#{results_folder}/source_data/pbm/pcm/vorontsovie/")
  }
end

# missing suffix {spatialDetrend_quantNorm,quantNorm_zscore} of pbm preprocessing subtype (came from an error in previous version of source files)
['spatialDetrend_quantNorm', 'quantNorm_zscore'].each do |pbm_subtype|
  Dir.glob("/home_local/jangrau/ppms/pbm/#{pbm_subtype}/*.pbm.train.*.ppm").each{|fn|
    rename_motif(fn, "#{results_folder}/pbm/ppm/" + basename_wo_ext(fn).sub('.pbm.', ".#{pbm_subtype}.pbm.") + '.ppm')
    rename_motif(fn, "#{results_folder}/source_data/pbm/ppm/jangrau/" + basename_wo_ext(fn).sub('.pbm.', ".#{pbm_subtype}.pbm.") + '.ppm')
  }
end

# model names contain dots, replace with underscores
['selex_IVT', 'selex_Lysate'].each{|selex_type|
  Dir.glob("/home_local/pbucher/ppms/#{selex_type}/*.train.*.ppm").each{|fn|
    bn = basename_wo_ext(fn)
    m = bn.match(/^(?<prefix>.*)\.selex\.train\.(?<tool>[^.]+)\.(?<model_name>.+)$/)
    model_name = m[:model_name].split('.').join('_')
    rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/" + "#{m[:prefix]}.selex.train.#{m[:tool]}.#{model_name}" + '.ppm')
    rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/pbucher/" + "#{m[:prefix]}.selex.train.#{m[:tool]}.#{model_name}" + '.ppm')
  }
}

# transpose matrix, fix header
Dir.glob("/home_local/pavelkrav/pcms/chipseq/*.train.*.pcm").each{|fn|
  rename_motif(fn, "#{results_folder}/chipseq/pcm/" + File.basename(fn), transpose: true)
  rename_motif(fn, "#{results_folder}/source_data/chipseq/pcm/pavelkrav/" + File.basename(fn), transpose: true)
}

['affiseq_Lysate', 'affiseq_IVT'].each do |affiseq_type|
  Dir.glob("/home_local/pavelkrav/pcms/affiseq/#{affiseq_type}/*.train.*.pcm").each{|fn|
    rename_motif(fn, "#{results_folder}/#{affiseq_type}/pcm/" + File.basename(fn), transpose: true)
    rename_motif(fn, "#{results_folder}/source_data/#{affiseq_type}/pcm/pavelkrav/" + File.basename(fn), transpose: true)
  }
end

# no separation of selex_IVT/selex_Lysate
# no separation of tool and model name
Dir.glob("/home_local/arsen_l/greco-bit/motifs/selex/pcms/*.train.*.pcm").each{|fn|
  bn = basename_wo_ext(fn)
  m = bn.match(/^(?<prefix>.*)\.selex\.train\.GRECO_THughes_novel_TFs_selex_ver1$/)
  if m[:prefix].include?('.IVT.')
    selex_type = 'selex_IVT'
  elsif m[:prefix].include?('.Lysate.')
    selex_type = 'selex_Lysate'
  else
    raise
  end
  rename_motif(fn, "#{results_folder}/#{selex_type}/pcm/#{m[:prefix]}.selex.train.philipp_reimpl.model1.pcm")
  rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/pcm/arsen_l/#{m[:prefix]}.selex.train.philipp_reimpl.model1.pcm")
}

# no separation of selex_IVT/selex_Lysate
# no separation of tool and model name
Dir.glob("/home_local/arsen_l/greco-bit/motifs/ajolma/ppms/*.train.*.ppm").each{|fn|
  bn = basename_wo_ext(fn)
  m = bn.match(/^(?<prefix>.*)\.selex\.train\.seqAjolmaAutoseed_(?<model_name>.+)$/)
    if m[:prefix].include?('.IVT.')
    selex_type = 'selex_IVT'
  elsif m[:prefix].include?('.Lysate.')
    selex_type = 'selex_Lysate'
  else
    raise
  end
  rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/#{m[:prefix]}.selex.train.seqAjolmaAutoseed.#{m[:model_name]}.ppm")
  rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/ajolma/#{m[:prefix]}.selex.train.seqAjolmaAutoseed.#{m[:model_name]}.ppm")
}

# no model name
Dir.glob("/home_local/mihaialbu/Codebook/ppms/pbm/*.train.Zscore.ppm").each{|fn| # here .val. motifs also exist
  bn = basename_wo_ext(fn)
  rename_motif(fn, "#{results_folder}/pbm/ppm/" + bn.sub('Zscore', 'Zscore.model1') + '.ppm')
  rename_motif(fn, "#{results_folder}/source_data/pbm/ppm/mihaialbu/" + bn.sub('Zscore', 'Zscore.model1') + '.ppm')
}

['selex_Lysate', 'selex_IVT'].each do |selex_type|
  # seqAjolmaAutoseed / BEESEM_KL in the same folder.
  # no model name (BEESEM_KL)
  # no separation of tool and model name (seqAjolmaAutoseed)
  Dir.glob("/home_local/mihaialbu/Codebook/ppms/#{selex_type}/*.train.seqAjolmaAutoseed*.ppm").each{|fn|
    bn = basename_wo_ext(fn)
    m = bn.match(/^(?<prefix>.*)\.train\.seqAjolmaAutoseed_(?<model_name>.+)$/)
    rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/#{m[:prefix]}.train.seqAjolmaAutoseed.#{m[:model_name]}.ppm")
    rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/mihaialbu/#{m[:prefix]}.train.seqAjolmaAutoseed.#{m[:model_name]}.ppm")
  }

  Dir.glob("/home_local/mihaialbu/Codebook/ppms/#{selex_type}/*.train.BEESEM_KL.ppm").each{|fn| # seqAjolmaAutoseed / BEESEM_KL in the same folder
    bn = basename_wo_ext(fn)
    rename_motif(fn, "#{results_folder}/#{selex_type}/ppm/" + bn.sub('BEESEM_KL', 'BEESEM_KL.model1') + '.ppm')
    rename_motif(fn, "#{results_folder}/source_data/#{selex_type}/ppm/mihaialbu/" + bn.sub('BEESEM_KL', 'BEESEM_KL.model1') + '.ppm')
  }
end

# incorrect header
['affiseq_Lysate', 'affiseq_IVT'].each do |affiseq_type|
  Dir.glob("/home_local/mihaialbu/Codebook/ppms/#{affiseq_type}/*.train.*.ppm").each{|fn|
    rename_motif(fn, "#{results_folder}/#{affiseq_type}/ppm/" + File.basename(fn)) # it will fix header
    rename_motif(fn, "#{results_folder}/source_data/#{affiseq_type}/ppm/mihaialbu/" + File.basename(fn)) # it will fix header
  }
end

Dir.glob("/home_local/mihaialbu/Codebook/ppms/chipseq/*.train.*.ppm").each{|fn|
  rename_motif(fn, "#{results_folder}/chipseq/ppm/" + File.basename(fn)) # it will fix header
  rename_motif(fn, "#{results_folder}/source_data/chipseq/ppm/mihaialbu/" + File.basename(fn)) # it will fix header
}
