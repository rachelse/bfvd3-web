#!/bin/bash
# Build the BFVD v2 release metadata table: one fully-denormalised row per entry.
#
# Two variants are written, differing only in the proteome_id column:
#   bfvd2_metadata.tsv               the default: every proteome the entry belongs to,
#                                    ';'-joined
#   bfvd2_metadata_ref-proteome.tsv  the variant: one proteome, preferring a UniProt
#                                    reference proteome
#
# Absent values are the literal string NA, never empty (PLAN 4.2).
#
# usage: make_metadata_tsv.sh <foldseekDB> <bfvd2Root> <outDir>
set -euo pipefail

DB=${1:?foldseek db prefix}
ROOT=${2:?bfvd2 root}
OUT=${3:?output dir}

DESC="$ROOT/data/uniprot_2025_03_virus_bfvd2.tsv"
INTEG="$ROOT/proteinttt/bfvd2_final_release/bfvd2_proteinttt_integrated.tsv"
MSA="$ROOT/data/bfvd2_scores_msa.tsv"
HOST="$ROOT/analyses/07_host_coverage/results/bfvd_host_augmented.tsv"
ICTVMAP="$ROOT/analyses/09_ictv_taxonomy_mapping/results/bfvd_taxid_ictv_mapping.tsv"
REFPROT="$ROOT/uniprot_proteome/proteomes_proteome_type_REFERENCE_AND_s_2026_09_01.tsv"

for f in "$DB.lookup" "$DB.index" "$DESC" "$INTEG" "$MSA" "$HOST" "$ICTVMAP" "$REFPROT"; do
    [ -s "$f" ] || { echo "missing input: $f" >&2; exit 1; }
done
mkdir -p "$OUT"

ALL="$OUT/bfvd2_metadata.tsv"
REF="$OUT/bfvd2_metadata_ref-proteome.tsv"

echo "building $ALL and $REF"
LC_ALL=C gawk -F'\t' -v OFS='\t' \
    -v desc="$DESC" -v integ="$INTEG" -v msa="$MSA" -v host="$HOST" \
    -v ictvmap="$ICTVMAP" -v refprot="$REFPROT" \
    -v outall="$ALL" -v outref="$REF" '
function na(v) { return (v == "" || v == "N/A" || v == "NA") ? "NA" : v }

BEGIN {
    # --- taxid -> ictv_id ---
    while ((getline < ictvmap) > 0) {
        nf = split($0, f, "\t")
        if (f[1] == "taxid") continue
        ictv[f[1]] = na(f[3])
    }
    close(ictvmap)

    # --- the set of UniProt reference proteomes ---
    while ((getline < refprot) > 0) {
        nf = split($0, f, "\t")
        if (f[1] == "Proteome Id") continue
        if (f[1] != "") isref[f[1]] = 1
    }
    close(refprot)

    # --- protein name + proteome membership ---
    while ((getline < desc) > 0) {
        nf = split($0, f, "\t")
        if (f[1] == "Entry") continue
        pname[f[1]] = na(f[3])
        if (f[6] == "") { pall[f[1]] = "NA"; pref[f[1]] = "NA"; continue }
        # "UP000127881: Genome; UP000159146: Segment" -> ids only
        m = split(f[6], ps, /; */)
        joined = ""; chosen = ""
        for (i = 1; i <= m; i++) {
            id = ps[i]; sub(/:.*$/, "", id); gsub(/^ +| +$/, "", id)
            if (id == "") continue
            joined = (joined == "") ? id : joined ";" id
            if (chosen == "") chosen = id            # fall back to the first listed
            if (id in isref && !(chosen in isref)) chosen = id
        }
        pall[f[1]] = (joined == "") ? "NA" : joined
        pref[f[1]] = (chosen == "") ? "NA" : chosen
    }
    close(desc)

    # --- pLDDT / pTM / prediction provenance ---
    while ((getline < integ) > 0) {
        nf = split($0, f, "\t")
        if (f[1] == "id") continue
        model = (f[5] == "ColabFold") ? "ColabFold-AF2" : f[5]
        # pTM was never recomputed for ProteinTTT entries: integrateProteinTTT.sh
        # overwrites only the pLDDT field, so the stored pTM still describes the
        # ColabFold model that ProteinTTT replaced.  Publish NA rather than a pTM for a
        # structure this release does not ship.
        ptm = (f[5] == "ProteinTTT") ? "NA" : na(f[4])
        conf[f[1]] = sprintf("%.2f", f[3]) SUBSEP ptm SUBSEP na(model)
    }
    close(integ)

    # --- MSA depth ---
    while ((getline < msa) > 0) {
        nf = split($0, f, "\t")
        if (f[1] == "id") continue
        depth[f[1]] = na(f[5]) SUBSEP na(f[6])
    }
    close(msa)

    # --- taxid / taxname / both host columns (verified identical to the taxid source) ---
    while ((getline < host) > 0) {
        nf = split($0, f, "\t")
        if (f[1] == "id") continue
        hs[f[1]] = na(f[2]) SUBSEP na(f[3]) SUBSEP na(f[4]) SUBSEP na(f[5])
    }
    close(host)

    hdr = "accession" OFS "protein_name" OFS "length" OFS "plddt" OFS "ptm" OFS "model" \
          OFS "basemsa" OFS "loganmsa" OFS "taxid" OFS "taxname" OFS "ictv_id" \
          OFS "uniprot_host" OFS "ictv_host_category" \
          OFS "proteome_id"
    print hdr > outall
    print hdr > outref
}

