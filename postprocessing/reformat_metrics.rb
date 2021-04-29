require 'json'

def log10_str(str)
  pattern = /^(?<significand>\d+(\.\d*)?)([eE](?<exponent>[-+]?\d+))?$/
  match = str.match(pattern)
  raise "#{str} is not a positive number; can't calculate log10"  unless match
  Math.log10(Float(match[:significand])) + (match[:exponent] ? Integer(match[:exponent]) : 0)
end

conversion_tasks = [
  {
    src: 'release_6_metrics/peaks.tsv',
    dst: 'release_6_metrics/formatted_peaks.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
  },
  {
    src: 'release_6_metrics/vigg_peaks.tsv',
    dst: 'release_6_metrics/formatted_vigg_peaks.tsv',
    metrics: ['roc_auc', 'logroc_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: 'release_6_metrics/pbm.tsv',
    dst: 'release_6_metrics/formatted_pbm.tsv',
    metrics: ['ASIS', 'LOG', 'EXP', 'ROC', 'PR'],
    parser: ->(info, metrics){ JSON.parse(info).values_at(*metrics) }
  },
  {
    src: 'release_6_metrics/reads_0.1.tsv',
    dst: 'release_6_metrics/formatted_reads_0.1.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
  },
  {
    src: 'release_6_metrics/reads_0.5.tsv',
    dst: 'release_6_metrics/formatted_reads_0.5.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
  },
  {
    src: 'release_6_metrics/peaks_centrimo.tsv',
    dst: 'release_6_metrics/formatted_peaks_centrimo.tsv',
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
]

conversion_tasks.each do |conversion_task|
  File.open(conversion_task[:src]) do |f|
    File.open(conversion_task[:dst], 'w') do |fw|
      metrics = conversion_task[:metrics]
      header = ["dataset", "motif", *metrics]
      fw.puts header.join("\t")
      f.each_line{|l|
        ds, mot, info = l.chomp.split("\t")
        metrics_values = conversion_task[:parser].call(info, metrics)
        row = [File.basename(ds), File.basename(mot), *metrics_values]
        fw.puts row.join("\t")
      }
    end
  end
end
