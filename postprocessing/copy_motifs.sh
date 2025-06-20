#!/usr/bin/env bash
CUR_DIRNAME=$(dirname $(readlink -f $0))
MOTIFS_DESTINATION=/home_local/vorontsovie/greco-bit-data-processing/release_6_motifs

mkdir -p ${MOTIFS_DESTINATION}/VIGG/
cp -Tr /home_local/arsen_l/greco-bit/motifs/motif_collection_release_6.2021-02-13/HTS/pcms  ${MOTIFS_DESTINATION}/VIGG/HTS
cp -Tr /home_local/arsen_l/greco-bit/motifs/motif_collection_release_6.2021-02-13/SMS/pcms  ${MOTIFS_DESTINATION}/VIGG/SMS
cp -Tr /home_local/arsen_l/greco-bit/motifs/motif_collection_release_6.2021-02-13/AFS.Reads/pcms  ${MOTIFS_DESTINATION}/VIGG/AFS.Reads
cp -Tr /home_local/vorontsovie/greco-bit-data-processing/process_PBM/release_6_motifs/pcms  ${MOTIFS_DESTINATION}/VIGG/PBM

mkdir -p ${MOTIFS_DESTINATION}/jangrau/
cp -r /home_local/jangrau/models/{AFS,CHS,SMS,SMS.published}  ${MOTIFS_DESTINATION}/jangrau

# Jan Grau PBM-s and HTS-s, Oriol Fornes? Timothy Hughes and Pavel Kravchenko data
#   are processed in motif_reformatting.rb
ruby ${CUR_DIRNAME}/motif_reformatting.rb
