find ~/greco-motifs/release_7b_motifs_2020-10-23/ -name '*.pcm' | xargs -n1 basename -s .pcm | xargs -n1 -I{} echo 'ruby postprocessing/get_pwm.rb --pcm ~/greco-motifs/release_7b_motifs_2020-10-23/{}.pcm > motifs_by_modeltype/pwm/{}.pwm' | time parallel

find ~/greco-motifs/release_7b_motifs_2020-10-23/ -name '*.ppm' | xargs -n1 basename -s .ppm | xargs -n1 -I{} echo 'ruby postprocessing/get_pwm.rb --pfm ~/greco-motifs/release_7b_motifs_2020-10-23/{}.ppm > motifs_by_modeltype/pwm/{}.pwm' | time parallel

find motifs_by_modeltype/pwm/ -xtype f | xargs -n1 -I{} echo java -cp ape.jar ru.autosome.ape.PrecalculateThresholds {} thresholds_by_modeltype/pwm/ --single-motif | time parallel

ruby postprocessing/print_flanks.rb

hits_in_flanks() {
  FASTA="$1"
  MOTIF_GLOB="$2"
  find motifs_by_modeltype/pwm/ -xtype f -name "${MOTIF_GLOB}" \
  | xargs -n1 basename -s .pwm \
  | xargs -n1 -I{} echo \
    java -cp sarus-2.0.2.jar  \
      ru.autosome.SARUS \
        "${FASTA}" \
        motifs_by_modeltype/pwm/{}.pwm \
        besthit \
        --output-scoring-mode logpvalue \
        --pvalues-file thresholds_by_modeltype/pwm/{}.thr \
        --add-flanks \
    ' | ruby postprocessing/sarus_reformatter.rb --filter-by-experiment run_benchmarks_release_7/metadata_release_7a.json {} ' \
  | parallel
}

hits_in_flanks HTS_flanks.fa '*@HTS.???@*' > HTS_flanks_hits.tsv
# gzip -9 HTS_flanks_hits.tsv
hits_in_flanks AFS_flanks.fa '*@AFS.???@*' > AFS_flanks_hits.tsv
# gzip -9 AFS_flanks_hits.tsv

hits_in_flanks SMS_unpublished_flanks.fa '*@SMS@*' > SMS_unpublished_flanks_hits.tsv
hits_in_flanks SMS_published_flanks.fa '*@SMS@*' > SMS_published_flanks_hits.tsv

# zcat HTS_flanks_hits.tsv.gz | cuttab -f5 | ruby -e 'xs =readlines.map(&:to_f); xs.each_with_object(Hash.new(0)){|x,h| h[x.round(1)] += 1 }.sort.each{|x, cnt| puts [x,cnt].join("\t") }' > HTS_flanks_hits_histogram.tsv

# zcat HTS_flanks_hits.tsv.gz | ruby -e 'lns = readlines.map{|l| l.chomp.split("\t") }; cnts = Hash.new{|h,k| h[k] = Hash.new(0); }; lns.each{|r| x = r[4].to_f; data_type = r[0].split("@")[1]; cnts[data_type][x.round(1)] += 1 }; order = ["HTS.IVT", "HTS.Lys", "SMS", "AFS.IVT", "AFS.Lys", "CHS", "PBM.HK", "PBM.ME"]; puts ["threshold", *order].join("\t"); (0..8.5).step(0.1).map{|x| x.round(1) }.each{|x| puts [x, *cnts.values_at(*order).map{|h| h[x] / h.values.sum.to_f }].join("\t") }' > HTS_flanks_hits_histogram_by_motifType.tsv

# zcat HTS_flanks_hits.tsv.gz | ruby -e 'lns = readlines.map{|l| l.chomp.split("\t") }; cnts = Hash.new{|h,k| h[k] = Hash.new(0); }; lns.each{|r| x = r[4].to_f; data_type = r[0].split("@")[3]; cnts[data_type][x.round(1)] += 1 }; order = cnts.keys.sort; puts ["threshold", *order].join("\t"); (0..8.5).step(0.1).map{|x| x.round(1) }.each{|x| puts [x, *cnts.values_at(*order).map{|h| h[x] / h.values.sum.to_f }].join("\t") }' > HTS_flanks_hits_histogram_by_motifTeam.tsv

# zcat AFS_flanks_hits.tsv.gz | cuttab -f5 | ruby -e 'xs =readlines.map(&:to_f); xs.each_with_object(Hash.new(0)){|x,h| h[x.round(1)] += 1 }.sort.each{|x, cnt| puts [x,cnt].join("\t") }' > AFS_flanks_hits_histogram.tsv

# zcat AFS_flanks_hits.tsv.gz | ruby -e 'lns = readlines.map{|l| l.chomp.split("\t") }; cnts = Hash.new{|h,k| h[k] = Hash.new(0); }; lns.each{|r| x = r[4].to_f; data_type = r[0].split("@")[1]; cnts[data_type][x.round(1)] += 1 }; order = ["HTS.IVT", "HTS.Lys", "SMS", "AFS.IVT", "AFS.Lys", "CHS", "PBM.HK", "PBM.ME"]; puts ["threshold", *order].join("\t"); (0..8.5).step(0.1).map{|x| x.round(1) }.each{|x| puts [x, *cnts.values_at(*order).map{|h| h[x] / h.values.sum.to_f }].join("\t") }' > AFS_flanks_hits_histogram_by_motifType.tsv

# zcat AFS_flanks_hits.tsv.gz | ruby -e 'lns = readlines.map{|l| l.chomp.split("\t") }; cnts = Hash.new{|h,k| h[k] = Hash.new(0); }; lns.each{|r| x = r[4].to_f; data_type = r[0].split("@")[3]; cnts[data_type][x.round(1)] += 1 }; order = cnts.keys.sort; puts ["threshold", *order].join("\t"); (0..8.5).step(0.1).map{|x| x.round(1) }.each{|x| puts [x, *cnts.values_at(*order).map{|h| h[x] / h.values.sum.to_f }].join("\t") }' > AFS_flanks_hits_histogram_by_motifTeam.tsv

# join -j 1 -a 1 -e NA  \
#   <( zcat HTS_flanks_hits.tsv.gz | cuttab -f1,2 | sort -u | cut -f2 | sort | countuniq | awktab -e '{print $2"\t"$1}' | sort -k1,1 ) \
#   <( zcat HTS_flanks_hits.tsv.gz | awktab -e '$5 >= 4' | cuttab -f1,2 | sort -u | cut -f2 | sort | countuniq | awktab -e '{print $2"\t"$1}' | sort -k1,1 ) | sed -re 's/\s+/\t/g' > HTS_flanks_hits_motifs.tsv

# join -j 1 -a 1 -e NA  \
#   <( zcat HTS_flanks_hits.tsv.gz | cuttab -f1 | cut -d@ --output-delimiter=$'\t' -f1,3 | sed -re 's/^(\w+)\.\w+/\1/' | sort -u | cut -f1 | sort | countuniq | awktab -e '{print $2"\t"$1}' | sort -k1,1 ) \
#   <( zcat HTS_flanks_hits.tsv.gz | awktab -e '$5 >= 4' | cuttab -f1 | cut -d@ --output-delimiter=$'\t' -f1,3 | sed -re 's/^(\w+)\.\w+/\1/' | sort -u | cut -f1 | sort | countuniq | awktab -e '{print $2"\t"$1}' | sort -k1,1 ) \
#   | sed -re 's/\s+/\t/g' > HTS_flanks_hits_motifs_dataset_dedup.tsv
