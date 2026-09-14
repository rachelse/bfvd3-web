<template>
<Panel style="margin-top: 0em;" collapsible>
    <template v-slot:header>
        Similar entries
    </template>

    <template v-slot:toolbar-extra>
        <v-menu offset-y>
            <template v-slot:activator="{ props }">
                <v-btn variant="plain" v-bind="props">
                    <v-icon class="mr-1">{{ $MDI.Export }}</v-icon>
                    Export
                </v-btn>
            </template>
            <v-list>
                <v-list-item :href="`${$axios.defaults.baseURL}/cluster/${$route.params.cluster}/similars?format=accessions&${requestOptions.params.toString()}`" target="_blank">
                    <v-list-item-title>Accessions</v-list-item-title>
                </v-list-item>
                <v-list-item :href="`${$axios.defaults.baseURL}/cluster/${$route.params.cluster}/similars?format=fasta&${requestOptions.params.toString()}`" target="_blank">
                    <v-list-item-title>FASTA</v-list-item-title>
                </v-list-item>
            </v-list>
        </v-menu>
    </template>

<template v-slot:content>
    <div class="table-scroll">
    <v-data-table-server
        mobile-breakpoint="sm"
        v-if="$route.params.cluster"
        :headers="headers"
        :items="entries"
        v-model:page="options.page"
        v-model:items-per-page="options.itemsPerPage"
        v-model:sort-by="options.sortBy"
        :items-length="totalEntries"
        :loading="loading"
        :items-per-page-options="[10, 20, 50, 100]"
    >
        <template v-slot:item.accession="prop">
            <router-link :to="{ name: 'cluster', params: { cluster: prop.value }}">{{ prop.value }}</router-link><br>
            <div class="description" :title="prop.item.description">{{ prop.item.description }}</div>
        </template>
        <template v-slot:item.avg_len="prop">
            {{ prop.value.toFixed(2) }}
        </template>

        <template v-slot:item.avg_plddt="prop">
            {{ prop.value.toFixed(2) }}
        </template>
        <template v-slot:item.plddt="prop">
            {{ prop.value.toFixed(2) }}
        </template>
        <template v-slot:header.structure="{ column }">
            {{ column.title }}
            <v-tooltip top>
                <template v-slot:activator="{ props }">
                    <span v-bind="props">
                        <v-icon v-bind="props">{{ $MDI.HelpCircleOutline }}</v-icon>
                    </span>
                </template>
                <span>
                   Click on a structure to superpose it on to this entry in the structure viewer
                </span>
            </v-tooltip>
        </template>
        <template v-slot:item.structure="prop">
            <div v-ripple="{ class: `primary--text` }" style="text-align: center; cursor: pointer;" @click="$emit('select', prop.item.accession)">
                <StructureThumb :accession="prop.item.accession"></StructureThumb>
            </div>
        </template>

        <template v-slot:header.lca_tax_id="{ column }">
                <!-- In the stacked card layout Vuetify reuses this slot as each card's
                     row label, where a filter widget makes no sense; show the plain
                     column title instead. -->
                <TaxonomyAutocomplete
                    v-if="!$vuetify.display.xs"
                    :cluster="cluster"
                    v-model="options.tax_id"
                    :urlFunction="(a, b) => '/cluster/' + a + '/similars/taxonomy/' + b"
                    :options="requestOptions"
                    :disabled="taxAutocompleteDisabled">
                </TaxonomyAutocomplete>
                <template v-else>{{ column.title }}</template>
        </template>

        <template v-slot:item.lca_tax_id="prop">
            <TaxSpan :taxonomy="prop.value"></TaxSpan>
        </template>

        <template v-slot:item.actions="{ item }">
            <v-chip title="Search with Foldseek" :href="'https://search.foldseek.com/search?accession=' + item.accession + '&source=BFVD_v2'" target="_blank" rel="noopener">
                <img src="./assets/marv-foldseek-small.png" style="display: inline-block; width: 16px; height: 16px;" />
            </v-chip>
        </template>
    </v-data-table-server>
    </div>
</template>
</Panel>
</template>

<script>
import StructureThumb from "./StructureThumb.vue";
import TaxSpan from "./TaxSpan.vue";
import StructureViewer from "./StructureViewer.vue";
import ExternalLinks from "./ExternalLinks.vue";
import TaxonomyAutocomplete from "./TaxonomyAutocomplete.vue";
import Sankey from "./Sankey.vue";
import Panel from "./Panel.vue";

