import { PluginContext } from 'molstar/lib/mol-plugin/context.js';
import { DefaultPluginSpec } from 'molstar/lib/mol-plugin/spec.js';
import { RawData } from 'molstar/lib/mol-plugin-state/transforms/data.js';
import { ModelFromTrajectory, StructureFromModel, TrajectoryFromPDB, StructureSelectionFromExpression } from 'molstar/lib/mol-plugin-state/transforms/model.js';
import { StructureRepresentation3D } from 'molstar/lib/mol-plugin-state/transforms/representation.js';
import { MolScriptBuilder as MS } from 'molstar/lib/mol-script/language/builder.js';
import { canvasToBlob } from 'molstar/lib/mol-canvas3d/util.js';
import { pulchra } from './lib/pulchra.mjs';

const oneToThree = {
    "A": "ALA", "R": "ARG", "N": "ASN", "D": "ASP",
    "C": "CYS", "E": "GLU", "Q": "GLN", "G": "GLY",
    "H": "HIS", "I": "ILE", "L": "LEU", "K": "LYS",
    "M": "MET", "F": "PHE", "P": "PRO", "S": "SER",
    "T": "THR", "W": "TRP", "Y": "TYR", "V": "VAL",
    "U": "SEC", "O": "PHL", "X": "XAA"
};

// AlphaFold-style discrete pLDDT confidence bands, matching the bfactor
// thresholds the old NGL viewer used (bins are 0-9 as stored in the DB,
// scaled back to an approximate 0-100 pLDDT percentage: bin*10 + 5).
export const CONFIDENCE_BANDS = [
    { label: 'Very high (pLDDT > 90)', min: 90, color: 0x0000F5 },
    { label: 'Confident (70 < pLDDT <= 90)', min: 70, color: 0x00FFFF },
    { label: 'Low (50 < pLDDT <= 70)', min: 50, color: 0xFFFF00 },
    { label: 'Very low (pLDDT <= 50)', min: 0, color: 0xFFA500 },
];

const SUPERPOSITION_COLORS = {
    primary: 0x1E88E5,
    secondary: 0xFFC107,
};

/**
 * Create a mock PDB from Ca data.
 * Follows the spacing spec from https://www.wwpdb.org/documentation/file-format-content/format33/sect9.html#ATOM
 */
function mockPDB(ca, seq) {
    const chainLength = ca.length / 3;
    const pdb = [];
    let j = 0;
    for (let i = 0; i < ca.length; i += 3, j++) {
        const line = 'ATOM  '
            + j.toString().padStart(5)
            + '  CA  ' + oneToThree[seq != "" && (ca.length / 3) == (seq.length - 1) ? seq[i / 3] : 'A'] + ' A'
            + j.toString().padStart(4)
            + '    '
            + ca[0 * chainLength + j].toString().padStart(8)
            + ca[1 * chainLength + j].toString().padStart(8)
            + ca[2 * chainLength + j].toString().padStart(8)
            + '  1.00  0.00           C  ';
        pdb.push(line);
    }
    return pdb.join('\n');
}

// The pLDDT DB stores discretized 0-9 bins per residue. Patch the b-factor
// (temperature factor, PDB columns 61-66) of every ATOM line with an
// approximate 0-100 pLDDT percentage so we can bucket by confidence band.
function patchBfactorFromPlddtBins(pdbText, plddtBins) {
    return pdbText.split('\n').map((line) => {
        if (!line.startsWith('ATOM')) return line;
        const resSeq = parseInt(line.substring(22, 26), 10);
        const bin = plddtBins ? +plddtBins[resSeq] : NaN;
        const pct = Number.isFinite(bin) ? bin * 10 + 5 : 50;
        const bfactorField = pct.toFixed(2).padStart(6);
        return line.substring(0, 60) + bfactorField + line.substring(66);
    }).join('\n');
}

// Rotate+translate a flat [x0..xn, y0..yn, z0..zn] CA coordinate array by
// the TM-align rotation matrix, mirroring the transform TM-align reports.
function transformCoordinates(ca, t, u) {
    const n = ca.length / 3;
    const out = new Array(ca.length);
    for (let i = 0; i < n; i++) {
        const x = ca[i], y = ca[n + i], z = ca[2 * n + i];
        out[i] = t[0] + u[0][0] * x + u[0][1] * y + u[0][2] * z;
        out[n + i] = t[1] + u[1][0] * x + u[1][1] * y + u[1][2] * z;
        out[2 * n + i] = t[2] + u[2][0] * x + u[2][1] * y + u[2][2] * z;
    }
    return out;
}

function bandExpression(min, max) {
    const bfactor = MS.struct.atomProperty.macromolecular.B_iso_or_equiv();
    const gt = MS.core.rel.gr([bfactor, min]);
    if (max == null) {
        return MS.struct.generator.atomGroups({ 'atom-test': gt });
    }
    const lte = MS.core.rel.lte([bfactor, max]);
    return MS.struct.generator.atomGroups({ 'atom-test': MS.core.logic.and([gt, lte]) });
}

export class MolstarService {
    constructor(container) {
        this.container = container;
        this.plugin = new PluginContext(DefaultPluginSpec());
        this.ready = this._init();
        this.lastPdb = null;
        this.lastSecondPdb = null;
    }

