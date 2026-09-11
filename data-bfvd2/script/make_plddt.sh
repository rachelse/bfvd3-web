#!/bin/bash
# Extract per-residue pLDDT from the structures into the afdb_plddt DbReader files.
#
# Reads B-factors straight from the PDBs rather than via foldcomp, which rebuilds
# geometry from internal coordinates and so can shift residues at a chain break -- and
# the pLDDT string is indexed positionally by the viewer.
#
# extract_plddt emits one digit per CA atom found, so missing residues would shorten the
# string; validate.sh checks length parity against afdb rather than trusting it.
#
# Usage: make_plddt.sh <farm> <bin/extract_plddt> <tmp-dir> <out-prefix> [jobs]
set -euo pipefail

FARM="${1:?structure farm}"
EXTRACT="${2:?extract_plddt binary}"
TMP="${3:?tmp dir}"
OUT="${4:?out prefix}"
JOBS="${5:-8}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -x "$EXTRACT" ] || { echo "not executable: $EXTRACT" >&2; exit 1; }
if [ "$(find "$FARM" -xtype l -print -quit | wc -l)" -ne 0 ]; then
    echo "FAIL: $FARM still has dangling symlinks; run relink_final_pdb.py first" >&2
    exit 1
fi

mkdir -p "$TMP/plddt_shards"
echo "extracting from $(ls -d "$FARM"/*/ | wc -l) shards with $JOBS jobs ..."
ls -d "$FARM"/*/ \
  | xargs -P "$JOBS" -I{} bash -c \
      'd="{}"; n=$(basename "$d"); "$0" "$d" > "$1/plddt_shards/$n.tsv"' \
      "$EXTRACT" "$TMP"

echo "merging and sorting ..."
cat "$TMP"/plddt_shards/*.tsv \
  | awk '{ sub(/\.pdb$/, "", $1); print $1"\t"$3 }' \
  | LC_ALL=C sort -k1,1 > "$TMP/v2_plddt.tsv"

echo "records: $(wc -l < "$TMP/v2_plddt.tsv")"
"$HERE/mkdb.awk" -v outfile="$OUT" "$TMP/v2_plddt.tsv"
echo "index:   $(wc -l < "${OUT}.index")"
rm -rf "$TMP/plddt_shards"