export default {
    name: "Similars",
    components: {
        StructureThumb,
        Panel,
        TaxSpan,
        StructureViewer,
        ExternalLinks,
        TaxonomyAutocomplete,
        Sankey,
    },
    props: ["cluster"],
    data() {
        return {
            headers: [
                {
                    title: "Structure",
                    value: "structure",
                    sortable: false,
                },
                {
                    title: "Accession",
                    value: "accession",
                    sortable: true,
                },
                {
                    title: "Average length",
                    value: "avg_len",
                    sortable: true,
                },
                // {
                //     text: "Average pLDDT",
                //     value: "avg_plddt",
                // },
                {
                    title: "Number of members",
                    value: "n_mem",
                    sortable: true,
                },
                {
                    title: "Lowest common ancestor",
                    value: "lca_tax_id",
                    sortable: false,
                },
                {
                    title: "pLDDT",
                    value: "plddt",
                    sortable: true,
                },
                {
                    title: "Length",
                    value: "len",
                    sortable: true,
                },
                {
                    title: "E-value",
                    value: "evalue",
                    sortable: true,
                },
                { title: 'Actions', value: 'actions', sortable: false },
            ],
            entries: [],
            totalEntries: 0,
            loading: false,
            options: {
                page: 1,
                itemsPerPage: 10,
                sortBy: [],
                tax_id: null,
            },
            taxAutocompleteDisabled: false,
        }
    },
    watch: {
        options: {
            handler () {
                this.fetchData()
            },
            deep: true,
        },
        cluster() {
            this.fetchData();
        }
    },
    created() {
        this.fetchData();
    },
    computed: {
        requestOptions() {
            let copy = JSON.parse(JSON.stringify(this.options));
            if (copy.tax_id) {
                copy.tax_id = copy.tax_id.value;
            } else {
                delete copy.tax_id;
            }
            const sort = (copy.sortBy && copy.sortBy[0]) || null;
            copy.sortBy = sort ? sort.key : '';
            copy.sortDesc = sort && sort.order === 'desc' ? 'true' : 'false';
            const params = new URLSearchParams(copy);
            params.sort();
            return { params };
        },
    },
    methods: {
        sankeySelect(value) {
            if (value == null) {
                this.options.tax_id = null;
                this.taxAutocompleteDisabled = false;
            } else {
               this.options.tax_id = { value: value.id, text: value.name };
               this.taxAutocompleteDisabled = true;
            }
            // this.fetchData()
        },
        log(value) {
            console.log(value);
            return value;
        },
        fetchData() {
            this.loading = true;
            const cluster = this.cluster;
            if (!cluster) {
                return;
            }
            this.$axios.get("/cluster/" + cluster + "/similars", this.requestOptions)
                .then(response => {
                    // Without an ava_db the endpoint answers a bare [], which has no
                    // .similars -- default rather than blowing up in .map below.
                    this.entries = response.data.similars ?? [];
                    this.totalEntries = response.data.total ?? 0;
                })
                .catch(() => {})
                .finally(() => {
                    this.loading = false;
                });
        }
    }
}

</script>

<style scoped>
/* Descriptions run far wider than the column, so they are clipped to one line
   and shown in full on hover rather than wrapping and stretching every row. */
.description {
    max-width: 22em;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

/* A flex item will not shrink below its content unless min-width is set, so
   without this the table pushes the panel past the card and is clipped by its
   overflow-x:hidden rather than scrolling. */
.table-scroll {
    min-width: 0;
    max-width: 100%;
}

.table-scroll :deep(.v-table__wrapper) {
    overflow-x: auto;
}

/* Overlay scrollbars are invisible until scrolled, so give this one a track. */
.table-scroll :deep(.v-table__wrapper)::-webkit-scrollbar {
    height: 10px;
}

.table-scroll :deep(.v-table__wrapper)::-webkit-scrollbar-track {
    background: rgba(128, 128, 128, 0.12);
}

.table-scroll :deep(.v-table__wrapper)::-webkit-scrollbar-thumb {
    background: rgba(128, 128, 128, 0.55);
    border-radius: 5px;
}

/* Keep cells on one line so the table holds its natural width and scrolls,
   except in the stacked card layout where values need to wrap. */
.table-scroll :deep(tr:not(.v-data-table__tr--mobile)) > th,
.table-scroll :deep(tr:not(.v-data-table__tr--mobile)) > td {
    white-space: nowrap;
}
</style>
