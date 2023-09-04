require 'json'
require 'set'

result_min_quantile_fn = ARGV[0] # 'dataset_artifact_metrics_min_quantile.json'
result_num_in_q25_fn = ARGV[1] # 'dataset_artifact_metrics_num_in_q25.json'
ranks_fn = ARGV[2] # 'benchmarks/release_8d/ranks_7e+8c_pack_1+2+3+4.json'
artifacts_json_fn = 'artifacts/artifacts.json'
artifacts_folder = 'artifacts'
artifact_similarities_folder = 'artifact_sims_precise'
flank_hits_fns = ['HTS_flanks_hits.tsv', 'AFS_flanks_hits.tsv', 'SMS_unpublished_flanks_hits.tsv', 'SMS_published_flanks_hits.tsv']
flank_threshold = 4.0

similarity_threshold = 0.15
rank_quantile_threshold = 0.05

artifact_baseline_motifs = JSON.parse(File.read(artifacts_json_fn))
artifact_motif_extfns = Dir.glob("#{artifacts_folder}/*.{ppm,pcm}").map{|fn| ext = File.extname(fn); [File.basename(fn, ext), ext] }.to_h
motif_extfns = Dir.glob("#{artifact_similarities_folder}/*.{ppm,pcm}").map{|fn| ext = File.extname(fn); [File.basename(fn, ext), ext] }.to_h
invert_artifact_baseline_motifs = artifact_baseline_motifs.flat_map{|k,vs| vs.map{|v| [v, k] } }.to_h

artifact_sims = Dir.glob("#{artifact_similarities_folder}/*").map{|motif_fn|
  motif_sims = File.readlines(motif_fn).map{|l|
    artifact_motif, similarity, shift, overlap, orientation = l.chomp.split("\t")
    artifact_motif = artifact_motif.split(' ').first
    artifact_motif_fn = "#{artifact_motif}#{artifact_motif_extfns[artifact_motif]}"
    [artifact_motif_fn, Float(similarity)]
  }.to_h
  [motif_fn, motif_sims]
}.to_h; nil

motif_artifact_similarities = artifact_sims.map{|motif_fn, motif_sims|
  motif = File.basename(motif_fn)
  best_sims_by_artifact = artifact_baseline_motifs.map{|artifact_type, artifact_motifs|
    best_sim = artifact_motifs.map{|artifact_motif| motif_sims[artifact_motif] }.max
    [artifact_type, best_sim]
  }.to_h
  [motif, best_sims_by_artifact]
}.to_h; nil

motif_artifact_types = motif_artifact_similarities.transform_values{|sims_by_artifact|
  sims_by_artifact.select{|artifact_type, sim| sim >= similarity_threshold }.keys
}; nil

# If I remember it right, we drop them not to have motifs, which are not greco-generated, for which we don't have origin etc. Those are the only hocomoco motifs
motifs_by_artifact_type = artifact_baseline_motifs.map{|k,v| [k, v.reject{|k,v| k.match?(/NFI.*\.H11MO\.\d\.[ABCD]/) }.to_set] }.to_h; nil
motif_artifact_types.each{|motif, artifact_types|
  artifact_types.each{|artifact_type|
    motifs_by_artifact_type[artifact_type] << motif
  }
}; nil

# artifact_motifs = artifact_sims.select{|motif_fn, motif_sims|
#   ! motif_sims.select{|artifact_motif, sim| sim >= similarity_threshold }.empty?
# }.keys.map{|fn| File.basename(fn) }; nil

motifs_in_flanks = flank_hits_fns.flat_map{|fn|
  File.readlines(fn).map{|l|
    motif_wo_ext, tf, exp_id, flank_type, logpval, pos, strand = l.chomp.split("\t")
    raise "Can't handle non-dataset ids"  if exp_id == 'all'
    logpval = Float(logpval)
    [motif_wo_ext, logpval]
  }.select{|motif_wo_ext, logpval|
    logpval >= flank_threshold
  }.map{|motif_wo_ext, logpval|
    raise  unless motif_extfns.has_key?(motif_wo_ext)
    "#{motif_wo_ext}#{motif_extfns[motif_wo_ext]}"
  }
}.uniq.to_set; nil

motifs_by_artifact_type['Artifact-11_In-Flank'] = Set.new
motifs_in_flanks.each{|motif|
  motifs_by_artifact_type['Artifact-11_In-Flank'] << motif
}; nil

motifs_by_artifact_type = motifs_by_artifact_type.transform_values(&:to_a); nil

ranks = JSON.parse(File.read(ranks_fn)); nil

artifact_infos_full = motifs_by_artifact_type.flat_map{|artifact_type, artifact_motifs|
  # artifact_motifs_infos = artifact_motifs.reject{|motif_fn| motifs_in_flanks.include?(File.basename(motif_fn, File.extname(motif_fn))) }.map{|motif_fn|
  artifact_motifs_infos = artifact_motifs.map{|motif_fn|
    tf = motif_fn.split('.').first
    [motif_fn, tf]
  }.select{|motif_fn, tf|
    ranks[tf] && ranks[tf].has_key?(motif_fn)
  }.flat_map{|motif_fn, tf|
    num_motifs = ranks[tf].size
    all_dataset_ranks = ranks[tf][motif_fn].reject{|data_type, v| data_type == 'combined' }.flat_map{|data_type, datatype_ranks|
      datatype_ranks.reject{|dataset, v| dataset == 'combined' }.map{|dataset, dataset_ranks|
        dataset_rank = dataset_ranks['combined']
        [dataset, dataset_rank, num_motifs, dataset_rank.to_f / num_motifs]
      }
    }
    all_dataset_ranks
  }

  artifact_motifs_infos.map{|ds_info|
    [artifact_type, *ds_info]
  }
}; nil

dataset_artifact_metrics_min_quantile = artifact_infos_full.group_by{|artifact_type, dataset, dataset_rank, num_motifs, dataset_quantile|
  dataset
}.transform_values{|ds_grp|
  ds_grp.group_by{|artifact_type, dataset, dataset_rank, num_motifs, dataset_quantile|
    artifact_type
  }.transform_values{|art_grp|
    art_grp.map{|artifact_type, dataset, dataset_rank, num_motifs, dataset_quantile|
      dataset_quantile
    }.min
  }
}

File.write(result_min_quantile_fn, dataset_artifact_metrics_min_quantile.to_json)

dataset_artifact_metrics_num_in_q25 = artifact_infos_full.group_by{|artifact_type, dataset, dataset_rank, num_motifs, dataset_quantile|
  dataset
}.transform_values{|ds_grp|
  ds_grp.group_by{|artifact_type, dataset, dataset_rank, num_motifs, dataset_quantile|
    artifact_type
  }.transform_values{|art_grp|
    art_grp.count{|artifact_type, dataset, dataset_rank, num_motifs, dataset_quantile|
      dataset_quantile < 0.25
    }
  }
}

File.write(result_num_in_q25_fn, dataset_artifact_metrics_num_in_q25.to_json)

# artifact_datasets = artifact_motifs_infos.select{|ds, *rest, pval| pval < rank_quantile_threshold }.map(&:first).uniq; nil
# File.write('artifact_datasets.json', artifact_datasets.to_json)
