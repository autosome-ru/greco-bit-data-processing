require 'json'

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
      'benchmarks/release_8c/motif_batch_8c_pack_7/pwmeval_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/pwmeval_peaks.tsv',
    ],
    dst: 'benchmarks/release_8c/final_formatted/pwmeval_peaks.tsv',
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
      'benchmarks/release_8c/motif_batch_8c_pack_7/vigg_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/vigg_peaks.tsv',
    ],
    dst: 'benchmarks/release_8c/final_formatted/vigg_peaks.tsv',
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
      'benchmarks/release_8c/motif_batch_8c_pack_7/centrimo_peaks.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/centrimo_peaks.tsv',
    ],
    dst: 'benchmarks/release_8c/final_formatted/centrimo_peaks.tsv',
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
      'benchmarks/release_8c/motif_batch_8c_pack_7/pbm.tsv',
      'benchmarks/release_8c/motif_batch_8c_pack_8_fix/pbm.tsv',
    ],
    dst: 'benchmarks/release_8c/final_formatted/pbm.tsv',
    metrics: ['ASIS', 'LOG', 'EXP', 'ROC', 'PR', 'ROCLOG', 'PRLOG', 'MERS', 'LOGMERS'],
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
        "benchmarks/release_8c/motif_batch_8c_pack_7/reads_#{fraction}.tsv",
        "benchmarks/release_8c/motif_batch_8c_pack_8_fix/reads_#{fraction}.tsv",
      ],
      dst: "benchmarks/release_8c/final_formatted/reads_#{fraction}.tsv",
      metrics: ['roc_auc', 'pr_auc'],
      parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
    }
  },
]

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
  }

  File.open(conversion_task[:dst], 'w'){|fw|
    header = ["dataset", "motif", *metrics]
    fw.puts header.join("\t")
    data_rows.each{|row|
      fw.puts(row.join("\t"))
    }
  }
end
