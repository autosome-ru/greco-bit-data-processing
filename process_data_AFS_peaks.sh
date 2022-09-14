SOURCE_FOLDER=./source_data/AFS/
SCRIPT_FOLDER=./process_peaks_CHS_AFS/

RESULTS_FOLDER=./source_data_prepared/AFS.Peaks

# It's essential that IVT and Lysate datasets are stored into different intermediate folders: they can conflict
for EXP_TYPE in IVT Lysate GFPIVT; do
  INTERMEDIATE_FOLDER=./results_databox_afs_${EXP_TYPE}
  mkdir -p "${INTERMEDIATE_FOLDER}"
  ruby "${SCRIPT_FOLDER}/prepare_peaks_affiseq.rb" "${SOURCE_FOLDER}" "${INTERMEDIATE_FOLDER}" \
    --qc-file source_data_meta/AFS/metrics_by_exp.tsv \
    --qc-file source_data_meta/AFS/metrics_by_exp_affseq_jun2021.tsv \
    --qc-file source_data_meta/AFS/metrics_by_exp_affseq_apr2022.tsv \
    --experiment-type ${EXP_TYPE} \
    2> affiseq_${EXP_TYPE}_peaks.log
done

for EXP_TYPE in IVT Lysate GFPIVT; do
  INTERMEDIATE_FOLDER=./results_databox_afs_${EXP_TYPE}/
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
done

for EXP_TYPE in IVT Lysate GFPIVT; do
  (
    INTERMEDIATE_FOLDER=./results_databox_afs_${EXP_TYPE}/
    for SLICE_TYPE in Train Val; do
      mkdir -p ${RESULTS_FOLDER}/${SLICE_TYPE}_intervals
      mkdir -p ${RESULTS_FOLDER}/${SLICE_TYPE}_sequences

      for FN in $(find ${INTERMEDIATE_FOLDER}/${SLICE_TYPE}_intervals/ -xtype f ); do
          # BN=$(basename -s .pbm.txt ${FN})
          NEW_BN=$( ruby shared/bin/name_sample_afs.rb "$FN" \
            --processing-type Peaks --slice-type ${SLICE_TYPE} --extension peaks \
            --qc-file source_data_meta/AFS/metrics_by_exp.tsv \
            --qc-file source_data_meta/AFS/metrics_by_exp_affseq_jun2021.tsv \
            --qc-file source_data_meta/AFS/metrics_by_exp_affseq_apr2022.tsv \
          )
          if [[ -n "$NEW_BN" ]]; then
              cp ${FN} ${RESULTS_FOLDER}/${SLICE_TYPE}_intervals/${NEW_BN}
          else
              echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
          fi
      done

      for FN in $(find ${INTERMEDIATE_FOLDER}/${SLICE_TYPE}_sequences/ -xtype f ); do
          # BN=$(basename -s .pbm.txt ${FN})
          NEW_BN=$( ruby shared/bin/name_sample_afs.rb "$FN" \
            --processing-type Peaks --slice-type ${SLICE_TYPE} --extension fa \
            --qc-file source_data_meta/AFS/metrics_by_exp.tsv \
            --qc-file source_data_meta/AFS/metrics_by_exp_affseq_jun2021.tsv \
            --qc-file source_data_meta/AFS/metrics_by_exp_affseq_apr2022.tsv \
          )
          if [[ -n "$NEW_BN" ]]; then
              cp ${FN} ${RESULTS_FOLDER}/${SLICE_TYPE}_sequences/${NEW_BN}
          else
              echo "Can't get filename for ${FN}. Probably no metadata supplied" >& 2
          fi
      done
    done
  ) 2> affiseq_${EXP_TYPE}_renaming.log
done

for EXP_TYPE in IVT Lysate GFPIVT; do
  INTERMEDIATE_FOLDER=./results_databox_afs_2_${EXP_TYPE}
  for FN in $(find ${INTERMEDIATE_FOLDER}/complete_data/ -xtype f ); do
    BN=$(basename "${FN}")
    echo ">${BN}"
    ruby shared/bin/name_sample_afs.rb "${FN}" --mode find --no-slice-type --extension peaks --processing-type Peaks \
      --folder ~/greco-data/release_8d.2022-07-31/full/AFS.Peaks/Train_intervals/ \
      --folder ~/greco-data/release_8d.2022-07-31/full/AFS.Peaks/Val_intervals/ \
      --qc-file source_data_meta/AFS/metrics_by_exp.tsv \
      --qc-file source_data_meta/AFS/metrics_by_exp_affseq_jun2021.tsv \
      --qc-file source_data_meta/AFS/metrics_by_exp_affseq_apr2022.tsv
  done > ${INTERMEDIATE_FOLDER}/complete_data_mapping_${EXP_TYPE}_peaks.txt

  for FN in $(find ${INTERMEDIATE_FOLDER}/complete_data/ -xtype f ); do
    BN=$(basename "${FN}")
    echo ">${BN}"
    ruby shared/bin/name_sample_afs.rb "${FN}" --mode find --no-slice-type --extension fa --processing-type Peaks \
      --folder ~/greco-data/release_8d.2022-07-31/full/AFS.Peaks/Train_sequences/ \
      --folder ~/greco-data/release_8d.2022-07-31/full/AFS.Peaks/Val_sequences/ \
      --qc-file source_data_meta/AFS/metrics_by_exp.tsv \
      --qc-file source_data_meta/AFS/metrics_by_exp_affseq_jun2021.tsv \
      --qc-file source_data_meta/AFS/metrics_by_exp_affseq_apr2022.tsv
  done > ${INTERMEDIATE_FOLDER}/complete_data_mapping_${EXP_TYPE}_sequences.txt
done
