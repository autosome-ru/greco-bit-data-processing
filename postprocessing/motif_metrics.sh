#!/usr/bin/env bash
mkdir -p results
ruby motif_metrics_pbm.rb | parallel > results/pbm_metrics.txt
ruby motif_metrics_selex.rb --fraction 0.1 | parallel > results/selex_0.1_metrics.txt
ruby motif_metrics_selex.rb --fraction 0.5 | parallel > results/selex_0.5_metrics.txt
ruby motif_metrics_chipseq_affiseq.rb | parallel > results/chipseq_affiseq_metrics.txt
ruby motif_metrics_VIGG_peaks.rb | parallel > results/vigg_peaks_metrics.txt

# ROCLOG and PRLOG are equivalently ranked to ROC/PR so we don't care about them
cat results/pbm_metrics.txt | ruby -r json -e 'metrics = %w[ASIS LOG EXP ROC PR]; puts(["dataset", "motif", *metrics].join("\t")); $stdin.each_line{|l| ds, mot, info = l.chomp.split("\t"); puts([File.basename(ds), File.basename(mot), JSON.parse(info).values_at(*metrics)].join("\t")) }' > results/parsed_pbm_metrics.tsv
cat results/selex_metrics.txt | ruby -e 'puts(["dataset", "motif", "AUCROC"].join("\t")); $stdin.each_line{|l| ds, mot, aucroc = l.chomp.split("\t"); puts([File.basename(ds), File.basename(mot), aucroc].join("\t")) }' > results/parsed_selex_metrics.tsv
cat results/chipseq_affiseq_metrics.txt | ruby -e 'puts(["dataset", "motif", "AUCROC"].join("\t")); $stdin.each_line{|l| ds, mot, aucroc = l.chomp.split("\t"); puts([File.basename(ds), File.basename(mot), aucroc].join("\t")) }' > results/parsed_chipseq_affiseq_metrics.tsv
cat results/vigg_peaks_metrics.txt | ruby -r json -e 'metrics = %w[roc_auc logroc_auc]; puts(["dataset", "motif", *metrics].join("\t")); $stdin.each_line{|l| ds, mot, info = l.chomp.split("\t"); puts([File.basename(ds), File.basename(mot), JSON.parse(info)["metrics"].values_at(*metrics)].join("\t")) }' > results/parsed_vigg_peaks_metrics.tsv
