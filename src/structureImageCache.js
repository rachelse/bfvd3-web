// Shared cache of rendered structure thumbnails, keyed by accession.
//
// Rendering is the expensive part -- pulchra rebuilds full atoms from the Ca trace, then
// Mol* parses, builds a cartoon and rasterises, all serialised on one queue -- while
// fetching coordinates costs a millisecond. So the point is to render each accession
// once. Module scope, not component state, so panels share renders and paging back is
// free; ImageMixin kept them per-component and wiped them on every fetch.

// PNG blob URLs; a few hundred thumbnails is a handful of MB.
const MAX_ENTRIES = 300;

const cache = new Map();     // accession -> object URL; insertion order drives the LRU
const inflight = new Map();  // accession -> Promise<string>

function touch(accession, url) {
    // Re-insert so the most recent sits last.
    cache.delete(accession);
    cache.set(accession, url);
}

function evictIfNeeded() {
    while (cache.size > MAX_ENTRIES) {
        const oldest = cache.keys().next().value;
        const url = cache.get(oldest);
        cache.delete(oldest);
        URL.revokeObjectURL(url);
    }
}

/** The thumbnail for `accession` if it has already been rendered, else null. */
export function getCachedImage(accession) {
    if (!accession) {
        return null;
    }
    const url = cache.get(accession);
    if (url) {
        touch(accession, url);
        return url;
    }
    return null;
}

/**
 * Render `accession` if it is not cached already, and resolve to its thumbnail URL.
 * Concurrent callers for the same accession share one render.
 */
export function loadImage(accession, axios, molstarService) {
    if (!accession) {
        return Promise.resolve(null);
    }

    const cached = getCachedImage(accession);
    if (cached) {
        return Promise.resolve(cached);
    }

    const pending = inflight.get(accession);
    if (pending) {
        return pending;
    }

    const promise = axios.get('/structure/' + accession)
        .then((response) => molstarService.makeImage(
            response.data.seq, response.data.plddt, response.data.coordinates))
        .then((blob) => {
            const url = URL.createObjectURL(blob);
            cache.set(accession, url);
            evictIfNeeded();
            return url;
        })
        .catch((e) => {
            // A missing structure 404s; anything else is worth seeing.
            console.log(`structure thumbnail for ${accession}:`, e);
            return null;
        })
        .finally(() => {
            inflight.delete(accession);
        });

    inflight.set(accession, promise);
    return promise;
}

/** Drop every cached thumbnail. Exposed for tests and teardown. */
export function clearImageCache() {
    for (const url of cache.values()) {
        URL.revokeObjectURL(url);
    }
    cache.clear();
}

export function imageCacheSize() {
    return cache.size;
}
