SOURCE_FOLDER=./source_data/AFS/
RESULTS_FOLDER=./results_databox_afs/
SCRIPT_FOLDER=./process_peaks_CHS_AFS/

mkdir -p "${RESULTS_FOLDER}"

ruby "${SCRIPT_FOLDER}/prepare_peaks_affiseq.rb" "${SOURCE_FOLDER}" "${RESULTS_FOLDER}"

mkdir -p ${RESULTS_FOLDER}/Train_sequences/
for FN in $(find ${RESULTS_FOLDER}/Train_intervals/ -xtype f); do
  TF="$(basename -s .interval "$FN")"
  cat ${FN} | tail -n+2 | sort -k5,5nr | head -500 | ./bedtools getfasta -fi ./source_data/hg38.fa -bed - > ${RESULTS_FOLDER}/Train_sequences/${TF}.fa
done

mkdir -p ${RESULTS_FOLDER}/Val_sequences/
for FN in $(find ${RESULTS_FOLDER}/Val_intervals/ -xtype f); do
  TF="$(basename -s .interval "$FN")"
  cat ${FN} | tail -n+2 | sort -k5,5nr | head -500 | ./bedtools getfasta -fi ./source_data/hg38.fa -bed - > ${RESULTS_FOLDER}/Val_sequences/${TF}.fa
done

for SLICE_TYPE in Train Val; do
  mkdir -p source_data_prepared/AFS/${SLICE_TYPE}_intervals
  mkdir -p source_data_prepared/AFS/${SLICE_TYPE}_sequences

  for FN in $(find ${RESULTS_FOLDER}/${SLICE_TYPE}_intervals/ -xtype f ); do
      # BN=$(basename -s .pbm.txt ${FN})
      NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_afs.rb "$FN" --slice-type ${SLICE_TYPE} --extension peaks )
      if [[ -n "$NEW_BN" ]]; then
          cp ${FN} source_data_prepared/AFS/${SLICE_TYPE}_intervals/${NEW_BN}
      else
          echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
      fi
  done

  for FN in $(find ${RESULTS_FOLDER}/${SLICE_TYPE}_sequences/ -xtype f ); do
      # BN=$(basename -s .pbm.txt ${FN})
      NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_afs.rb "$FN" --slice-type ${SLICE_TYPE} --extension fa )
      if [[ -n "$NEW_BN" ]]; then
          cp ${FN} source_data_prepared/AFS/${SLICE_TYPE}_sequences/${NEW_BN}
      else
          echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
      fi
  done
done
