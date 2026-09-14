#!/bin/bash
# Pack the released BFVD v2 structures into a single uploadable archive.
#
# Two things this gets right that a plain `tar -cf` would not:
#
#   -h / --dereference   The release lives as a symlink farm (<accession>.pdb -> the
#                        ColabFold or ProteinTTT prediction).  Without -h, tar stores the
#                        links themselves and whoever extracts the archive gets dangling
#                        symlinks instead of structures.  -h also means no dereferenced
#                        intermediate copy (~948 GB) is needed, and it keeps the builder's
#                        absolute paths (which the link targets contain) out of the archive.
#
#   --owner/--group      Otherwise every member is stamped with the building account's
#                        user and group name, which then ships to every downloader.
#                        Forced to numeric 0/0.
#
# usage: make_structure_archive.sh <symlinkFarm> <outFile> [topLevelName] [level] [threads]
#        <outFile> ending in .zst uses zstd, .gz uses gzip.
set -euo pipefail

FARM=${1:?symlink farm dir}
OUT=${2:?output archive (.tar.zst or .tar.gz)}
TOP=${3:-bfvd2_structures}
LEVEL=${4:-9}
THREADS=${5:-20}

[ -d "$FARM" ] || { echo "missing $FARM" >&2; exit 1; }
[ -e "$OUT" ]  && { echo "refusing to overwrite existing $OUT" >&2; exit 1; }

case "$OUT" in
    *.zst) command -v zstd >/dev/null || { echo "zstd not on PATH" >&2; exit 1; }
           COMPRESS=(zstd "-$LEVEL" "-T$THREADS" -q -o "$OUT" -f)
           DECOMPRESS=(zstd -dc "$OUT") ;;
    *.gz)  COMPRESS=(sh -c "gzip -$LEVEL > '$OUT'")
           DECOMPRESS=(gzip -dc "$OUT") ;;
    *)     echo "unrecognised archive suffix: $OUT" >&2; exit 1 ;;
esac

base=$(basename "$FARM")
parent=$(dirname "$FARM")

echo "[1/3] pre-flight"
n_links=$(find "$FARM" -name '*.pdb' -printf . | wc -c)
n_broken=$(find "$FARM" -name '*.pdb' -xtype l | wc -l)
echo "  $n_links entries, $n_broken broken"
[ "$n_broken" -eq 0 ] || { echo "refusing to archive a farm with broken links" >&2; exit 1; }

echo "[2/3] archiving -> $OUT"
tar -chf - -C "$parent" \
    --owner=0 --group=0 --numeric-owner --sort=name \
    --transform="s,^${base},${TOP}," \
    "$base" | "${COMPRESS[@]}"
ls -l "$OUT" | awk '{printf("  %.1f GB\n", $5/1073741824)}'

# Read the archive back.  Every member must be a regular file (a symlink slipping in
# means -h did not take effect) and no member may carry a named owner or group.
echo "[3/3] verifying archive contents"
"${DECOMPRESS[@]}" | tar -tv | gawk -v want="$n_links" '
    {
        t = substr($1, 1, 1)
        if (t == "-") files++; else if (t == "l") links++; else other++
        if ($2 != "0/0") { named++; if (named <= 3) printf("  named owner: %s %s\n", $2, $NF) > "/dev/stderr" }
    }
    END {
        printf("  regular files: %d, symlinks: %d, dirs/other: %d, named owners: %d\n",
               files, links+0, other+0, named+0)
        if (links)         { print "  FAIL: archive contains symlinks -- -h did not take effect" > "/dev/stderr"; exit 1 }
        if (named)         { print "  FAIL: archive leaks owner/group names" > "/dev/stderr"; exit 1 }
        if (files != want) { printf("  FAIL: %d files archived, expected %d\n", files, want) > "/dev/stderr"; exit 1 }
    }
'
echo "OK: $OUT"
