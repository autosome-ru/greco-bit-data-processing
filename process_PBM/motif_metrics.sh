#!/usr/bin/env bash
set -euo pipefail

METRICS="LOG"
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
        --metrics)
            METRICS="$2"
            shift
            ;;
        --linker-opts)
            LINKER_OPTS="$2"
            shift
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

for FN in $( find "${CHIPS_SOURCE_FOLDER}" -xtype f | sort ); do
  BN=$(basename -s .txt ${FN})

  PBM_TEMP_FN="$(mktemp)"
  cat ${CHIPS_SOURCE_FOLDER}/${BN}.txt | ruby extract_chip_sequences.rb $LINKER_OPTS > "${PBM_TEMP_FN}"

  CORRELATION=$(docker run --rm \
      --security-opt apparmor=unconfined \
      --volume "${PBM_TEMP_FN}:/pbm_data.txt:ro" \
      --volume "${MOTIFS_SOURCE_FOLDER}/${BN}.pfm:/motif.pfm:ro" \
      vorontsovie/pwmbench_pbm:1.2.0 \
      ${METRICS} /pbm_data.txt /motif.pfm)
  rm "${PBM_TEMP_FN}"

  echo -e "${BN}\t${CORRELATION}"
done
