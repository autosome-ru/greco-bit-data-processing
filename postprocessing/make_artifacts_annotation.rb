require 'json'
require 'csv'
require 'set'
require_relative '../shared/lib/index_by'

results_fn = ARGV[0] # 'motif_artifact_similarities.tsv'
motif_metadata_fn = ARGV[1] # 'freeze/motif_infos.freeze.tsv'
ranks_fn = ARGV[2] # 'freeze/benchmarks/ranks.freeze.json'
artifacts_json_fn = 'artifacts/artifacts.json'
artifacts_folder = 'artifacts'
artifact_similarities_folder = 'artifact_sims_precise'
flank_hits_fns = ['HTS_flanks_hits.tsv', 'AFS_flanks_hits.tsv', 'SMS_unpublished_flanks_hits.tsv', 'SMS_published_flanks_hits.tsv']

artifact_baseline_motifs = JSON.parse(File.read(artifacts_json_fn)); nil
artifact_motif_extfns = Dir.glob("#{artifacts_folder}/*.{ppm,pcm}").map{|fn| ext = File.extname(fn); [File.basename(fn, ext), ext] }.to_h; nil
motif_extfns = Dir.glob("#{artifact_similarities_folder}/*.{ppm,pcm}").map{|fn| ext = File.extname(fn); [File.basename(fn, ext), ext] }.to_h; nil

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

motif_flank_logpvalues = flank_hits_fns.flat_map{|fn|
  File.readlines(fn).map{|l|
    motif_wo_ext, tf, exp_id, flank_type, logpval, pos, strand = l.chomp.split("\t")
    raise "Can't handle non-dataset ids"  if exp_id == 'all'
    logpval = Float(logpval)
    raise  unless motif_extfns.has_key?(motif_wo_ext)
    motif = "#{motif_wo_ext}#{motif_extfns[motif_wo_ext]}"
    [motif, logpval]
  }
}.group_by(&:first).transform_values{|grp|
  grp.map{|motif, logpval| logpval }.max
}; nil

motif_infos = CSV.readlines(motif_metadata_fn, headers: true, col_sep: "\t").map(&:to_h).index_by{|d| d['motif'] }; nil

motifs_in_ranking = JSON.parse(File.read(ranks_fn)).flat_map{|tf, tf_data| motifs = tf_data.keys; motifs }.to_set; nil

artifact_types = artifact_baseline_motifs.keys.sort
File.open(results_fn, 'w'){|fw|
  header = ['motif', 'excluded_from_ranking', 'tf', 'experiment_type', 'experiment_id', *artifact_types, 'flank_logpvalue']
  fw.puts(header.join("\t"))
  motif_artifact_similarities.sort.select{|motif, motif_sims|
    motif_infos.has_key?(motif)
  }.each{|motif, motif_sims|
    motif_info = motif_infos[motif]
    row = [
      motif,
      !motifs_in_ranking.include?(motif),
      motif_info['tf'], motif_info.values_at('exp_type', 'exp_subtype').compact.join('.'), motif_info['experiment_id'],
      *artifact_types.map{|artifact_type| motif_sims[artifact_type] }.map{|v| v.round(4)},
      motif_flank_logpvalues[motif], # can be missing
    ]
    fw.puts(row.join("\t"))
  }
}; nil

