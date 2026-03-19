<template>
  <div class="mobile-app">
    <RouterView />

    <!-- Bottom Nav (when logged in) -->
    <nav v-if="store.isLoggedIn" class="mobile-bottom-nav">
      <RouterLink v-if="store.canSell" to="/sales" class="mobile-nav-item" active-class="active">
        <i class="pi pi-shopping-cart mobile-nav-icon" />
        <span class="mobile-nav-label">Продажи</span>
      </RouterLink>
      <RouterLink v-if="store.isWarehouse || !store.canSell || store.role === 'manager' || store.role === 'admin'" to="/incoming" class="mobile-nav-item" active-class="active">
        <i class="pi pi-inbox mobile-nav-icon" />
        <span class="mobile-nav-label">Приёмка</span>
      </RouterLink>
      <RouterLink v-if="store.isWarehouse || store.role === 'manager' || store.role === 'admin'" to="/inventory" class="mobile-nav-item" active-class="active">
        <i class="pi pi-list mobile-nav-icon" />
        <span class="mobile-nav-label">Инвентарь</span>
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
  height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.mobile-app > :first-child {
  flex: 1;
  overflow: hidden;
}
</style>