# pass 1: the DB index gives the modelled length per key
FILENAME == ARGV[1] { dlen[$1] = $3 - 2; next }

# pass 2: .lookup drives the output, so the row set is exactly the DB contents
{
    key = $1; acc = $2
    if (!(key in dlen)) { printf("key %s missing from index\n", key) > "/dev/stderr"; exit 1 }

    split(conf[acc],  c, SUBSEP)
    split(depth[acc], d, SUBSEP)
    split(hs[acc],    h, SUBSEP)
    tid = (acc in hs) ? h[1] : "NA"
    iid = (tid in ictv) ? ictv[tid] : "NA"

    common = acc OFS ((acc in pname) ? pname[acc] : "NA") OFS dlen[key] \
        OFS ((acc in conf)  ? c[1] : "NA") OFS ((acc in conf)  ? c[2] : "NA") \
        OFS ((acc in conf)  ? c[3] : "NA") \
        OFS ((acc in depth) ? d[1] : "NA") OFS ((acc in depth) ? d[2] : "NA") \
        OFS tid OFS ((acc in hs) ? h[2] : "NA") \
        OFS iid \
        OFS ((acc in hs) ? h[3] : "NA") OFS ((acc in hs) ? h[4] : "NA")

    print common OFS ((acc in pall) ? pall[acc] : "NA") > outall
    print common OFS ((acc in pref) ? pref[acc] : "NA") > outref
    n++
}
END { printf("wrote %d rows\n", n) }
' "$DB.index" "$DB.lookup"

echo "verifying"
entries=$(wc -l < "$DB.lookup")
for f in "$ALL" "$REF"; do
    rows=$(( $(wc -l < "$f") - 1 ))
    [ "$rows" -eq "$entries" ] || { echo "$f: $rows rows, expected $entries" >&2; exit 1; }
    cols=$(head -1 "$f" | awk -F'\t' '{print NF}')
    bad=$(gawk -F'\t' -v c="$cols" 'NF!=c{n++}END{print n+0}' "$f")
    [ "$bad" -eq 0 ] || { echo "$f: $bad rows with wrong column count" >&2; exit 1; }
    empty=$(gawk -F'\t' '{for(i=1;i<=NF;i++) if($i==""){n++;break}}END{print n+0}' "$f")
    [ "$empty" -eq 0 ] || { echo "$f: $empty rows contain an empty field (should be NA)" >&2; exit 1; }
    echo "  $(basename "$f"): $rows rows x $cols cols, no empty fields"
done
echo OK
