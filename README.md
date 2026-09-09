# BFVD Web (Vue 3)

Vue 3 / Vuetify 3 / Vite rewrite of the BFVD webserver frontend, with the
structure viewer rebuilt on [Mol*](https://molstar.org/) instead of NGL.

## Frontend

```sh
npm install
npm run dev      # dev server on :5173, proxies /api to :3000
npm run build    # production build to dist/
```

## Backend

The Express API server under `src/server/` is ported over from the original
app essentially unchanged (it doesn't depend on the frontend framework).

```sh
cp .env.example .env   # set DATA_PATH to your foldseek/mmseqs database directory
npm install             # also compiles the native tsvreader addon (node-gyp)
npm run server          # runs on EXPRESS_PORT (default 3000)
```

`DATA_PATH` must point at the same set of database files the original
`bfvd-web` repo uses (`afdb*`, `afdb-clusters.sqlite3`, `ava_db*`, etc.) —
this repo does not include that data.

## Status

Ported so far: search, Foldseek/taxonomy/GO result tables, cluster page,
members/similars tables, Sankey view, MSA logo plot, and the structure
viewer (Mol*-based, monomer view + TM-align superposition). Not yet
revisited: bundle size / route-level code-splitting.
