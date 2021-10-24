find ~/greco-motifs/release_7b_motifs_2020-10-23/ -name '*.pcm' | xargs -n1 basename -s .pcm | xargs -n1 -I{} echo 'ruby postprocessing/get_pwm.rb --pcm ~/greco-motifs/release_7b_motifs_2020-10-23/{}.pcm > motifs_by_modeltype/pwm/{}.pwm' | time parallel

find ~/greco-motifs/release_7b_motifs_2020-10-23/ -name '*.ppm' | xargs -n1 basename -s .ppm | xargs -n1 -I{} echo 'ruby postprocessing/get_pwm.rb --pfm ~/greco-motifs/release_7b_motifs_2020-10-23/{}.ppm > motifs_by_modeltype/pwm/{}.pwm' | time parallel

find motifs_by_modeltype/pwm/ -xtype f | xargs -n1 -I{} echo java -cp ape.jar ru.autosome.ape.PrecalculateThresholds {} thresholds_by_modeltype/pwm/ --single-motif | time parallel

ruby postprocessing/print_flanks.rb

find motifs_by_modeltype/pwm/ -xtype f \
  | xargs -n1 basename -s .pwm \
  | xargs -n1 -I{} echo \
    java -cp sarus-2.0.2.jar  \
      ru.autosome.SARUS \
        HTS_flanks.fa \
        motifs_by_modeltype/pwm/{}.pwm \
        besthit \
        --output-scoring-mode logpvalue \
        --pvalues-file thresholds_by_modeltype/pwm/{}.thr \
        --add-flanks \
    ' | ruby postprocessing/sarus_reformatter.rb --filter-by-tf {} ' \
  | parallel \
  > HTS_flanks_hits.tsv
gzip -9 HTS_flanks_hits.tsv


find motifs_by_modeltype/pwm/ -xtype f \
  | xargs -n1 basename -s .pwm \
  | xargs -n1 -I{} echo \
    java -cp sarus-2.0.2.jar  \
      ru.autosome.SARUS \
        AFS_flanks.fa \
        motifs_by_modeltype/pwm/{}.pwm \
        besthit \
        --output-scoring-mode logpvalue \
        --pvalues-file thresholds_by_modeltype/pwm/{}.thr \
        --add-flanks \
    ' | ruby postprocessing/sarus_reformatter.rb {} ' \
  | parallel \
  > AFS_flanks_hits.tsv
gzip -9 AFS_flanks_hits.tsv


zcat HTS_flanks_hits.tsv.gz | cuttab -f5 | ruby -e 'xs =readlines.map(&:to_f); xs.each_with_object(Hash.new(0)){|x,h| h[x.round(1)] += 1 }.sort.each{|x, cnt| puts [x,cnt].join("\t") }' > HTS_flanks_hits_histogram.tsv

zcat HTS_flanks_hits.tsv.gz | ruby -e 'lns = readlines.map{|l| l.chomp.split("\t") }; cnts = Hash.new{|h,k| h[k] = Hash.new(0); }; lns.each{|r| x = r[4].to_f; data_type = r[0].split("@")[1]; cnts[data_type][x.round(1)] += 1 }; order = ["HTS.IVT", "HTS.Lys", "SMS", "AFS.IVT", "AFS.Lys", "CHS", "PBM.HK", "PBM.ME"]; puts ["threshold", *order].join("\t"); (0..8.5).step(0.1).map{|x| x.round(1) }.each{|x| puts [x, *cnts.values_at(*order).map{|h| h[x] / h.values.sum.to_f }].join("\t") }' > HTS_flanks_hits_histogram_by_motifType.tsv

zcat HTS_flanks_hits.tsv.gz | ruby -e 'lns = readlines.map{|l| l.chomp.split("\t") }; cnts = Hash.new{|h,k| h[k] = Hash.new(0); }; lns.each{|r| x = r[4].to_f; data_type = r[0].split("@")[3]; cnts[data_type][x.round(1)] += 1 }; order = cnts.keys.sort; puts ["threshold", *order].join("\t"); (0..8.5).step(0.1).map{|x| x.round(1) }.each{|x| puts [x, *cnts.values_at(*order).map{|h| h[x] / h.values.sum.to_f }].join("\t") }' > HTS_flanks_hits_histogram_by_motifTeam.tsv