    async _init() {
        await this.plugin.init();
        await this.plugin.mountAsync(this.container);
        await this.plugin.canvas3dInitialized;
        const renderer = this.plugin.canvas3d?.props?.renderer;
        if (renderer) {
            this.plugin.canvas3d.setProps({
                cameraResetDurationMs: 0,
                renderer: { ...renderer, ambientIntensity: 0.2 },
            });
        }
    }

    async _loadPdbWithBands(pdbText, apply) {
        this.plugin.clear();
        const update = this.plugin.build();
        const root = update.toRoot()
            .apply(RawData, { data: pdbText })
            .apply(TrajectoryFromPDB)
            .apply(ModelFromTrajectory)
            .apply(StructureFromModel);
        apply(root);
        await update.commit();
    }

    // Reconstruct full-atom PDB text from CA coordinates only, without rendering it.
    // Used to build TM-align inputs before deciding on a final superposed layout.
    async reconstructPdb(coordinates, seq) {
        return pulchra(mockPDB(coordinates, seq));
    }

    // Load a single structure, colored by discretized pLDDT confidence band.
    async loadStructure(coordinates, seq, plddtBins) {
        await this.ready;
        const pdb = await pulchra(mockPDB(coordinates, seq));
        const patched = patchBfactorFromPlddtBins(pdb, plddtBins);
        this.lastPdb = patched;
        this.lastSecondPdb = null;

        await this._loadPdbWithBands(patched, (root) => {
            for (let i = 0; i < CONFIDENCE_BANDS.length; i++) {
                const { min, color } = CONFIDENCE_BANDS[i];
                const max = i === 0 ? null : CONFIDENCE_BANDS[i - 1].min;
                root
                    .apply(StructureSelectionFromExpression, { expression: bandExpression(min, max) })
                    .apply(StructureRepresentation3D, {
                        type: { name: 'cartoon', params: {} },
                        colorTheme: { name: 'uniform', params: { value: color } },
                    });
            }
        });
        this.resetView();
        return patched;
    }

    // Load two structures superposed via a TM-align rotation/translation,
    // each shown as a solid color instead of confidence bands.
    async loadSuperposition(primaryCoordinates, primarySeq, secondaryCoordinates, secondarySeq, transform) {
        await this.ready;
        const primaryPdb = await pulchra(mockPDB(primaryCoordinates, primarySeq));
        let secondaryPdb = await pulchra(mockPDB(secondaryCoordinates, secondarySeq));

        if (transform) {
            const transformedCa = transformCoordinates(secondaryCoordinates, transform.t, transform.u);
            secondaryPdb = await pulchra(mockPDB(transformedCa, secondarySeq));
        }

        this.lastPdb = primaryPdb;
        this.lastSecondPdb = secondaryPdb;

        this.plugin.clear();
        const update = this.plugin.build();
        update.toRoot()
            .apply(RawData, { data: primaryPdb })
            .apply(TrajectoryFromPDB)
            .apply(ModelFromTrajectory)
            .apply(StructureFromModel)
            .apply(StructureRepresentation3D, {
                type: { name: 'cartoon', params: {} },
                colorTheme: { name: 'uniform', params: { value: SUPERPOSITION_COLORS.primary } },
            });
        update.toRoot()
            .apply(RawData, { data: secondaryPdb })
            .apply(TrajectoryFromPDB)
            .apply(ModelFromTrajectory)
            .apply(StructureFromModel)
            .apply(StructureRepresentation3D, {
                type: { name: 'cartoon', params: {} },
                colorTheme: { name: 'uniform', params: { value: SUPERPOSITION_COLORS.secondary } },
            });
        await update.commit();
        this.resetView();
    }

    resetView() {
        this.plugin.managers.camera.reset(undefined, 0);
        this.plugin.canvas3d?.commit(true);
    }

    handleResize() {
        this.plugin.canvas3d?.handleResize();
    }

    async toggleFullscreen(el) {
        if (!document.fullscreenElement) {
            await (el || this.container).requestFullscreen();
        } else {
            await document.exitFullscreen();
        }
    }

    async makeImage() {
        await this.ready;
        this.plugin.canvas3d?.commit(true);
        const ss = this.plugin.helpers.viewportScreenshot;
        ss.behaviors.values.next({ ...ss.values, transparent: true });
        const preview = await ss.getPreview(undefined, 2048);
        return canvasToBlob(preview.canvas, 'png');
    }

    // Combined PDB of whatever is currently loaded, for download.
    makePdbText(primaryLabel, secondaryLabel) {
        const header =
`REMARK     This file was generated by the BFVD webserver
REMARK     Warning: Please refer to the original AFDB PDB files.
REMARK       This file was auto-generated from compressed information:
REMARK         * Non C-alpha atoms were re-generated by PULCHRA.
REMARK         * pLDDTs were discretized into 0 to 9 bins.
REMARK         * Residue/atom indices were sequentially renumbered`;

        const onlyAtoms = (pdb) => pdb.split('\n').filter((l) => l.startsWith('ATOM')).join('\n');

        if (!this.lastSecondPdb) {
            return `TITLE     ${primaryLabel}\n${header}\n${onlyAtoms(this.lastPdb)}\nEND\n`;
        }
        return `TITLE     ${primaryLabel}+${secondaryLabel}\n${header}\nMODEL        1\n${onlyAtoms(this.lastPdb)}\nENDMDL\nMODEL        2\n${onlyAtoms(this.lastSecondPdb)}\nENDMDL\nEND\n`;
    }

    dispose() {
        if (this.plugin) this.plugin.dispose();
    }
}
