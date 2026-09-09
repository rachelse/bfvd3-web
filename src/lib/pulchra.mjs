// This bundler doesn't resolve pulchra-wasm's own bare `.wasm` import as a
// URL, so we reimplement its tiny wrapper here using Vite's explicit `?url`
// suffix, which reliably works for any asset type.
import createPulchra from 'pulchra-wasm/pulchra-wasm.js';
import pulchraWasmUrl from 'pulchra-wasm/pulchra-wasm.wasm?url';

export function pulchra(pdb) {
    return new Promise((resolve) => {
        createPulchra({ locateFile: () => pulchraWasmUrl }).then((instance) => {
            const ptr = instance.ccall('pulchra', 'number', ['string'], [pdb]);
            const res = instance.UTF8ToString(ptr);
            instance.ccall('pulchra_free', 'number', ['number'], [ptr]);
            resolve(res);
        });
    });
}
