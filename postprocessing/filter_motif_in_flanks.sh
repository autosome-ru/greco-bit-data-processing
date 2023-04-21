mkdir -p  motifs_by_modeltype/pwm/
mkdir -p  thresholds_by_modeltype/pwm/

MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs'
for MOTIFS_RELEASE in  "release_8c.7e+8c.pack_1+2+3+4+5+6_wo_bad/"; do
  for MOTIF_TYPE in  pcm  ppm; do
    find "${MOTIFS_FOLDER}/${MOTIFS_RELEASE}" -name "*.${MOTIF_TYPE}" \
      | xargs -n1 -I{} basename -s ".${MOTIF_TYPE}" {} \
      | xargs -n1 -I{} echo \
        "ruby postprocessing/get_pwm.rb --${MOTIF_TYPE} ${MOTIFS_FOLDER}/${MOTIFS_RELEASE}/{}.${MOTIF_TYPE} > motifs_by_modeltype/pwm/{}.pwm" ;
  done
done | time parallel -j 35

find motifs_by_modeltype/pwm/ -xtype f  \
  | xargs -n1 -I{} echo  \
      java -cp ape.jar ru.autosome.ape.PrecalculateThresholds {} thresholds_by_modeltype/pwm/ --single-motif  \
  | time parallel -j 35

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
    ' | ruby postprocessing/sarus_reformatter.rb --filter-by-experiment metadata_release_8c.json {} ' \
  | parallel -j 35
}

hits_in_flanks HTS_flanks.fa '*@HTS.???@*' > HTS_flanks_hits.tsv
hits_in_flanks AFS_flanks.fa '*@AFS.???@*' > AFS_flanks_hits.tsv
hits_in_flanks SMS_unpublished_flanks.fa '*@SMS@*' > SMS_unpublished_flanks_hits.tsv
hits_in_flanks SMS_published_flanks.fa '*@SMS@*' > SMS_published_flanks_hits.tsv
