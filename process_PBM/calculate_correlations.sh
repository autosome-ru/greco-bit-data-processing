#!/usr/bin/env bash
set -euo pipefail

CORRELATION_MODE="LOG"
WITH_LINKER="0"
while true; do
    case "${1-}" in
        --motifs-source)
            MOTIFS_SOURCE_FOLDER="$2"
            shift
            ;;
        --chips-source)
            CHIPS_SOURCE_FOLDER="$2"
            shift
            ;;
        --correlation-mode)
            CORRELATION_MODE="$2"
            shift
            ;;
        --with-linker)
            WITH_LINKER="1"
            ;;
        -?*)
            echo -e "WARN: Unknown option (ignored): $1\n" >&2
            ;;
        *)
            break
    esac
    shift
done

MOTIFS_SOURCE_FOLDER="$(readlink -m "${MOTIFS_SOURCE_FOLDER}")"
CHIPS_SOURCE_FOLDER="$(readlink -m "${CHIPS_SOURCE_FOLDER}")"

echo -e "chip\tcorrelation"

for FN in $( find "${CHIPS_SOURCE_FOLDER}" -xtype f ); do
  BN=$(basename -s .txt ${FN})

  PBM_TEMP_FN="$(mktemp)"
  if [[ "${WITH_LINKER}" -eq "1" ]]; then
    cat ${CHIPS_SOURCE_FOLDER}/${BN}.txt | awk -F $'\t' -e '($10 != "1"){print $8 "\t" $7$6}' | tail -n+2 > "${PBM_TEMP_FN}"
  else
    cat ${CHIPS_SOURCE_FOLDER}/${BN}.txt | awk -F $'\t' -e '($10 != "1"){print $8 "\t" $6}' | tail -n+2 > "${PBM_TEMP_FN}"
  fi

  CORRELATION=$(docker run --rm \
      --security-opt apparmor=unconfined \
      --volume "${PBM_TEMP_FN}:/pbm_data.txt:ro" \
      --volume "${MOTIFS_SOURCE_FOLDER}/${BN}.pfm:/motif.pfm:ro" \
      vorontsovie/pwmbench_pbm:1.1.0 \
      ${CORRELATION_MODE} /pbm_data.txt /motif.pfm)
  rm "${PBM_TEMP_FN}"

  echo -e "${BN}\t${CORRELATION}"
done
