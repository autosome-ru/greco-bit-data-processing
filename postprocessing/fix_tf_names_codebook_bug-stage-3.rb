require 'csv'
require 'json'
require 'fileutils'
require 'set'
require_relative 'fix_tf_names_codebook_bug_utils.rb'

def motif_similarity_rename_pairs
  Dir.glob("artifact_sims_precise/*").map{|fn|
    renames_for_motif = dataset_ids_by_motif_fn(fn).map{|dataset_id| dataset_ids_renames[dataset_id] }.compact.uniq
    if renames_for_motif.size == 0
      [fn, File.join('artifact_sims_precise_recalc', File.basename(motif_fn))]
    elsif renames_for_motif.size == 1
      rename_info = renames_for_motif.take_the_only
      new_basename = renamed_motif_basename_by_info(motif_fn, rename_info)
      [fn, File.join('artifact_sims_precise_recalc', new_basename)]
    else
      raise "Mismatch in motif renames"
    end
  }.compact
end

FileUtils.rm_rf('artifact_sims_precise_recalc')
FileUtils.mkdir_p('artifact_sims_precise_recalc')

renames = CSV.foreach('source_data_meta/fixes/CODEGATE_DatasetsSwap.txt', col_sep: "\t", headers: true).map(&:to_h).map{|row|
  #  "THC_0361.Rep-DIANA_0293,THC_0361.Rep-MICHELLE_0314" → THC_0361
  id = row['MEX Dataset ID(s)'].split(',').map{|v| v.split('.').first }.uniq.take_the_only
  [id, row]
}.to_h_safe

# copy/copy-and-rename motif-related files from `artifact_sims_precise` to `artifact_sims_precise_recalc`
copy_files(motif_similarity_rename_pairs, symlink: true)
