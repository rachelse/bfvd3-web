<template>
    <v-autocomplete
        class="bfvd-field"
        variant="outlined"
        label="Protein name"
        style="max-width: 400px; margin: 0 auto;"
        v-model:search="search"
        :model-value="modelValue || null"
        item-title="name"
        item-value="name"
        placeholder="Start typing a protein name"
        hide-no-data
        :items="items"
        :loading="isLoading"
        no-filter
        auto-select-first
        @update:model-value="pick"
        @update:focused="focused = $event"
    >
        <template v-slot:item="{ item, props }">
            <v-list-item
                v-bind="props"
                :title="item.raw.name"
                :subtitle="item.raw.n_entry.toLocaleString() + (item.raw.n_entry == 1 ? ' entry' : ' entries')"
            ></v-list-item>
        </template>
    </v-autocomplete>
</template>

<script>
import { debounce } from './lib/debounce';

// Only names from the suggestions can be picked, since the search matches whole names
export default {
    props: ['modelValue'],
    emits: ['update:modelValue', 'search'],
    data() {
        return {
            items: [],
            isLoading: false,
            search: null,
            focused: false,
        }
    },
    watch: {
        search(val) {
            if (!val && this.focused && this.modelValue) {
                this.$emit('update:modelValue', null);
            }
            if (val && val.trim().length > 2 && val !== this.modelValue) {
                this.querySelections(val);
            }
        },
    },
    methods: {
        pick(name) {
            if (!name) {
                return;
            }
            this.$emit('update:modelValue', name);
            this.$emit('search');
        },
        querySelections: debounce(function (name) {
            this.isLoading = true;
            this.$axios.get("/search/name-suggest", { params: { q: name } })
                .then(response => {
                    // drop answers to a query the user has already typed past
                    if (name === this.search) {
                        this.items = response.data;
                    }
                })
                .finally(() => { this.isLoading = false; });
        }, 300, false)
    },
}
</script>
