<template>
    <v-combobox
        class="bfvd-field"
        variant="outlined"
        :model-value="modelValue"
        label="Protein name"
        placeholder="Start typing a protein name"
        hide-no-data
        no-filter
        :items="items"
        item-title="name"
        item-value="name"
        :return-object="false"
        :loading="isLoading"
        v-model:search="search"
        style="max-width: 400px; margin: 0 auto;"
        @keydown.enter="submit(search)"
    >
        <template v-slot:item="{ item, props }">
            <v-list-item
                v-bind="props"
                :title="item.raw.name"
                :subtitle="item.raw.n_entry.toLocaleString() + (item.raw.n_entry == 1 ? ' entry' : ' entries')"
                @click="submit(item.raw.name)"
            ></v-list-item>
        </template>
    </v-combobox>
</template>

<script>
import { debounce } from './lib/debounce';

export default {
    props: ['modelValue'],
    emits: ['update:modelValue', 'search'],
    data() {
        return {
            items: [],
            isLoading: false,
            search: this.modelValue,
        }
    },
    watch: {
        modelValue(val) {
            this.search = val;
        },
        search(val) {
            if (val !== this.modelValue) {
                this.$emit('update:modelValue', val);
            }
            if (val && val.trim().length > 2) {
                this.querySelections(val);
            } else {
                this.items = [];
            }
        },
    },
    methods: {
        submit(name) {
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
