<template>
    <!-- entry.flag records how the structure was predicted.
         1: ColabFold-AF2, 2: ESMFold + ProteinTTT(MSA) -->
    <span>{{ flagText }}</span>
</template>

<script>

export default {
    name: "Fragment",
    props: ["flag"],
    computed: {
        flagText() {
            if (this.flag == 1) {
                return "ColabFold-AF2";
            } else if (this.flag == 2) {
                return "ESMFold+ProteinTTT";
            }
            return "NA";
        }
    }
}

</script>
