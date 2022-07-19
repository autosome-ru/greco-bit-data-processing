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

  write_motif(dst_filename, header, matrix)
end

def write_motif(dst_filename, header, matrix)
  File.open(dst_filename, 'w') {|fw|
    fw.puts header
    fw.puts matrix.map{|row| row.map{|x| Float(x) }.map{|x| '%.16f' % x }.join("\t") }.join("\n")
  }
end

# novel Arttu's motifs have unique formatting
def rename_arttu_motif(src_filename, dst_filename)
  new_motif_name = basename_wo_ext(dst_filename)
  header = ">#{new_motif_name}"
  lines = File.readlines(src_filename).map(&:chomp)
  raise  unless lines[0].start_with?('Gene') && lines[1].start_with?('Motif') && lines[2].start_with?('Pos')
  matrix = lines.drop(3).map{|l| l.strip.split(/\s+/) }.map{|r|
    r.drop(1) # drop `position` column
  }
  write_motif(dst_filename, header, matrix)
end

# novel Oriol's motifs have unique formatting
def rename_oriol_motif(src_filename, dst_filename)
  new_motif_name = basename_wo_ext(dst_filename)
  header = ">#{new_motif_name}"
  matrix = File.readlines(src_filename).map{|l| l.strip.split(/\s+/) }
  write_motif(dst_filename, header, matrix)
end

#############################################

results_folder = File.absolute_path(ARGV[0])
# results_folder = '/home_local/vorontsovie/greco-motifs/release_7e_motifs_2022-06-02'

FileUtils.mkdir_p(results_folder)

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


# Dir.glob('/home_local/pavelkrav/GRECO_4_iter_pcms_novel/AFS_novel/*.pcm').each{|fn|
#   # AC008770.DBD@AFS.IVT@YWH_B_AffSeq_H02_AC008770_DBD.C4.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC@Peaks.messy-heliotrope-armadillo.Train.peaks.499seq_7to15_m0.pcm
#   bn = File.basename(fn, '.pcm')
#   tf_info, exp_type, _exp_info, rest_info = bn.split('@')
#   tf_info = fix_tf_info.call(tf_info)
#   _processing_type, dataset_name, _train_val, _processing_type_2, motif_name = rest_info.split('.')
#   raise  unless ['AFS.IVT', 'AFS.Lys', 'AFS.GFPIVT'].include?(exp_type)
#   raise  unless (_processing_type == 'Peaks') && (_processing_type_2 == 'peaks')
#   raise  unless _train_val == 'Train'
#   team_tool = 'autosome-ru.ChIPMunk'
#   dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team_tool}@#{motif_name}.pcm"
#   rename_motif(fn, "#{results_folder}/#{dst_bn}", transpose: true)
# }

# Dir.glob('/home_local/pavelkrav/GRECO_4_iter_pcms_novel/CHS_novel/*.pcm').each{|fn|
#   # AC008770.FL@CHS@THC_0139@Peaks.squeaky-cream-tarantula.Train.peaks.242seq_21to7_m0.pcm
#   bn = File.basename(fn, '.pcm')
#   tf_info, exp_type, _exp_info, rest_info = bn.split('@')
#   tf_info = fix_tf_info.call(tf_info)
#   _processing_type, dataset_name, _train_val, _processing_type_2, motif_name = rest_info.split('.')
#   raise  unless exp_type == 'CHS'
#   raise  unless (_processing_type == 'Peaks') && (_processing_type_2 == 'peaks')
#   raise  unless _train_val == 'Train'
#   team_tool = 'autosome-ru.ChIPMunk'
#   dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team_tool}@#{motif_name}.pcm"
#   rename_motif(fn, "#{results_folder}/#{dst_bn}", transpose: true)
# }

