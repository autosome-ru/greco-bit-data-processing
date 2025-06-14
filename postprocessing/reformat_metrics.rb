require 'json'
require 'csv'
require_relative 'fix_tf_names_codebook_bug_utils.rb'

def log10_str(str)
  pattern = /^(?<significand>\d+(\.\d*)?)([eE](?<exponent>[-+]?\d+))?$/
  match = str.match(pattern)
  raise "#{str} is not a positive number; can't calculate log10"  unless match
  Math.log10(Float(match[:significand])) + (match[:exponent] ? Integer(match[:exponent]) : 0)
end

conversion_tasks = [
  # peak-based
  {
    src: [
      'benchmarks/release_8c/motif_batch_7e/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_1/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_2/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_3/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_4/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_5/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_6_wo_bad/pwmeval_peaks.tsv',
      # 'benchmarks/release_8c/motif_batch_8c_pack_7/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_9/pwmeval_peaks.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/pwmeval_peaks.tsv',
    metrics: ['roc_auc', 'pr_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: [
      'benchmarks/release_8c/motif_batch_7e/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_1/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_2/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_3/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_4/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_5/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_6_wo_bad/vigg_peaks.tsv',
      # 'benchmarks/release_8c/motif_batch_8c_pack_7/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_9/vigg_peaks.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/vigg_peaks.tsv',
    metrics: ['roc_auc', 'logroc_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: [
      'benchmarks/release_8c/motif_batch_7e/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_1/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_2/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_3/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_4/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_5/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_6_wo_bad/centrimo_peaks.tsv',
      # 'benchmarks/release_8c/motif_batch_8c_pack_7/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_9/centrimo_peaks.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/centrimo_peaks.tsv',
    metrics: ['-log10(E-value)','concentration_30nt'],
    parser: ->(info, metrics){
      if !info || info.empty?
        [nil, nil]
      else
        info = JSON.parse(info)
        log_evalue = log10_str(info['evalue'])
        concentration_30 = info['concentrations'].detect{|metric|
          metric['window_size'] == 30
        }['concentration']
        [log_evalue.zero? ? 0 : -log_evalue, concentration_30]
      end
    }
  },

  # PBM-based
  {
    src: [
      'benchmarks/release_8c/motif_batch_7e/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_1/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_2/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_3/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_4/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_5/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_6_wo_bad/pbm.tsv',
      # 'benchmarks/release_8c/motif_batch_8c_pack_7/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_9/pbm.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/pbm.tsv',
    metrics: ['ROC', 'PR'],
    parser: ->(info, metrics){ JSON.parse(info).values_at(*metrics) }
  },

  # Read-based
  *['0.1', '0.25', '0.5'].map{|fraction|
    {
      src: [
        "benchmarks/release_8c/motif_batch_7e/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_1/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_2/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_3/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_4/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_5/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_6_wo_bad/reads_#{fraction}.tsv",
        # "benchmarks/release_8c/motif_batch_8c_pack_7/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_8_fix/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_9/reads_#{fraction}.tsv",
      ],
      dst: "freeze_recalc_integrated/benchmarks_formatted/reads_#{fraction}.tsv",
      metrics: ['roc_auc', 'pr_auc'],
      parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
    }
  },
]


conversion_tasks_recalc = [
  # peak-based
  {
    src: [
      'freeze_recalc_for_benchmark/benchmarks_1/pwmeval_peaks.tsv',
      'freeze_recalc_for_benchmark/benchmarks_2/pwmeval_peaks.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/pwmeval_peaks.tsv',
    metrics: ['roc_auc', 'pr_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: [
      'freeze_recalc_for_benchmark/benchmarks_1/vigg_peaks.tsv',
      'freeze_recalc_for_benchmark/benchmarks_2/vigg_peaks.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/vigg_peaks.tsv',
    metrics: ['roc_auc', 'logroc_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: [
      'freeze_recalc_for_benchmark/benchmarks_1/centrimo_peaks.tsv',
      'freeze_recalc_for_benchmark/benchmarks_2/centrimo_peaks.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/centrimo_peaks.tsv',
    metrics: ['-log10(E-value)','concentration_30nt'],
    parser: ->(info, metrics){
      if !info || info.empty?
        [nil, nil]
      else
        info = JSON.parse(info)
        log_evalue = log10_str(info['evalue'])
        concentration_30 = info['concentrations'].detect{|metric|
          metric['window_size'] == 30
        }['concentration']
        [log_evalue.zero? ? 0 : -log_evalue, concentration_30]
      end
    }
  },

  # PBM-based
  {
    src: [
      'freeze_recalc_for_benchmark/benchmarks_1/pbm.tsv',
      'freeze_recalc_for_benchmark/benchmarks_2/pbm.tsv',
    ],
    dst: 'freeze_recalc_integrated/benchmarks_formatted/pbm.tsv',
    metrics: ['ROC', 'PR'],
    parser: ->(info, metrics){ JSON.parse(info).values_at(*metrics) }
  },

  # Read-based
  *['0.1', '0.25', '0.5'].map{|fraction|
    {
      src: [
        "freeze_recalc_for_benchmark/benchmarks_1/reads_#{fraction}.tsv",
        "freeze_recalc_for_benchmark/benchmarks_2/reads_#{fraction}.tsv",
      ],
      dst: "freeze_recalc_integrated/benchmarks_formatted/reads_#{fraction}.tsv",
      metrics: ['roc_auc', 'pr_auc'],
      parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
    }
  },
]

renames = CSV.foreach('source_data_meta/fixes/CODEGATE_DatasetsSwap.txt', col_sep: "\t", headers: true).map(&:to_h).map{|row|
  #  "THC_0361.Rep-DIANA_0293,THC_0361.Rep-MICHELLE_0314" → THC_0361
  id = row['MEX Dataset ID(s)'].split(',').map{|v| v.split('.').first }.uniq.take_the_only
  [id, row]
}.to_h_safe

affected_tfs = renames.flat_map{|exp_id, rename_info| rename_info.values_at('Original TF label', 'NEW TF label') }.uniq

conversion_tasks.each do |conversion_task|
  metrics = conversion_task[:metrics]

  data_rows = conversion_task[:src].flat_map{|fn|
    File.readlines(fn).map(&:strip).reject(&:empty?).map{|l|
      ds, mot, info = l.split("\t")
      metrics_values = conversion_task[:parser].call(info, metrics)
      [File.basename(ds), File.basename(mot), *metrics_values]
    }
  }.reject{|ds, mot, *rest|
    ds.start_with?('ZNF705E.') || mot.start_with?('ZNF705E.')
  }.reject{|ds, mot, *rest|
    ds_tf = ds.split('.').first
    mot_tf = mot.split('.').first
    raise "#{ds_tf} doesn't match #{mot_tf}" unless ds_tf == mot_tf
    affected_tfs.include?(ds_tf) # drop TFs which are in the recalc
  }

  File.open(conversion_task[:dst], 'w'){|fw|
    header = ["dataset", "motif", *metrics]
    fw.puts header.join("\t")
    data_rows.each{|row|
      fw.puts(row.join("\t"))
    }
  }
end

conversion_tasks_recalc.each do |conversion_task|
  metrics = conversion_task[:metrics]

  data_rows = conversion_task[:src].flat_map{|fn|
    File.readlines(fn).map(&:strip).reject(&:empty?).map{|l|
      ds, mot, info = l.split("\t")
      metrics_values = conversion_task[:parser].call(info, metrics)
      [File.basename(ds), File.basename(mot), *metrics_values]
    }
  }.each{|ds, mot, *rest|
    ds_tf = ds.split('.').first
    mot_tf = mot.split('.').first
    raise "#{ds_tf} doesn't match #{mot_tf}" unless ds_tf == mot_tf
  }.reject{|ds, mot, *rest|
    ds.start_with?('ZNF705E.') || mot.start_with?('ZNF705E.')
  }

  File.open(conversion_task[:dst], 'a'){|fw|
    fw.puts header.join("\t")
    data_rows.each{|row|
      fw.puts(row.join("\t"))
    }
  }
end
