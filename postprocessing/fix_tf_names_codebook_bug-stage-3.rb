require 'csv'
require 'json'
require 'fileutils'
require 'set'
require_relative 'fix_tf_names_codebook_bug_utils.rb'

def renamed_motif_basename(fn, dataset_ids_renames)
  renames_for_motif = dataset_ids_by_motif_fn(fn).map{|dataset_id|
    dataset_ids_renames[dataset_id]
  }.compact.uniq

  if renames_for_motif.size == 0
    File.basename(fn)
  elsif renames_for_motif.size == 1
    renamed_motif_basename_by_info(fn, renames_for_motif.take_the_only)
  else
    raise "Mismatch in motif renames"
  end
end

def motif_similarity_rename_pairs(dataset_ids_renames)
  Dir.glob("artifact_sims_precise/*").map{|fn|
    new_bn = renamed_motif_basename(fn, dataset_ids_renames)
    [fn, File.join('artifact_sims_precise_recalc', new_bn)]
  }
end

FileUtils.rm_rf('artifact_sims_precise_recalc')
FileUtils.mkdir_p('artifact_sims_precise_recalc')

renames = CSV.foreach('source_data_meta/fixes/CODEGATE_DatasetsSwap.txt', col_sep: "\t", headers: true).map(&:to_h).map{|row|
  #  "THC_0361.Rep-DIANA_0293,THC_0361.Rep-MICHELLE_0314" → THC_0361
  id = row['MEX Dataset ID(s)'].split(',').map{|v| v.split('.').first }.uniq.take_the_only
  [id, row]
}.to_h_safe

datasets_full = File.readlines('freeze/datasets_metadata.full.json').map{|l| JSON.parse(l) }

dataset_ids_renames = get_dataset_ids_renames(datasets_full, renames)
# copy/copy-and-rename motif-related files from `artifact_sims_precise` to `artifact_sims_precise_recalc`
copy_files(motif_similarity_rename_pairs(dataset_ids_renames), symlink: true)

hocomoco_similarities_renamed = File.readlines('hocomoco_similarities.tsv').map{|l| l.chomp.split("\t") }.map{|row|
  [renamed_motif_basename(row[0], dataset_ids_renames), *row[1..-1]]
}

save_tsv('hocomoco_similarities_recalc.tsv', hocomoco_similarities_renamed)

Dir.glob('*_flanks_hits.tsv').each{|fn|
  flanks_hits_data = File.readlines(fn).map{|l| l.chomp.split("\t") }.map{|row|
    motif_wo_ext, tf, *rest = l.chomp.split("\t")
    new_motif_wo_ext = renamed_motif_basename(motif_wo_ext, dataset_ids_renames)
    new_tf = new_motif_wo_ext.split(".")[0]
    [new_motif_wo_ext, new_tf, *rest]
  }
  save_tsv(fn.sub(/.tsv$/, '_recalc.tsv'), flanks_hits_data)
}
