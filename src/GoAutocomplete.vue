<template>
    <v-tooltip open-delay="300" location="top">
        <template v-slot:activator="{ props }">
            <v-autocomplete
                variant="outlined"
                :value="value"
                label="GO Term"
                placeholder="Start typing to search GO terms"
                hide-no-data
                no-filter
                :items="items"
                :loading="isLoading"
                v-model:search-input="search"
                style="max-width: 400px; margin: 0 auto;"
                @input="change"
                return-object
                auto-select-first
                :allow-overflow="false"
                theme="dark"
                v-bind="$attrs"
            >
                <template v-slot:item="{ item }">
                    {{ item.text }} ({{ item.value }})
                </template>
            </v-autocomplete>
        </template>
        <span>Search for Gene Ontology (GO) terms</span>
    </v-tooltip>
  </template>
  
  <script>
  import { debounce } from './lib/debounce';
  
  export default {
    props: ['value'],
    data() {
        return {
            items: [],
            isLoading: false,
            search: null,
        }
    },
    mounted() {
        this.items = [ this.value ];
    },
    watch: {
        value(val) {
            this.items = [ this.value ];
        },
        search (val) {
            val && val.length > 2 && val !== this.value && this.queryGOSelections(val)
        },
    },
    methods: {
        change(goTerm) {
          this.$emit('input', goTerm);
        },
        queryGOSelections: debounce(function (term) {
            this.isLoading = true;
            this.$axios.get("/autocomplete/go/" + encodeURIComponent(term))
                .then(response => {
                    if (response.status == 200 && response.data.hasOwnProperty("result")) {
                        this.items = response.data.result.map((el) => {
                            return { text: el.go_name, value: el.go_id }
                        });
                    }
                }).finally(() => { this.isLoading = false; });
        }, 300, false)
    },
  }
  </script>
  