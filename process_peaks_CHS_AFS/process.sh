#!/usr/bin/env bash
SOURCE_FOLDER="./source_data/affiseq"
RESULTS_FOLDER="./results/affiseq/"
# ln -s /home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval "${SOURCE_FOLDER}/peaks-intervals"

mkdir -p "${RESULTS_FOLDER}"
cat "${SOURCE_FOLDER}/metrics_by_exp.tsv" | tail -n+2 | cut -d $'\t' -f2,4 | awk -F $'\t' -e '$1 != "CONTROL" && $1 != ""' > "${RESULTS_FOLDER}/tf_peaks.txt"

TRAIN_CHR="$(seq 1 2 21)" # odd
VALIDATION_CHR="$(seq 2 2 22)" # even

for PEAK_CALLER in cpics gem macs2-pemode sissrs; do
	for FN in $(find "${SOURCE_FOLDER}/peaks-intervals/${PEAK_CALLER}" -xtype f -iname '*.interval'); do
		BN="$( basename -s .interval )"
		ruby split_train_val.rb "${FN}" "${RESULTS_FOLDER}/train/peaks-intervals/${PEAK_CALLER}/${BN}.interval" "${RESULTS_FOLDER}/validation/peaks-intervals/${PEAK_CALLER}/${BN}.interval"
	done
done
