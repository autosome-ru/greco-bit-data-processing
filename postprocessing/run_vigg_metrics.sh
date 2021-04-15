#!/usr/bin/env bash
set -euo pipefail
DATASET="$1"
MOTIF="$2"
ASSEMBLY_PATH="$3"
ASSEMBLY="$4"

MOTIF_EXT="${MOTIF##*.}"

# echo "docker run --rm " \
#  "--tmpfs /tmp " \
#  "--security-opt apparmor=unconfined " \
#  "--volume ${ASSEMBLY_PATH}:/assembly"  \
#  "--volume ${DATASET}:/peaks:ro"  \
#  "--volume ${MOTIF}:/motif.${MOTIF_EXT}:ro"  \
#  "vorontsovie/motif_pseudo_roc:v2.0.1"  \
#  "--assembly-name ${ASSEMBLY}" \
#  "--peak-format 1,2,3,summit:abs:4" >&2

echo -ne "${DATASET}\t${MOTIF}\t"

docker run --rm  \
 --tmpfs /tmp  \
 --security-opt apparmor=unconfined  \
 --volume "${ASSEMBLY_PATH}:/assembly"  \
 --volume "${DATASET}:/peaks:ro"  \
 --volume "${MOTIF}:/motif.${MOTIF_EXT}:ro"  \
 vorontsovie/motif_pseudo_roc:v2.0.1  \
 --assembly-name "${ASSEMBLY}" \
 --peak-format 1,2,3,summit:abs:4
