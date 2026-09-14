#!/bin/bash
# Build bfvd2_taxID_rank_scientificname_lineage.tsv -- the v2 counterpart of v1's
# bfvd_taxID_rank_scientificname_lineage.tsv.
#
#   1 model            released structure file name (<accession>.pdb)
#   2 taxId            NCBI taxonomy identifier
#   3 rank             rank of that taxon
#   4 scientific name  name of that taxon
#   5 lineage          ';'-joined, rank-prefixed, root -> taxon
#
# Ranks, names and lineages come from the release's own <db>_taxonomy via
# `mmseqs addtaxonomy`, so they are consistent with the shipped taxonomy DB (merged
# taxids resolve the same way).  No header row, matching v1.
#
# usage: make_taxonomy_tsv.sh <foldseekDB> <outDir> <tmpDir> [taxdumpDir]
set -euo pipefail

DB=${1:?foldseek db prefix}
OUT=${2:?output dir}
TMP=${3:?tmp dir}
TAXDUMP=${4:-/home/user2/bfvd-web/data-bfvd2/taxdump}

command -v mmseqs >/dev/null || { echo "mmseqs not on PATH" >&2; exit 1; }
for f in "$DB.lookup" "$DB.index" "${DB}_mapping" "${DB}_taxonomy"; do
    [ -s "$f" ] || { echo "missing $f -- run make_taxdb.sh first" >&2; exit 1; }
done
mkdir -p "$OUT" "$TMP"

W="$TMP/taxlineage"; rm -rf "$W"; mkdir -p "$W"
DEST="$OUT/bfvd2_taxID_rank_scientificname_lineage.tsv"

# addtaxonomy reads the taxid of each result's *target*, so give every entry a single
# self-hit.  That turns "annotate a search result" into "annotate every DB entry".
echo "[1/4] building the self-referential result DB"
cut -f1 "$DB.index" | gawk '{print $1 "\t" $1}' > "$W/res.tsv"
mmseqs tsv2db "$W/res.tsv" "$W/res" --output-dbtype 5 -v 1

echo "[2/4] mmseqs addtaxonomy --tax-lineage 1"
mmseqs addtaxonomy "$DB" "$W/res" "$W/restax" --tax-lineage 1

echo "[3/4] mmseqs createtsv"
mmseqs createtsv "$DB" "$DB" "$W/restax" "$W/restax.tsv" -v 1

# createtsv gives: queryAcc, targetAcc, taxId, rank, name, lineage.  Drive the output
# from .lookup so an entry addtaxonomy could not resolve still gets a row.
echo "[4/4] writing $DEST"
LC_ALL=C gawk -F'\t' -v OFS='\t' '
    NR == FNR {
        tax[$1] = $3; rank[$1] = $4; name[$1] = $5; lin[$1] = $6
        next
    }
    {
        acc = $2
        if (acc in tax) { print acc ".pdb", tax[acc], rank[acc], name[acc], lin[acc] }
        else            { print acc ".pdb", "NA", "NA", "NA", "NA"; miss++ }
        n++
    }
    END {
        printf("  %d rows", n) > "/dev/stderr"
        if (miss) printf(", %d without taxonomy", miss) > "/dev/stderr"
        printf("\n") > "/dev/stderr"
    }
' "$W/restax.tsv" "$DB.lookup" > "$DEST"

entries=$(wc -l < "$DB.lookup")
rows=$(wc -l < "$DEST")
[ "$rows" -eq "$entries" ] || { echo "row count mismatch: $rows vs $entries" >&2; exit 1; }
bad=$(gawk -F'\t' 'NF!=5{n++}END{print n+0}' "$DEST")
[ "$bad" -eq 0 ] || { echo "$bad rows do not have 5 fields" >&2; exit 1; }
# Column 2 must agree with the shipped _mapping, except where merged.dmp supersedes the
# id: addtaxonomy resolves merges (so the rank/name/lineage describe the current node)
# while _mapping stores the taxid verbatim.  Anything else is a bug.
LC_ALL=C gawk -F'\t' -v merged="$TAXDUMP/merged.dmp" '
    BEGIN {
        while ((getline l < merged) > 0) {
            split(l, g, /\t\|\t?/); gsub(/[^0-9]/, "", g[1]); gsub(/[^0-9]/, "", g[2])
            if (g[1] != "") remap[g[1]] = g[2]
        }
    }
    FNR == NR            { acc[$1] = $2; next }          # .lookup : key -> accession
    FILENAME == ARGV[2]  { want[acc[$1]] = $2; next }    # _mapping: key -> taxid
    {
        a = $1; sub(/\.pdb$/, "", a)
        if ($2 == "NA")                                 { na++; next }
        w = want[a]
        if ($2 == w)                                      same++
        else if ((w in remap) && $2 == remap[w])          remapped++
        else { other++; if (other <= 3) printf("  UNEXPECTED %s file=%s mapping=%s\n", a, $2, w) > "/dev/stderr" }
    }
    END {
        printf("  taxid identical to _mapping: %d\n  resolved via merged.dmp: %d\n  NA (taxid deleted by NCBI): %d\n", same, remapped+0, na+0)
        if (other) { printf("  UNEXPLAINED: %d\n", other) > "/dev/stderr"; exit 1 }
    }
' "$DB.lookup" "${DB}_mapping" "$DEST"
echo "OK: $DEST ($rows rows)"
