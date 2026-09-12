#!/bin/bash
# Attach an NCBI taxonomy to the Foldseek DB, reusing the taxids UniProt already
# assigned to each accession rather than re-deriving them.
#
# Produces <db>_mapping (db key -> taxid) and <db>_taxonomy (binary NCBI tree).
#
# usage: make_taxdb.sh <foldseekDB> <accTaxidTsv> <taxdumpDir> <tmpDir>
#   accTaxidTsv: accession in col 1, taxid in col 2 (extra columns ignored)
set -euo pipefail

DB=${1:?foldseek db prefix}
SRC=${2:?acc->taxid tsv}
TAXDUMP=${3:?ncbi taxdump dir}
TMP=${4:?tmp dir}

command -v mmseqs >/dev/null || { echo "mmseqs not on PATH" >&2; exit 1; }
[ -s "$DB.lookup" ] || { echo "missing $DB.lookup" >&2; exit 1; }
[ -s "$SRC" ]       || { echo "missing $SRC" >&2; exit 1; }
for f in nodes.dmp names.dmp merged.dmp delnodes.dmp; do
    [ -s "$TAXDUMP/$f" ] || { echo "missing $TAXDUMP/$f" >&2; exit 1; }
done
mkdir -p "$TMP"

MAP="$TMP/$(basename "$DB")_acc_taxid.tsv"

# --tax-mapping-mode 0 resolves names through .lookup, so the mapping file is keyed by
# accession.  Restrict it to accessions the DB actually contains and check every one is
# covered -- a silently short mapping would leave entries untaxed.
echo "[1/3] building $MAP"
LC_ALL=C gawk -F'\t' -v OFS='\t' '
    NR == FNR { want[$2] = 1; next }
    ($1 in want) { print $1, $2; seen[$1] = 1 }
    END {
        for (a in want) if (!(a in seen)) miss++
        if (miss) { printf("%d DB accessions have no taxid\n", miss) > "/dev/stderr"; exit 1 }
    }
' "$DB.lookup" "$SRC" > "$MAP"

lookup_n=$(wc -l < "$DB.lookup")
map_n=$(wc -l < "$MAP")
[ "$lookup_n" -eq "$map_n" ] || { echo "row count mismatch: lookup=$lookup_n mapping=$map_n" >&2; exit 1; }
echo "  $map_n accessions mapped"

echo "[2/3] mmseqs createtaxdb -> ${DB}_mapping, ${DB}_taxonomy"
rm -rf "$TMP/createtaxdb"
mmseqs createtaxdb "$DB" "$TMP/createtaxdb" \
    --ncbi-tax-dump "$TAXDUMP" \
    --tax-mapping-file "$MAP" \
    --tax-mapping-mode 0 \
    --tax-db-mode 1

echo "[3/3] verifying"
[ -s "${DB}_mapping" ]  || { echo "no ${DB}_mapping produced" >&2; exit 1; }
[ -s "${DB}_taxonomy" ] || { echo "no ${DB}_taxonomy produced" >&2; exit 1; }
mapping_n=$(wc -l < "${DB}_mapping")
echo "  ${DB}_mapping:  $mapping_n rows (DB has $lookup_n entries)"
echo "  ${DB}_taxonomy: $(stat -c%s "${DB}_taxonomy") bytes"
# Cross-check the mapping against the source: key -> accession via .lookup, then
# compare taxids.  mmseqs stores the taxid verbatim -- merged.dmp is applied when the
# tree is queried, not when _mapping is written -- so any difference here is a bug.
# Superseded and deleted ids are counted separately, as information.
LC_ALL=C gawk -F'\t' -v merged="$TAXDUMP/merged.dmp" -v delnodes="$TAXDUMP/delnodes.dmp" '
    BEGIN {
        while ((getline line < merged) > 0) {
            split(line, f, /\t\|\t?/)
            gsub(/[^0-9]/, "", f[1]); gsub(/[^0-9]/, "", f[2])
            if (f[1] != "" && f[2] != "") remap[f[1]] = f[2]
        }
        while ((getline line < delnodes) > 0) {
            gsub(/[^0-9]/, "", line)
            if (line != "") dead[line] = 1
        }
    }
    FILENAME == ARGV[1] { srctax[$1] = $2; next }
    FILENAME == ARGV[2] { acc[$1] = $2; next }
    {
        want = srctax[acc[$1]]
        if ($2 != want) { bad++; if (bad <= 5) printf("  mismatch key=%s acc=%s mapping=%s source=%s\n", $1, acc[$1], $2, want) }
        else ok++
        if ($2 in remap) superseded++
        else if ($2 in dead) deleted++
    }
    END {
        printf("  mapping matches source for %d entries, %d mismatched\n", ok, bad)
        printf("  (%d carry a taxid merged.dmp supersedes -- resolved via _taxonomy at query time)\n", superseded+0)
        printf("  (%d carry a taxid NCBI deleted outright)\n", deleted+0)
        if (bad) exit 1
    }
' "$MAP" "$DB.lookup" "${DB}_mapping"
echo "OK"
