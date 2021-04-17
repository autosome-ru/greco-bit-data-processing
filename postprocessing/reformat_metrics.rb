require 'json'

conversion_tasks = [
  {
    src: 'results/pbm_metrics.txt',
    dst: 'results/parsed_pbm_metrics.tsv',
    metrics: ['ASIS', 'LOG', 'EXP', 'ROC', 'PR'],
    parser: ->(info, metrics){ JSON.parse(info).values_at(*metrics) }
  },
  {
    src: 'results/vigg_peaks_metrics.txt',
    dst: 'results/parsed_vigg_peaks_metrics.tsv',
    metrics: ['roc_auc', 'logroc_auc'],
    parser: ->(info, metrics){ JSON.parse(info)["metrics"].values_at(*metrics) }
  },
  {
    src: 'results/chipseq_affiseq_metrics.txt',
    dst: 'results/parsed_chipseq_affiseq_metrics.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
  },
  {
    src: 'results/selex_0.1_metrics.txt',
    dst: 'parsed_selex_0.1_metrics.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
  },
  {
    src: 'results/selex_0.5_metrics.txt',
    dst: 'parsed_selex_0.5_metrics.tsv',
    metrics: ['AUCROC'],
    parser: ->(info, metrics){ info }
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
