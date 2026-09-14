<template>
<Panel style="margin-top: 0em;" collapsible>
    <template v-slot:header>
        <span class="d-inline-flex align-center ga-1">
            Sequence cluster members
            <v-tooltip top>
                <template v-slot:activator="{ props }">
                    <span v-bind="props" class="d-inline-flex align-center">
                        <v-icon size="small" v-bind="props">{{ $MDI.HelpCircleOutline }}</v-icon>
                    </span>
                </template>
                <span>
                    Other BFVD entries in the same sequence cluster
                    (MMseqs2, 30% identity, 90% coverage)
                </span>
            </v-tooltip>
        </span>
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
                <v-list-item :href="`${$axios.defaults.baseURL}/cluster/${$route.params.cluster}/members?format=accessions&${requestOptions.params.toString()}`" target="_blank">
                    <v-list-item-title>Accessions</v-list-item-title>
                </v-list-item>
                <!-- <v-list-item :href="`${$axios.defaults.baseURL}/cluster/${$route.params.cluster}/members?format=fasta&${requestOptions.params.toString()}`" target="_blank">
                    <v-list-item-content>
                        <v-list-item-title>FASTA</v-list-item-title>
                    </v-list-item-content>
                </v-list-item> -->
            </v-list>
        </v-menu>
    </template>
        
<template v-slot:content>
    <template v-if="$route.params.cluster">
    <Sankey :cluster="cluster" type="members" @select="sankeySelect"></Sankey>
    <div class="table-scroll">
    <v-data-table-server
        mobile-breakpoint="sm"
        :headers="headers"
        :items="members"
        v-model:page="options.page"
        v-model:items-per-page="options.itemsPerPage"
        :items-length="totalMembers"
        :loading="loading"
        :items-per-page-options="[10, 20, 50, 100]"
    >
        <template v-slot:item.accession="prop">
            <ExternalLinks :accession="prop.value"></ExternalLinks><br>
            <div class="description" :title="prop.item.description">{{ prop.item.description }}</div>
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
        <!-- <template v-slot:item.flag="prop">
            <Fragment :flag="prop.value"></Fragment>
        </template> -->
        <!-- <template v-slot:header.flag="{ column }">
            <v-menu
                :close-on-content-click="false"
                offset-y>
                <template v-slot:activator="{ on }">
                    <v-btn v-on="on" :outlined="options.flagFilter != null">
                        {{ header.text }}&nbsp;
                        <v-tooltip top>
                            <template v-slot:activator="{ on }">
                                <span v-on="on">
                                    <v-icon v-on="on">{{ $MDI.HelpCircleOutline }}</v-icon>
                                </span>
                            </template>
                            <span>
                                <img width="600" src="./assets/cluster_step.jpg"><br>
                                AFDB/Foldseek: Clustered with structural similarity<br>
                                AFDB50/Mmseqs: Clustered at sequence identity 50%<br>
                                Fragment: Removed fragments among AFDB50<br>
                                Singleton: Removed singletons after fragment removal
                            </span>
                        </v-tooltip>
                    </v-btn>
                </template>

                <v-card style="padding: 2em; width: 250px;">
                    <h3>Filter by</h3>
                    <v-chip-group column v-model="options.flagFilter">
                        <Fragment :flag="1"></Fragment>
                        <Fragment :flag="2"></Fragment>
                        <Fragment :flag="3"></Fragment>
                        <Fragment :flag="4"></Fragment>
                    </v-chip-group>
                </v-card>
            </v-menu>
        </template> -->
        <template v-slot:header.tax_id="{ column }">
                <!-- In the stacked card layout Vuetify reuses this slot as each card's
                     row label, where a filter widget makes no sense; show the plain
                     column title instead. -->
                <TaxonomyAutocomplete
                    v-if="!$vuetify.display.xs"
                    :cluster="cluster"
                    v-model="options.tax_id"
                    :urlFunction="(a, b) => '/cluster/' + a + '/members/taxonomy/' + b"
                    :options="requestOptions"
                    :disabled="taxAutocompleteDisabled">
                </TaxonomyAutocomplete>
                <template v-else>{{ column.title }}</template>
        </template>
        <template v-slot:item.plddt="prop">
            {{ prop.value != null ? prop.value.toFixed(2) : 'NA' }}
        </template>
        <template v-slot:item.tax_id="prop">
            <TaxSpan :taxonomy="prop.value"></TaxSpan>
        </template>
        <template v-slot:item.actions="{ item }">
            <v-chip title="Search with Foldseek" :href="'https://search.foldseek.com/search?accession=' + item.accession + '&source=BFVD_v2'" target="_blank">
                <img src="./assets/marv-foldseek-small.png" style="display: inline-block; width: 16px; height: 16px;" />
            </v-chip>
        </template>
    </v-data-table-server>
    </div>
    </template>
</template>
</Panel>
</template>

<script>
import StructureThumb from "./StructureThumb.vue";
import TaxSpan from "./TaxSpan.vue";
import StructureViewer from "./StructureViewer.vue";
import ExternalLinks from "./ExternalLinks.vue";
import TaxonomyAutocomplete from "./TaxonomyAutocomplete.vue";
import Fragment from "./Fragment.vue";
import Sankey from './Sankey.vue';
import Panel from "./Panel.vue";

export default {
    name: "members",
    components: {
        StructureThumb,
        Panel,
        TaxSpan,
        StructureViewer,
        ExternalLinks,
        TaxonomyAutocomplete,
        Fragment,
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
                    width: "5%",
                },
                {
                    title: "Accession",
                    value: "accession",
                    sortable: false,
                    width: "30%",
                },
                {
                    title: "pLDDT",
                    value: "plddt",
                    sortable: false,
                    width: "5%",
                },
                // {
                //     text: "Length",
                //     value: "len",
                //     sortable: false,
                // },
                // {
                //     text: "Clustered step",
                //     value: "flag",
                //     sortable: false,
                //     width: "10%",
                // },
                {
                    title: "Taxonomy",
                    value: "tax_id",
                    sortable: false,
                    width: "20%",
                },
                {
                    text: 'Actions',
                    value: 'actions',
                    sortable: false,
                    width: "10%",
                },
            ],
            members: [],
            totalMembers: 0,
            loading: false,
            options: {
                page: 1,
                itemsPerPage: 10,
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
            const cluster = this.$route.params.cluster;
            if (!cluster) {
                return;
            }

            this.$axios.get("/cluster/" + cluster + "/members", this.requestOptions)
                .then(response => {
                    this.members = response.data.result;
                    this.totalMembers = response.data.total;
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
.description {
    max-width: 40em;
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
