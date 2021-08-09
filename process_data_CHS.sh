SOURCE_FOLDER=./source_data/CHS
RESULTS_FOLDER=./source_data_prepared/CHS
SCRIPT_FOLDER=./process_peaks_CHS_AFS

INTERMEDIATE_FOLDER=./results_databox_chs_batch1
METRICS_FN='source_data_meta/CHS/metrics_by_exp.tsv'

# INTERMEDIATE_FOLDER=./results_databox_chs_batch2
# METRICS_FN='source_data_meta/CHS/metrics_by_exp_chipseq_feb2021.tsv'

# INTERMEDIATE_FOLDER=./results_databox_chs_batch3/
# METRICS_FN='source_data_meta/CHS/metrics_by_exp_chipseq_jun2021.tsv'

mkdir -p "${INTERMEDIATE_FOLDER}"

ruby "${SCRIPT_FOLDER}/prepare_peaks_chipseq.rb" "${SOURCE_FOLDER}" "${INTERMEDIATE_FOLDER}" "${METRICS_FN}"

mkdir -p ${INTERMEDIATE_FOLDER}/Train_sequences/
for FN in $(find ${INTERMEDIATE_FOLDER}/Train_intervals/ -xtype f); do
  TF="$(basename -s .interval "$FN")"
  cat ${FN} | tail -n+2 | sort -k5,5nr | head -500 | ./bedtools getfasta -fi ./source_data/hg38.fa -bed - > ${INTERMEDIATE_FOLDER}/Train_sequences/${TF}.fa
done

mkdir -p ${INTERMEDIATE_FOLDER}/Val_sequences/
for FN in $(find ${INTERMEDIATE_FOLDER}/Val_intervals/ -xtype f); do
  TF="$(basename -s .interval "$FN")"
  cat ${FN} | tail -n+2 | sort -k5,5nr | head -500 | ./bedtools getfasta -fi ./source_data/hg38.fa -bed - > ${INTERMEDIATE_FOLDER}/Val_sequences/${TF}.fa
done


mkdir -p ${RESULTS_FOLDER}/Train_intervals ${RESULTS_FOLDER}/Val_intervals
mkdir -p ${RESULTS_FOLDER}/Train_sequences ${RESULTS_FOLDER}/Val_sequences

for FN in $(find ${INTERMEDIATE_FOLDER}/Train_intervals/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --extension peaks )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} ${RESULTS_FOLDER}/Train_intervals/${NEW_BN}
    else
        true # echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done

for FN in $(find ${INTERMEDIATE_FOLDER}/Val_intervals/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --extension peaks )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} ${RESULTS_FOLDER}/Val_intervals/${NEW_BN}
    else
        true # echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done

for FN in $(find ${INTERMEDIATE_FOLDER}/Train_sequences/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --extension fa )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} ${RESULTS_FOLDER}/Train_sequences/${NEW_BN}
    else
        true # echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done

for FN in $(find ${INTERMEDIATE_FOLDER}/Val_sequences/ -xtype f ); do
    # BN=$(basename -s .pbm.txt ${FN})
    NEW_BN=$( ruby ${SCRIPT_FOLDER}/name_sample_chs.rb "$FN" --extension fa )
    if [[ -n "$NEW_BN" ]]; then
        cp ${FN} ${RESULTS_FOLDER}/Val_sequences/${NEW_BN}
    else
        true # echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
    fi
done
