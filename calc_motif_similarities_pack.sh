for MOTIF_TYPE in ppm pcm; do
    for MOTIF_FN in $(find /home_local/vorontsovie/greco-motifs/release_7d_motifs_2021-12-21/ -xtype f -iname "*.${MOTIF_TYPE}" | sort ); do
        echo ./calc_motif_similarity.sh ${MOTIF_FN} ${MOTIF_TYPE}
    done
done | parallel -j 35 > hocomoco_similarities.tsv
