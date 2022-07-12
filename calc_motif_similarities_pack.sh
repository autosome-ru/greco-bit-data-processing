MOTIFS_FOLDER="$1"
COLLECTION_FOLDER="$2"
for MOTIF_TYPE in ppm pcm; do
    for MOTIF_FN in $(find "${MOTIFS_FOLDER}" -xtype f -iname "*.${MOTIF_TYPE}" | sort ); do
        echo ./calc_motif_similarity.sh "${MOTIF_FN}" "${MOTIF_TYPE}" "${COLLECTION_FOLDER}"
    done
done
