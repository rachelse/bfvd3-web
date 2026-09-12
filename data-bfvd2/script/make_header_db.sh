#!/bin/bash
# Rebuild the Foldseek header DB (<db>_h) so each header is
#   "<accession> <protein name>"
# instead of the bare accession the ProteinTTT merge left behind.
#
# The previous header DB must already have been moved aside; this script refuses
# to clobber an existing <db>_h.
#
# usage: make_header_db.sh <foldseekDB> <uniprotDescTsv> <tmpDir>
set -euo pipefail

DB=${1:?foldseek db prefix}
DESC=${2:?uniprot desc tsv (Entry, Reviewed, Protein names, ...)}
TMP=${3:?tmp dir}

command -v foldseek >/dev/null || { echo "foldseek not on PATH" >&2; exit 1; }
[ -s "$DB.lookup" ] || { echo "missing $DB.lookup" >&2; exit 1; }
[ -s "$DESC" ]      || { echo "missing $DESC" >&2; exit 1; }
for f in "${DB}_h" "${DB}_h.index" "${DB}_h.dbtype"; do
    [ -e "$f" ] && { echo "refusing to overwrite existing $f -- move it aside first" >&2; exit 1; }
done
mkdir -p "$TMP"

TSV="$TMP/$(basename "$DB")_h.tsv"

# Join .lookup (key -> accession) against the description table (accession -> protein
# name).  Emits "key<TAB>accession protein_name"; entries with no name keep just the
# accession, so no header ever ends in a stray space.
echo "[1/3] building $TSV"
gawk -F'\t' -v OFS='\t' '
    NR == FNR {
        if (FNR == 1) next                      # header row of the UniProt export
        sub(/\r$/, "", $3)
        gsub(/^[ \t]+|[ \t]+$/, "", $3)
        name[$1] = $3
        next
    }
    {
        acc = $2
        n = (acc in name) ? name[acc] : ""
        if (n == "") { missing++; print $1, acc }
        else         { print $1, acc " " n }
    }
    END { if (missing) printf("  %d entries had no protein name\n", missing) > "/dev/stderr" }
' "$DESC" "$DB.lookup" > "$TSV"

lookup_n=$(wc -l < "$DB.lookup")
tsv_n=$(wc -l < "$TSV")
[ "$lookup_n" -eq "$tsv_n" ] || { echo "row count mismatch: lookup=$lookup_n tsv=$tsv_n" >&2; exit 1; }
echo "  $tsv_n rows"

echo "[2/3] foldseek tsv2db -> ${DB}_h"
foldseek tsv2db "$TSV" "${DB}_h" --output-dbtype 12

echo "[3/3] verifying against the main DB index"
main_n=$(wc -l < "$DB.index")
hdr_n=$(wc -l < "${DB}_h.index")
[ "$main_n" -eq "$hdr_n" ] || { echo "key count mismatch: $DB.index=$main_n ${DB}_h.index=$hdr_n" >&2; exit 1; }
# every key in the main index must exist in the header index
if ! diff <(cut -f1 "$DB.index" | LC_ALL=C sort) <(cut -f1 "${DB}_h.index" | LC_ALL=C sort) >/dev/null; then
    echo "key sets differ between $DB.index and ${DB}_h.index" >&2; exit 1
fi
echo "OK: ${DB}_h has $hdr_n entries, keys match $DB.index"
