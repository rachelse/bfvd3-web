<template>
    <v-app id="app">
        <navigation />
        <v-main>
            <router-view></router-view>
        </v-main>
    </v-app>
</template>

<script>
import Navigation from './Navigation.vue';

export default {
    components: { Navigation },
}
</script>

<style>
:root {
    --BFVD_CLR: #30E940;
}

.v-theme--light {
    --BFVD_LINK_CLR: rgb(var(--v-theme-primary));
}

.v-theme--dark {
    --BFVD_LINK_CLR: var(--BFVD_CLR);
}

/* Brand-coloured search field, focused or not; the error state keeps Vuetify's red.
   Global so search fields inside child components get it too. */
.bfvd-field .v-field:not(.v-field--error) .v-field__outline {
    color: var(--BFVD_CLR);
    --v-field-border-opacity: 1;
}

.bfvd-field .v-field:not(.v-field--error) .v-label {
    color: var(--BFVD_CLR);
    opacity: 1;
}

.bfvd-field .v-input__control:has(.v-field:not(.v-field--error)) ~ .v-input__append .v-icon {
    color: var(--BFVD_CLR);
    opacity: 1;
}

/* Vuetify 3 dropped Vuetify 2's anchor rule, so links fell back to browser defaults
   -- #0000EE, and #551A8B once visited. Restore one themed colour, visited included. */
a {
    color: rgb(var(--v-theme-primary));
    text-decoration: none;
}

a:visited {
    color: rgb(var(--v-theme-primary));
}

a:hover {
    text-decoration: underline;
}

/* Vuetify's own link-like components already colour themselves. */
.v-btn a,
.v-list-item a,
.v-chip a {
    color: inherit;
}

.accession-link {
    color: var(--BFVD_LINK_CLR) !important;
}
</style>
