<template>
  <v-card style="padding: 2em; width: 250px;">
    <h3>Filter by</h3>
    <v-text-field
        v-model="min"
        @change="commit"
        @keyup.enter="commit"
        placeholder="min"
        single-line
        hide-details
        type="number"
        variant="outlined"
        density="compact"
        style="width: 80px; display: inline-block;">
    </v-text-field>
    ~
    <v-text-field
        v-model="max"
        @change="commit"
        @keyup.enter="commit"
        placeholder="max"
        single-line
        hide-details
        type="number"
        variant="outlined"
        density="compact"
        style="width: 80px; display: inline-block;">
    </v-text-field>
</v-card>
</template>

<script>

// Edits a [min, max] array owned by the parent in place; the parent watches it deeply
// and refetches. An empty field means unbounded (0 / Infinity).
function toField(value) {
  return Number.isFinite(value) ? String(value) : "";
}

export default {
  name: "RangeSlider",
  props: ["range"],
  data() {
    return {
      min: toField(this.range[0]),
      max: toField(this.range[1]),
    };
  },
  methods: {
    commit() {
      const min = this.min === "" ? 0 : Number(this.min);
      const max = this.max === "" ? Infinity : Number(this.max);
      if (Number.isNaN(min) || Number.isNaN(max)) {
        return;
      }
      if (this.range[0] !== min) {
        this.range[0] = min;
      }
      if (this.range[1] !== max) {
        this.range[1] = max;
      }
    },
  },
}

</script>
