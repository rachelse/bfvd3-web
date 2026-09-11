<template>
    <div ref="root" class="structure-thumb" :style="{ height: height + 'px', width: height + 'px' }">
        <img v-if="url" :src="url" :alt="accession" :style="{ height: height + 'px' }">
        <v-progress-circular v-else-if="loading" indeterminate size="20" width="2" color="primary">
        </v-progress-circular>
    </div>
</template>

<script>
import { getCachedImage, loadImage } from './structureImageCache';

export default {
    name: "StructureThumb",
    props: {
        accession: { type: String, default: null },
        height: { type: Number, default: 75 },
    },
    data() {
        return {
            url: null,
            loading: false,
        };
    },
    watch: {
        // A data table reuses row components across pages, so the same instance is handed
        // a new accession rather than being recreated. Without this the row would keep
        // showing the previous entry's structure.
        accession() {
            this.url = getCachedImage(this.accession);
            this.loading = false;
            if (!this.url) {
                this.requestIfVisible();
            }
        },
    },
    mounted() {
        // Already rendered: show it without waiting to be scrolled into view.
        this.url = getCachedImage(this.accession);
        if (this.url) {
            return;
        }

        // Rendering is serialised and expensive, so only pay for rows the user can
        // actually see -- a 100-row page used to render 100 thumbnails regardless.
        if (typeof IntersectionObserver === 'undefined') {
            this.request();
            return;
        }
        this.observer = new IntersectionObserver((entries) => {
            if (entries.some((e) => e.isIntersecting)) {
                this.request();
            }
        }, { rootMargin: '200px' });   // start slightly before the row scrolls in
        this.observer.observe(this.$refs.root);
    },
    beforeUnmount() {
        this.disconnect();
    },
    methods: {
        disconnect() {
            if (this.observer) {
                this.observer.disconnect();
                this.observer = null;
            }
        },
        requestIfVisible() {
            if (!this.observer && this.$refs.root) {
                this.request();
            }
        },
        request() {
            this.disconnect();
            if (this.url || this.loading || !this.accession) {
                return;
            }
            this.loading = true;
            const requested = this.accession;
            loadImage(requested, this.$axios, this.$molstarService)
                .then((url) => {
                    // The row may have been recycled onto another accession while we
                    // waited; dropping the result avoids showing the wrong structure.
                    if (requested === this.accession) {
                        this.url = url;
                    }
                })
                .finally(() => {
                    if (requested === this.accession) {
                        this.loading = false;
                    }
                });
        },
    },
};
</script>

<style scoped>
.structure-thumb {
    display: inline-flex;
    align-items: center;
    justify-content: center;
}
</style>
