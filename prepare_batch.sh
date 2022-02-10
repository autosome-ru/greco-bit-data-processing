RELEASE=release_8.2022-02-10_v0.1
ruby shared/lib/symlink_folder_content.rb /home_local/vorontsovie/greco-data/release_7a.2021-10-14/full ${RELEASE}/full/ symlink
rm ${RELEASE}/full/AFS.Peaks/ -r
rm ${RELEASE}/full/AFS.Reads/ -r
rm ${RELEASE}/full/CHS/ -r

ruby shared/lib/symlink_folder_content.rb source_data_prepared/SMS/ ${RELEASE}/novel/SMS copy
ruby shared/lib/symlink_folder_content.rb ${RELEASE}/novel/SMS ${RELEASE}/full/SMS symlink

ruby shared/lib/symlink_folder_content.rb source_data_prepared/HTS/ ${RELEASE}/novel/HTS copy
ruby shared/lib/symlink_folder_content.rb ${RELEASE}/novel/HTS ${RELEASE}/full/HTS symlink

for EXPERIMENT_SUBTYPE in SDQN QNZS; do
    ruby shared/lib/symlink_folder_content.rb /home_local/vorontsovie/greco-data/release_6.2021-02-13/PBM.${EXPERIMENT_SUBTYPE} ${RELEASE}/full/PBM.${EXPERIMENT_SUBTYPE} symlink
    for PROCESSING_TYPE in intensities sequences; do
        mkdir -p ${RELEASE}/novel/PBM.${EXPERIMENT_SUBTYPE}/Train_${PROCESSING_TYPE}/
        mkdir -p ${RELEASE}/novel/PBM.${EXPERIMENT_SUBTYPE}/Val_${PROCESSING_TYPE}/
        mkdir -p ${RELEASE}/full/PBM.${EXPERIMENT_SUBTYPE}/Train_${PROCESSING_TYPE}/
        mkdir -p ${RELEASE}/full/PBM.${EXPERIMENT_SUBTYPE}/Val_${PROCESSING_TYPE}/
        for FN in $( find source_data_prepared/PBM.${EXPERIMENT_SUBTYPE}/Train_${PROCESSING_TYPE} -xtype f -name '*@PBM.HK@*' ); do
            BN=$(basename $FN)
            cp ${FN} ${RELEASE}/novel/PBM.${EXPERIMENT_SUBTYPE}/Train_${PROCESSING_TYPE}/${BN}
            ln ${RELEASE}/novel/PBM.${EXPERIMENT_SUBTYPE}/Train_${PROCESSING_TYPE}/${BN} ${RELEASE}/full/PBM.${EXPERIMENT_SUBTYPE}/Train_${PROCESSING_TYPE}/${BN}
        done

        for FN in $( find source_data_prepared/PBM.${EXPERIMENT_SUBTYPE}/Val_${PROCESSING_TYPE} -xtype f -name '*@PBM.ME@*' ); do
            BN=$(basename $FN)
            cp ${FN} ${RELEASE}/novel/PBM.${EXPERIMENT_SUBTYPE}/Val_${PROCESSING_TYPE}/${BN}
            ln ${RELEASE}/novel/PBM.${EXPERIMENT_SUBTYPE}/Val_${PROCESSING_TYPE}/${BN} ${RELEASE}/full/PBM.${EXPERIMENT_SUBTYPE}/Val_${PROCESSING_TYPE}/${BN}
        done
    done
done

ruby shared/lib/symlink_folder_content.rb source_data_prepared/CHS ${RELEASE}/novel/CHS copy
ruby shared/lib/symlink_folder_content.rb ${RELEASE}/novel/CHS ${RELEASE}/full/CHS symlink

ruby shared/lib/symlink_folder_content.rb source_data_prepared/AFS.Peaks ${RELEASE}/novel/AFS.Peaks copy
ruby shared/lib/symlink_folder_content.rb ${RELEASE}/novel/AFS.Peaks ${RELEASE}/full/AFS.Peaks symlink

ruby shared/lib/symlink_folder_content.rb source_data_prepared/AFS.Reads_batch1 ${RELEASE}/novel/AFS.Reads copy
ruby shared/lib/symlink_folder_content.rb source_data_prepared/AFS.Reads ${RELEASE}/novel/AFS.Reads copy
ruby shared/lib/symlink_folder_content.rb ${RELEASE}/novel/AFS.Reads ${RELEASE}/full/AFS.Reads symlink

find ${RELEASE}/ -name 'stats.tsv' | xargs -n1 rm
