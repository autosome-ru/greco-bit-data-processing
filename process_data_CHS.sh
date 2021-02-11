SOURCE_FOLDER=./source_data/CHS/
RESULTS_FOLDER=./results_databox_chs/
SCRIPT_FOLDER=./process_peaks_CHS_AFS/

mkdir -p "${RESULTS_FOLDER}"

ruby "${SCRIPT_FOLDER}/prepare_peaks_chipseq.rb" "${SOURCE_FOLDER}" "${RESULTS_FOLDER}"

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


mkdir -p source_data_prepared/CHS/Train_intervals source_data_prepared/CHS/Val_intervals 
mkdir -p source_data_prepared/CHS/Train_sequences source_data_prepared/CHS/Val_sequences 

for FN in $(find ${RESULTS_FOLDER}/Train_intervals/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --slice-type Train --extension peaks )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} source_data_prepared/CHS/Train_intervals/${NEW_BN}
    else
        echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done

for FN in $(find ${RESULTS_FOLDER}/Val_intervals/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --slice-type Val --extension peaks )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} source_data_prepared/CHS/Val_intervals/${NEW_BN}
    else
        echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done

for FN in $(find ${RESULTS_FOLDER}/Train_sequences/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --slice-type Train --extension fa )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} source_data_prepared/CHS/Train_sequences/${NEW_BN}
    else
        echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done

for FN in $(find ${RESULTS_FOLDER}/Val_sequences/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --slice-type Val --extension fa )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} source_data_prepared/CHS/Val_sequences/${NEW_BN}
    else
        echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done