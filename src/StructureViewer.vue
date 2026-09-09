<template>
    <div class="structure-panel">
        <div
            class="structure-wrapper"
            ref="structurepanel"
            :class="{ hovered: hovered || isFullscreen }"
            @mouseover="hovered = true" @mouseleave="hovered = false"
            >
            <v-tooltip open-delay="300" location="bottom" attach=".structure-wrapper" background-color="transparent">
                <template v-slot:activator="{ props }">
                    <v-icon v-if="toolbar" :theme="isFullscreen ? 'light' : undefined" v-bind="props" class="help">{{ $MDI.HelpCircleOutline }}</v-icon>
                </template>
                <span>
                    <dl style="text-align: center;">
                        <dt>
<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2" viewBox="0 0 32 32">
<title>Left click</title>
<path d="M25.6 5.8a5 5 0 0 0-5-4.8h-9.1a5 5 0 0 0-5.1 4.8v20.4a5 5 0 0 0 5 4.8h9.1a5 5 0 0 0 5.1-4.8V5.8Zm-1 9.5v10.9a4 4 0 0 1-4 3.8h-9.1a4 4 0 0 1-4-3.8V15.3h17ZM15.5 2v12.3h-8V5.8a4 4 0 0 1 4-3.8h4Zm1 0h4a4 4 0 0 1 4 3.8v8.5h-8V2Z"/>
<path id="left" d="M15.5 2v12.3h-8V5.8a4 4 0 0 1 4-3.8h4Z" style="fill:red"/>
<path id="middle-inactive" d="M14.6 4h2.8v8h-2.8z"/>
</svg>
                        </dt>
                        <dd>
                            Rotate
                        </dd>
                        <dt>
<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2" viewBox="0 0 32 32">
<title>Right click</title>
<path d="M25.6 5.8a5 5 0 0 0-5-4.8h-9.1a5 5 0 0 0-5.1 4.8v20.4a5 5 0 0 0 5 4.8h9.1a5 5 0 0 0 5.1-4.8V5.8Zm-1 9.5v10.9a4 4 0 0 1-4 3.8h-9.1a4 4 0 0 1-4-3.8V15.3h17ZM15.5 2v12.3h-8V5.8a4 4 0 0 1 4-3.8h4Zm1 0h4a4 4 0 0 1 4 3.8v8.5h-8V2Z"/>
<path id="right" d="M16.5 2h4a4 4 0 0 1 4 3.8v8.5h-8V2Z" style="fill:red"/>
<path id="middle-inactive" d="M14.6 4h2.8v8h-2.8z"/>
</svg>
                        </dt>
                        <dd>
                            Pan
                        </dd>
                        <dt>
