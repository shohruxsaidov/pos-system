<template>
  <div class="mobile-app">
    <RouterView />

    <!-- Bottom Nav (when logged in) -->
    <nav v-if="store.isLoggedIn" class="mobile-bottom-nav">
      <RouterLink to="/incoming" class="mobile-nav-item" active-class="active">
        <i class="pi pi-inbox mobile-nav-icon" />
        <span class="mobile-nav-label">Incoming</span>
      </RouterLink>
      <RouterLink to="/inventory" class="mobile-nav-item" active-class="active">
        <i class="pi pi-list mobile-nav-icon" />
        <span class="mobile-nav-label">Inventory</span>
      </RouterLink>
    </nav>

    <Toast position="top-center" />
  </div>
</template>

<script setup>
import { RouterLink, RouterView } from 'vue-router'
import { useWarehouseStore } from './stores/warehouse.js'
import Toast from 'primevue/toast'

const store = useWarehouseStore()
</script>

<style scoped>
.mobile-app {
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.mobile-app > :first-child {
  flex: 1;
  overflow: hidden;
}
</style>
