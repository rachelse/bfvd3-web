// Shared cache of rendered structure thumbnails, keyed by accession.
//
// Rendering one thumbnail is expensive -- pulchra reconstructs full-atom coordinates
// from the Ca trace, then Mol* parses, builds a cartoon representation and rasterises it
// -- and MolstarService serialises every render onto one promise queue. Fetching the
// coordinates, by contrast, costs a millisecond or two.
//
// So the thing worth avoiding is re-rendering. This cache lives at module scope rather
// than on a component, which means:
//   - paging back to a page you have already seen costs nothing
//   - the members and similars panels share renders of the same accession
//   - concurrent requests for one accession render once, not twice
//
// It replaces ImageMixin, which kept its images on the component, wiped them on every
// fetch, and so re-rendered everything from scratch on any page or filter change.

// Each entry is a PNG blob URL; a few hundred thumbnails is a handful of MB.
const MAX_ENTRIES = 300;

const cache = new Map();     // accession -> object URL. Map iterates in insertion order,
                             // which is what makes the LRU eviction below cheap.
const inflight = new Map();  // accession -> Promise<string>

function touch(accession, url) {
    // Re-insert so the most recently used entry sits at the end.
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
            // A missing structure is a 404 from the API; anything else is worth seeing.
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
