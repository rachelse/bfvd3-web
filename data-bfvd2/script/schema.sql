-- BFVD v2 webserver database schema.
--
-- Entry-centric: each of the 5,776,417 entries has its own structure and page.
-- `cluster` groups them (MMseqs2, 30% id / 90% cov) only to drive the members panel.
--
-- load.sh creates the indices AFTER import; building them during it is far slower.

CREATE TABLE entry (
    accession  TEXT PRIMARY KEY,  -- UniProt accession; the page subject
    len        INTEGER,           -- residues
    plddt      REAL,              -- mean pLDDT of this entry
    tax_id     INTEGER,           -- NCBI taxid of the source organism
    flag       INTEGER,           -- 1 = ColabFold-AF2, 2 = ESMFold+ProteinTTT_MSA
    cluster_id TEXT               -- -> cluster.cluster_id
);

CREATE TABLE cluster (
    cluster_id   TEXT PRIMARY KEY, -- representative entry's accession, used as the key
    n_mem        INTEGER,
    avg_len      REAL,
    avg_plddt    REAL,
    is_singleton BOOLEAN,          -- n_mem == 1
    lca_tax_id   INTEGER           -- LCA of member taxids (0 if none resolve)
);

-- Ancestor -> descendant closure of the viral subtree, for the taxonomy filter.
CREATE TABLE taxonomy_lineage (
    parent TEXT,
    child  TEXT
);

-- UniProt "Virus hosts": a specific host organism. Accession-keyed, not taxid-keyed --
-- 158 taxids carry more than one distinct host value, so `ictv` would lose information.
CREATE TABLE taxonomy_host (
    accession TEXT,
    tax_id    TEXT
);

-- ICTV, per NCBI taxid. Populated for every BFVD taxid; absent values are 'NA'.
--
-- No ictv_species: at species rank the NCBI name matches the ICTV species for 176,302
-- of 176,330 mapped taxids, so the entry page reads it off the NCBI tree.
--
-- ictv_host is a coarse controlled-vocabulary category ('vertebrates'), NOT a species.
-- It is kept separate from taxonomy_host, which holds specific host organisms; the
-- page shows UniProt hosts when present, else this category, else 'NA'.
CREATE TABLE ictv (
    tax_id         TEXT PRIMARY KEY,
    ictv_id        TEXT NOT NULL,  -- 'ICTV19911441' | 'NA'
    ictv_accession TEXT NOT NULL,  -- GenBank exemplar(s), ';'-joined | 'NA'
    ictv_host      TEXT NOT NULL,  -- host category, ';'-joined | 'NA'
    mapping_step   TEXT NOT NULL   -- how the taxid was mapped | 'NA'
);
