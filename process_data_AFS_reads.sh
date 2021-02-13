source .venv/bin/activate
python3 process_reads_HTS_SMS_AFS/extract_affiseq_reads.py
deactivate

for EXP_TYPE in IVT Lysate; do
  RESULTS_FOLDER=./results_databox_afs_reads_${EXP_TYPE}/
  for SLICE_TYPE in Train Val; do
    mkdir -p source_data_prepared/AFS.Reads/${SLICE_TYPE}_sequences

    for FN in $(find ${RESULTS_FOLDER}/${SLICE_TYPE}_sequences/ -xtype f ); do
        # BN=$(basename -s .pbm.txt ${FN})
        NEW_BN=$( ruby shared/bin/name_sample_afs.rb "$FN" --processing-type Reads --slice-type ${SLICE_TYPE} --extension fa )
        if [[ -n "$NEW_BN" ]]; then
            cp ${FN} source_data_prepared/AFS.Reads/${SLICE_TYPE}_sequences/${NEW_BN}
        else
            echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
        fi
    done
  done
done
