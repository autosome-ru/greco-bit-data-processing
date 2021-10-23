require 'fileutils'

def basename_wo_ext(fn)
  File.basename(fn, File.extname(fn))
end

def rename_motif_copies(src_filename, dst_filenames, transpose: false)
  dst_filenames.each{|dst_filename|
    rename_motif(src_filename, dst_filename, transpose: transpose)
  }
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

  matrix = lines.map{|l| l.strip.split(/\s+/) }
  matrix = matrix.transpose  if transpose

  File.open(dst_filename, 'w') {|fw|
    fw.puts header
    fw.puts matrix.map{|row| row.join("\t") }.join("\n")
  }
end

results_folder = File.absolute_path(ARGV[0])
# results_folder = '/home_local/vorontsovie/greco-motifs/release_7_motifs_2020-10-13'

FileUtils.mkdir_p(results_folder)

#############################################

gene_mapping = {
  'ZNF788' => 'ZNF788P',
  'ZUFSP' => 'ZUP1',
  'TPRX' => 'TPRX1',
  'OKT4' => 'POU5F1',
  'cJUN' => 'JUN',
  'ZFAT1' => 'ZFAT',
  'C11orf95' => 'ZFTA',
}

fix_tf_info = ->(tf_info) {
  tf, construction_type = tf_info.split('.')
  tf = gene_mapping.fetch(tf, tf)
  "#{tf}.#{construction_type}"
}


Dir.glob('/home_local/pavelkrav/GRECO_3_iter_pcms/AFS/*.pcm').each{|fn|
  # AC008770.DBD@AFS.IVT@YWH_B_AffSeq_H02_AC008770_DBD.C4.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC@Peaks.messy-heliotrope-armadillo.Train.peaks.499seq_7to15_m0.pcm
  bn = File.basename(fn, '.pcm')
  tf_info, exp_type, _exp_info, rest_info = bn.split('@')
  tf_info = fix_tf_info.call(tf_info)
  _processing_type, dataset_name, _train_val, _processing_type_2, motif_name = rest_info.split('.')
  raise  unless (exp_type == 'AFS.IVT') || (exp_type == 'AFS.Lys')
  raise  unless (_processing_type == 'Peaks') && (_processing_type_2 == 'peaks')
  raise  unless _train_val == 'Train'
  dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@autosome-ru.ChIPMunk@#{motif_name}.pcm"
  rename_motif(fn, "#{results_folder}/#{dst_bn}", transpose: true)
}

Dir.glob('/home_local/pavelkrav/GRECO_3_iter_pcms/CHS/*.pcm').each{|fn|
  # AC008770.FL@CHS@THC_0139@Peaks.squeaky-cream-tarantula.Train.peaks.242seq_21to7_m0.pcm
  bn = File.basename(fn, '.pcm')
  tf_info, exp_type, _exp_name, rest_info = bn.split('@')
  tf_info = fix_tf_info.call(tf_info)
  _processing_type, dataset_name, _train_val, _processing_type_2, motif_name = rest_info.split('.')
  raise  unless exp_type == 'CHS'
  raise  unless (_processing_type == 'Peaks') && (_processing_type_2 == 'peaks')
  raise  unless _train_val == 'Train'
  dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@autosome-ru.ChIPMunk@#{motif_name}.pcm"
  rename_motif(fn, "#{results_folder}/#{dst_bn}", transpose: true)
}

Dir.glob("/home_local/vorontsovie/greco-bit-data-processing/motifs_pbm_release_7/{SDQN,QNZS}/pcms/*.pcm").each{|fn|
  # AC008770.DBD@PBM.HK@nerdy-auburn-turtle@autosome-ru.ChIPMunk@s_6-16_flat.pcm
  bn = File.basename(fn, '.pcm')
  tf_info, exp_type, dataset_name, team_tool, motif_name = bn.split('@')
  tf_info = fix_tf_info.call(tf_info)
  dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team_tool}@#{motif_name}.pcm"
  rename_motif(fn, "#{results_folder}/#{dst_bn}")
}

Dir.glob("/home_local/arsen_l/greco-bit/motifs/motif_collection_release_7.2021-08-14/{AFS,HTS,SMS}/pcms/*.pcm").each{|fn|
  # AC008770.FL@AFS.IVT@lumpy-zucchini-octopus+sunny-ruby-kangaroo@autosome-ru.ChIPMunk@topk_cycle=C3+C4_k=5_top=500.pcm
  bn = File.basename(fn, '.pcm')
  tf_info, exp_type, dataset_name, team_tool, motif_name = bn.split('@')
  tf_info = fix_tf_info.call(tf_info)
  dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team_tool}@#{motif_name}.pcm"
  rename_motif(fn, "#{results_folder}/#{dst_bn}")
}

# model names contain dots, replace with underscores
Dir.glob("/home_local/jangrau/models_r7/{AFS,CHS,PBM.QNZS,PBM.SDQN,SMS,SMS.published}/*.ppm").each{|fn|
  # AC008770.DBD@HTS.IVT@blurry-puce-tarsier+flimsy-celadon-spitz+stealthy-linen-kakapo+jumpy-bronze-woodlouse@Halle.Dimont@Motif_1_sampled_e1.5_astrained.ppm
  bn = File.basename(fn, '.ppm')
  tf_info, exp_type, dataset_name, team_tool, motif_name = bn.split('@')
  tf_info = fix_tf_info.call(tf_info)
  motif_name = motif_name.gsub('.', '_')
  dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team_tool}@#{motif_name}.ppm"
  rename_motif(fn, "#{results_folder}/#{dst_bn}")
}

Dir.glob("/mnt/space/hughes/Motifs_10_06/Motifs/{AFS.Peaks,CHS,SMS,SMS.published}/*.ppm").each{|fn|
  # AC008770.DBD@AFS.IVT@YWH_B_AffSeq_H02_AC008770_DBD.C4.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC@Peaks.messy-heliotrope-armadillo@HughesLab@Homer@Motif1.ppm
  bn = File.basename(fn, '.ppm')
  tf_info, exp_type, _exp_info, rest_info, team, tool, motif_name = bn.split('@')
  tf_info = fix_tf_info.call(tf_info)
  dataset_name = rest_info.split('.').drop(1).join('+')

  dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team}.#{tool}@#{motif_name}.ppm"
  rename_motif(fn, "#{results_folder}/#{dst_bn}")
}
