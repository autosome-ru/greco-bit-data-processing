MOTIFS_FOLDER='/home_local/vorontsovie/greco-motifs/release_4.2020-10-20'

ruby rename_motifs.rb ${MOTIFS_FOLDER}

rm -rf ${MOTIFS_FOLDER}/all
mkdir -p ${MOTIFS_FOLDER}/all

cp $(find ${MOTIFS_FOLDER}/by_source/ -xtype f) ${MOTIFS_FOLDER}/all
ruby ~/motif_validator.rb $(find ${MOTIFS_FOLDER}/all -xtype f) | grep -vPe '^OK'