# [
#   *Dir.glob("/home_local/mihaialbu/Motifs202206/Motifs{AFS.Peaks,CHS,SMS}/*.ppm"),
# ].each{|fn|
#   # AC008770.DBD@AFS.IVT@YWH_B_AffSeq_H02_AC008770_DBD.C4.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC@Peaks.messy-heliotrope-armadillo@HughesLab@Homer@Motif1.ppm
#   # C11orf95.FL@CHS@THC_0197@Peaks.foggy-red-dalmatian@HughesLab@GkmSVM@Motif2.txt
#   # AHCTF1.DBD@SMS@UT380-009-2.5TAAGAGACAGCGTATGAATC.3CTGTCTCTTATACACATCTC@Reads.chummy-puce-dragon@HughesLab@Homer@Motif2.ppm
#   bn = File.basename(fn, File.extname(fn))
#   tf_info, exp_type, _exp_info, rest_info, team, tool, motif_name = bn.split('@')
#   tf_info = fix_tf_info.call(tf_info)
#   dataset_name = rest_info.split('.').drop(1).join('+')

#   dst_bn = "#{tf_info}@#{exp_type}@#{dataset_name}@#{team}.#{tool}@#{motif_name}.ppm"
#   rename_motif(fn, "#{results_folder}/#{dst_bn}")
# }

# [
#   '/home_local/arsen_l/greco-bit/motifs/motif_collection_release_8a.2022-04-14/HTS/pcms',
#   '/home_local/arsen_l/greco-bit/motifs/motif_collection_release_8a.2022-04-14/SMS/pcms',
#   '/home_local/arsen_l/greco-bit/motifs/motif_collection_release_8c.2022-06-01/AFS/pcms',
# ].each{|folder|
#   Dir.glob("#{folder}/*").each{|fn|
#     FileUtils.cp(fn, results_folder)
#   }
# }

[
  *Dir.glob('/home_local/vorontsovie/greco-bit-data-processing/arttu_motifs/MotifSet_HT-SELEXJune2022_NostartingLetter/*.ppm'),
  *Dir.glob('/home_local/vorontsovie/greco-bit-data-processing/arttu_motifs/MotifSet_SmileSeqJune2022/*.ppm'),
].each{|fn|
  # TIGD4.FL@HTS.IVT@YWE_A_AT40NGAGAGG.C3.5ACGACGCTCTTCCGATCTAT.3GAGAGGAGATCGGAAGAGCA@Reads.snazzy-pear-sparrow.Train@Ajolma_Autoseed_Multinom2_Onehit_Seed_NAACCCCGTTA
  raise  unless File.extname(fn) == '.ppm'
  bn = File.basename(fn, '.ppm')
  tf_info, exp_type, exp_info, ds_info, motif_info = bn.split('@')
  raise  unless motif_info.start_with?('Ajolma_Autoseed_')
  tf_info = fix_tf_info.call(tf_info)
  motif_name = motif_info.sub(/^Ajolma_Autoseed_/, '')
  proc_type, ds_name, slice_type = ds_info.split('.')
  raise  unless proc_type == 'Reads' && slice_type == 'Train'
  team_tool = 'AJolma.Autoseed'
  dst_bn = "#{tf_info}@#{exp_type}@#{ds_name}@#{team_tool}@#{motif_name}.ppm"
  rename_arttu_motif(fn, "#{results_folder}/#{dst_bn}")
}

[
  *Dir.glob('/home_local/vorontsovie/greco-bit-data-processing/oriol_motifs/PPM/*.ppm'),
].each{|fn|
  # GATA3.NA@SMS@SRR3405148@stealthy-jade-skunk@OF_ExplaiNN_filter2_1.ppm
  raise  unless File.extname(fn) == '.ppm'
  bn = File.basename(fn, '.ppm')
  tf_info, exp_type, exp_info, ds_name, motif_info = bn.split('@')
  raise  unless motif_info.start_with?('OF_ExplaiNN_')
  tf_info = fix_tf_info.call(tf_info)
  motif_name = motif_info.sub(/^OF_ExplaiNN_/, '')
  team_tool = 'OFornes.ExplaiNN'
  dst_bn = "#{tf_info}@#{exp_type}@#{ds_name}@#{team_tool}@#{motif_name}.ppm"
  rename_oriol_motif(fn, "#{results_folder}/#{dst_bn}")
}