<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2" viewBox="0 0 32 32">
<title>Scroll wheel</title>
<path d="M25.6 5.8a5 5 0 0 0-5-4.8h-9.1a5 5 0 0 0-5.1 4.8v20.4a5 5 0 0 0 5 4.8h9.1a5 5 0 0 0 5.1-4.8V5.8Zm-1 9.5v10.9a4 4 0 0 1-4 3.8h-9.1a4 4 0 0 1-4-3.8V15.3h17ZM15.5 2v12.3h-8V5.8a4 4 0 0 1 4-3.8h4Zm1 0h4a4 4 0 0 1 4 3.8v8.5h-8V2Z"/>
<path id="middle-active" d="M14.6 4h2.8v8h-2.8z" style="fill:red"/>
</svg>
                        </dt>
                        <dd>
                            Zoom
                        </dd>
                    </dl>
                </span>
            </v-tooltip>
            <div class="toolbar-panel" v-if="toolbar">
                <v-item-group class="v-btn-toggle" :theme="isFullscreen ? 'light' : undefined">
                <v-btn
                    v-if="hasSecondStructure"
                    v-bind="tbButtonBindings"
                    v-on:click="makePdb()"
                    title="Save PDB"
                >
                    <v-icon v-bind="tbIconBindings">M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5c0-1.1.9-2 2-2h14Zm0 8v-.8c0-.7-.6-1.2-1.3-1.2h-2.4v6h2.4c.7 0 1.2-.5 1.2-1.2v-1c0-.4-.4-.8-.9-.8.5 0 1-.4 1-1Zm-9.7.5v-1c0-.8-.7-1.5-1.5-1.5H5.3v6h1.5v-2h1c.8 0 1.5-.7 1.5-1.5Zm5 2v-3c0-.8-.7-1.5-1.5-1.5h-2.5v6h2.5c.8 0 1.5-.7 1.5-1.5Zm3.4.3h-1.2v-1.2h1.2v1.2Zm-5.9-3.3v3h1v-3h-1Zm-5 0v1h1v-1h-1Zm11 .9h-1.3v-1.2h1.2v1.2Z</v-icon>
                    <span v-if="isFullscreen">&nbsp;Save PDB</span>
                </v-btn>
                <v-btn
                    v-bind="tbButtonBindings"
                    v-on:click="makeImage()"
                    title="Save image"
                >
                    <v-icon v-bind="tbIconBindings">M19 3H5C3.9 3 3 3.9 3 5V19C3 20.1 3.9 21 5 21H19C20.1 21 21 20.1 21 19V5C21 3.9 20.1 3 19 3M9 11.5C9 12.3 8.3 13 7.5 13H6.5V15H5V9H7.5C8.3 9 9 9.7 9 10.5V11.5M14 15H12.5L11.5 12.5V15H10V9H11.5L12.5 11.5V9H14V15M19 10.5H16.5V13.5H17.5V12H19V13.7C19 14.4 18.5 15 17.7 15H16.4C15.6 15 15.1 14.3 15.1 13.7V10.4C15 9.7 15.5 9 16.3 9H17.6C18.4 9 18.9 9.7 18.9 10.3V10.5H19M6.5 10.5H7.5V11.5H6.5V10.5Z</v-icon>
                    <span v-if="isFullscreen">&nbsp;Save image</span>
                </v-btn>
                <v-btn
                    v-bind="tbButtonBindings"
                    v-on:click="resetView()"
                    title="Reset the view to the original position and zoom level"
                >
                    <v-icon v-bind="tbIconBindings">{{ $MDI.Restore }}</v-icon>
                    <span v-if="isFullscreen">&nbsp;Reset view</span>
                </v-btn>
                <v-btn v-bind="tbButtonBindings"
                    v-on:click="toggleFullscreen()"
                    title="Enter fullscreen mode - press ESC to exit"
                >
                    <v-icon v-bind="tbIconBindings">{{ $MDI.Fullscreen }}</v-icon>
                    <span v-if="isFullscreen">&nbsp;Fullscreen</span>
                </v-btn>
                </v-item-group>
            </div>
            <div class="structure-viewer" ref="viewport"></div>
        </div>
        <template v-if="second">
            <span v-if="!hasSecondStructure">Superposition loading</span>
            <template v-else>
                <span style="color:#FFC107">{{ second }}</span> superposed on representative <span style="color:#1E88E5">{{ cluster }}</span>
                <template v-if="tmOutput">
                    <br>
                    <span><strong>TM-score:</strong>&nbsp; {{ tmOutput.tmScore.toFixed(2) }}</span>&nbsp;
                    <span><strong>RMSD:</strong>&nbsp; {{ tmOutput.rmsd.toFixed(2) }}&ThinSpace;Å</span>
                </template>
            </template>
        </template>
    </div>
</template>

<script>
import { MolstarService } from './MolstarService.mjs';
import { tmalign as runTmalign, parseMatrix, parse } from './lib/tmalign.mjs';

const tmalign = function (pdb1, pdb2) {
    return runTmalign(pdb1, pdb2).then((tm) => ({
        matrix: parseMatrix(tm.matrix),
        output: parse(tm.output),
    }));
};

// Given a raw PDB text (ATOM lines only), return it unchanged - used just
// to build the query/target inputs TM-align expects.
const onlyAtomLines = (pdb) => pdb.split('\n').filter((l) => l.startsWith('ATOM')).join('\n');

