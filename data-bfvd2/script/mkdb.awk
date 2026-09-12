#!/usr/bin/env -S gawk -f
# (env needs -S here; v1's data/db.awk omits it and only runs via `gawk -f`.)
#
# TSV -> DbReader blob + index, for src/server/dbreader.mjs.
#
# Input : key <TAB> value, grouped by key; lines sharing a key are concatenated, each
#         terminated by \n. Sorted input by default; pass -v grouped=1 when the input is
#         merely grouped, and sort the .index afterwards.
# Output: <outfile> NUL-terminated records, <outfile>.index of key, offset, size.
#
# Records are written as they are read rather than accumulated: for ava_db a single
# query can carry tens of thousands of hits, and building that in a string is quadratic.
#
# Unlike v1's db.awk: `outfile` is required, and unsorted input fails loudly rather than
# producing an index dbreader.mjs cannot binary-search.
#
# Usage: mkdb.awk [-v grouped=1] -v outfile=out/afdb_desc input.tsv

BEGIN {
    FS = "\t";
    if (length(outfile) == 0) {
        print "mkdb.awk: -v outfile=... is required" > "/dev/stderr";
        exit 1;
    }
    outindex = outfile ".index";
    printf("") > outfile;
    printf("") > outindex;
    last = "";
    offset = 0;   # where the current record starts
    size = 0;     # bytes written for it so far
    have = 0;
}

# Close the current record: NUL-terminate it and emit its index line.
function flush() {
    printf "%c", 0 >> outfile;
    size += 1;
    print last "\t" offset "\t" size >> outindex;
    offset += size;
    size = 0;
}

{
    key = $1;
    $1 = "";
    val = substr($0, 2);

    if (have && key != last) {
        if (!grouped && key < last) {
            printf("mkdb.awk: input not sorted at line %d: %s after %s\n",
                   NR, key, last) > "/dev/stderr";
            exit 1;
        }
        flush();
    }

    printf "%s\n", val >> outfile;
    size += length(val) + 1;
    last = key;
    have = 1;
}

END {
    if (have) flush();
    close(outfile);
    close(outindex);
}
