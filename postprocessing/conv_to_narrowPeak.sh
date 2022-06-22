#!/usr/bin/env sh
PEAKS_FN="$1"
cat "$PEAKS_FN" | tail -n+2 | cut -d $'\t' -f 1-9 | awk -F $'\t' -e '{print $0 "\t" ($4-$2)}'