export default {
    data: () => ({
        service: null,
        hasSecondStructure: false,
        primaryStructure: null,
        secondaryStructure: null,
        tmOutput: null,
        isFullscreen: false,
        hovered: false,
    }),
    props: {
        'cluster': { type: String, required: true },
        'second': { type: String, required: true },
        'toolbar': { type: Boolean, default: true },
    },
    methods: {
        handleResize() {
            if (!this.service) return;
            this.service.handleResize();
        },
        toggleFullscreen() {
            if (!this.service) return;
            this.service.toggleFullscreen(this.$refs.structurepanel);
        },
        resetView() {
            if (!this.service) return;
            if (this.hasSecondStructure) {
                this.hasSecondStructure = false;
                this.tmOutput = null;
                this.secondaryStructure = null;
                this.service.loadStructure(this.primaryStructure.coordinates, this.primaryStructure.seq, this.primaryStructure.plddt);
                this.$emit('reset', null);
                return;
            }
            this.service.resetView();
        },
        makeImage() {
            if (!this.service) return;
            this.service.makeImage().then((blob) => {
                downloadBlob(blob, this.cluster + '.png');
            });
        },
        makePdb() {
            if (!this.service || !this.hasSecondStructure) return;
            const text = this.service.makePdbText(this.cluster, this.second);
            downloadBlob(new Blob([text], { type: 'text/plain' }), this.cluster + '+' + this.second + '.pdb');
        },
        fetchStructure(accession) {
            return this.$axios.get('/structure/' + accession).then((response) => ({
                coordinates: response.data.coordinates,
                seq: response.data.seq,
                plddt: response.data.plddt,
            }));
        },
        loadPrimary() {
            if (!this.cluster) return;
            this.fetchStructure(this.cluster).then((structure) => {
                this.primaryStructure = structure;
                return this.service.loadStructure(structure.coordinates, structure.seq, structure.plddt);
            }).then(() => {
                if (this.second) this.loadSuperposition();
            });
        },
        loadSuperposition() {
            // Waits for the primary structure's fetch+reconstruction (kicked off by the
            // `cluster` watcher) so its PDB text is available for TM-align.
            if (!this.second) return;
            this.hasSecondStructure = false;
            this.tmOutput = null;
            const primary = this.primaryStructure;
            if (!primary) return;

            this.fetchStructure(this.second)
                .then((secondary) => {
                    this.secondaryStructure = secondary;
                    return Promise.all([
                        this.service.reconstructPdb(primary.coordinates, primary.seq),
                        this.service.reconstructPdb(secondary.coordinates, secondary.seq),
                    ]);
                })
                .then(([primaryPdb, secondaryPdb]) => tmalign(onlyAtomLines(secondaryPdb), onlyAtomLines(primaryPdb)))
                .then((tm) => {
                    this.tmOutput = tm.output;
                    return this.service.loadSuperposition(
                        primary.coordinates, primary.seq,
                        this.secondaryStructure.coordinates, this.secondaryStructure.seq,
                        { t: tm.matrix.t, u: tm.matrix.u }
                    );
                })
                .then(() => {
                    this.hasSecondStructure = true;
                });
        },
    },
    computed: {
        tbIconBindings() {
            return (this.isFullscreen) ? { 'end': true } : {};
        },
        tbButtonBindings() {
            return (this.isFullscreen) ? {
                'size': 'default',
                'style': 'margin-bottom: 15px;',
            } : {
                'size': 'small',
                'style': ''
            };
        },
    },
    watch: {
        'cluster': {
            handler() {
                this.$nextTick(() => this.loadPrimary());
            },
            immediate: true,
        },
        'second': {
            handler() {
                if (this.second == '') return;
                this.$nextTick(() => this.loadSuperposition());
            },
            immediate: true,
        },
    },
    mounted() {
        this.service = new MolstarService(this.$refs.viewport);
        window.addEventListener('resize', this.handleResize);
    },
    beforeUnmount() {
        window.removeEventListener('resize', this.handleResize);
        if (this.service) this.service.dispose();
    },
}

function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}
</script>

<style scoped>
.structure-wrapper {
    margin: 0 auto;
    position: relative;
    height: 300px;
    width: 100%;
}

.v-theme--dark .structure-wrapper .v-tooltip__content {
    background: rgba(97, 97, 97, 0.3);
}

.structure-viewer {
    width: 100%;
    height: 100%;
}

.structure-viewer canvas {
    border-radius: 2px;
}

.structure-panel {
    position: relative;
}

.hovered .toolbar-panel {
    display: inline-flex;
}
.toolbar-panel {
    display: none;
    flex-direction: row;
    position: absolute;
    justify-content: center;
    width: 100%;
    bottom: 0;
    z-index: 1;
    left: 0;
}
.structure-wrapper.hovered :deep(.help) {
    display: inline-flex;
}
.structure-wrapper :deep(.help) {
    display: none;
    position: absolute;
    z-index: 999;
    right:0;
}
</style>
