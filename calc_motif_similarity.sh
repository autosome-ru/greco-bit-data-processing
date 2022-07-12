#!/bin/bash
MOTIF_FN="$1"
MOTIF_TYPE="$2"
COLLECTION_FOLDER="$3"
MOTIF_BN="$(basename "${MOTIF_FN}")"
echo -ne ${MOTIF_BN} '\t'
java -Xmx1G -cp ape.jar ru.autosome.macroape.ScanCollection \
            "${MOTIF_FN}" "${COLLECTION_FOLDER}" \
            --query-${MOTIF_TYPE} --all --pvalue 0.0005 --rough-discretization 1 \
      | grep -vPe '^#' | ruby -e 'puts readlines.last' \
 || echo fail
