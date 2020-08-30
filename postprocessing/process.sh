ruby rename_motifs.rb
ruby ~/motif_validator.rb $(find /home_local/vorontsovie/greco-motifs/release_3_motifs_2020-08-30 -xtype f) | grep -vPe '^OK'
mkdir -p data/all_motifs
cp $(find /home_local/vorontsovie/greco-motifs/release_3_motifs_2020-08-30/source_data/ -xtype f) data/all_motifs
