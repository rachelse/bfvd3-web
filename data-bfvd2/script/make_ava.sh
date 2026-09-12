#!/bin/bash
# Build ava_db from the all-vs-all Foldseek results.
#
# Input is a gzipped tar of one TSV: query <TAB> target <TAB> evalue, ids carrying the
# ColabFold suffix, grouped by query. ~464 GB uncompressed, so it is streamed straight
# out of the archive -- never extracted -- and passes through exactly once.
#
# The server (index.mjs) expects one "target evalue\n" line per hit, space-separated: a
# tab inside a record splits wrongly and shows nothing. Self-hits are filtered there.
#
# The payload never needs sorting. dbreader.mjs looks up by key and reads (offset, size),
# so records may sit in any order; only the index must be sorted, and that is ~5.8M
# lines. Sorting 464 GB would need about a terabyte of scratch for no benefit.
#
# Usage: make_ava.sh <ava.tsv.tar.gz> <tmp-dir> <out-prefix>
set -euo pipefail

SRC="${1:?all-vs-all tar.gz}"
TMP="${2:?tmp dir}"
OUT="${3:?out prefix, e.g. .../ava_db}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUFFIX='_unrelaxed_rank_001_alphafold2_ptm_model_4_seed_000'

[ -f "$SRC" ] || { echo "missing input: $SRC" >&2; exit 1; }
mkdir -p "$TMP"

echo "streaming $(du -h "$SRC" | cut -f1) through mkdb.awk ..."
tar xzOf "$SRC" \
  | gawk -F'\t' -v sfx="$SUFFIX" '
        BEGIN { OFS = "\t"; n = 0; bad = 0 }
        {
            # Strip the suffix from both ids; the server keys on bare accessions.
            q = $1; sub(sfx "$", "", q)
            t = $2; sub(sfx "$", "", t)
            if (q == "" || t == "" || $3 == "") { bad++; next }
            print q, t " " $3
            if (++n % 200000000 == 0)
                printf("  %d rows\n", n) > "/dev/stderr"
        }
        END {
            printf("  rows %d, skipped %d\n", n, bad) > "/dev/stderr"
        }' \
  | "$HERE/mkdb.awk" -v grouped=1 -v outfile="$OUT"

# Grouped, not sorted: dbreader.mjs binary-searches the index, so it must be ordered.
echo "sorting the index ..."
LC_ALL=C sort -k1,1 -o "$OUT.index" "$OUT.index"

echo "blob    $(du -h "$OUT" | cut -f1)"
echo "index   $(wc -l < "$OUT.index") keys"
