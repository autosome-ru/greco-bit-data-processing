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
      'run_benchmarks_release_7/pwmeval_peaks.tsv',
      'run_benchmarks_release_7/pwmeval_peaks_7a+7c.tsv',
      'run_benchmarks_release_7/pwmeval_peaks_7a+7_upd_d.tsv',
      'run_benchmarks_release_7/pwmeval_peaks_7a+7_upd_e.tsv',
    ],
    dst: 'run_benchmarks_release_7/formatted_peaks_pwmeval.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
  },
  {
    src: [
      'run_benchmarks_release_7/VIGG_peaks.tsv',
      'run_benchmarks_release_7/VIGG_peaks_7a+7c.tsv',
      'run_benchmarks_release_7/VIGG_peaks_7a+7_upd_d.tsv',
      'run_benchmarks_release_7/VIGG_peaks_7a+7_upd_e.tsv',
    ],
    dst: 'run_benchmarks_release_7/formatted_peaks_vigg.tsv',
    metrics: ['roc_auc', 'logroc_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: [
      'run_benchmarks_release_7/centrimo.tsv',
      'run_benchmarks_release_7/centrimo_7a+7c.tsv',
      'run_benchmarks_release_7/centrimo_7a+7_upd_d.tsv',
      'run_benchmarks_release_7/centrimo_7a+7_upd_e.tsv',
    ],
    dst: 'run_benchmarks_release_7/formatted_peaks_centrimo.tsv',
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
      'run_benchmarks_release_7/pbm.tsv',
      'run_benchmarks_release_7/pbm_7a+7c.tsv',
      'run_benchmarks_release_7/pbm_7a+7_upd_d.tsv',
      'run_benchmarks_release_7/pbm_7a+7_upd_e.tsv',
      'run_benchmarks_release_7/pbm_7b+7_upd_e.tsv',
    ],
    dst: 'run_benchmarks_release_7/formatted_pbm.tsv',
    metrics: ['ASIS', 'LOG', 'EXP', 'ROC', 'PR'],
    parser: ->(info, metrics){ JSON.parse(info).values_at(*metrics) }
  },

  # Read-based
  *['0.1', '0.25', '0.5'].map{|fraction|
    {
      src: [
        "run_benchmarks_release_7/reads_#{fraction}.tsv",
        "run_benchmarks_release_7/reads_#{fraction}_7a+7c.tsv",
        "run_benchmarks_release_7/reads_#{fraction}_7a+7c_upd.tsv",
        "run_benchmarks_release_7/reads_#{fraction}_7a+7_upd_d.tsv",
        "run_benchmarks_release_7/reads_#{fraction}_7a+7_upd_e.tsv",
      ],
      dst: "run_benchmarks_release_7/formatted_reads_pwmeval_#{fraction}.tsv",
      metrics: ['AUCROC'],
      parser: ->(info, metrics){ info }
    }
  },
]

conversion_tasks.each do |conversion_task|
  metrics = conversion_task[:metrics]

  data_rows = conversion_task[:src].flat_map{|fn|
    File.readlines(fn).map{|l|
      ds, mot, info = l.chomp.split("\t")
      metrics_values = conversion_task[:parser].call(info, metrics)
      [File.basename(ds), File.basename(mot), *metrics_values]
    }
  }

  File.open(conversion_task[:dst], 'w'){|fw|
    header = ["dataset", "motif", *metrics]
    fw.puts header.join("\t")
    data_rows.each{|row|
      fw.puts(row.join("\t"))
    }
  }
end
