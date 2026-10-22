<template>
    <v-chip :color="chipColor" variant="outlined">
        {{ chipText }}
    </v-chip>
</template>

<script>

// Yes/no chip for the Singleton column, or the Reference proteome column when isReference is set
export default {
    name: "IsSingleton",
    props: ["isSingleton", "isReference"],
    computed: {
        chipText() {
            if (this.isReference != null) {
                return this.isReference == 1 ? "Reference" : "Non-reference";
            }
            if (this.isSingleton == 0) {
                return "Non-singleton";
            } else if (this.isSingleton == 1) {
                return "Singleton";
            }
        },
        chipColor() {
            if (this.isReference != null) {
                return this.isReference == 1 ? "#7CB987" : "#9E9E9E";
            }
            if (this.isSingleton == 0) {
                return "#7CB987";
            } else if (this.isSingleton == 1) {
                return "#9E9E9E";
            }
        }
    }
}

</script>

<style scoped>
.v-chip-group .v-chip--active {
    font-weight: bold;
    border-width: 2px;
}
</style>
