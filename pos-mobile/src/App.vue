<template>
  <div class="mobile-app">
    <div class="route-container">
      <RouterView v-slot="{ Component, route }">
        <Transition :name="transitionName">
          <component :is="Component" :key="route.name" class="route-view" />
        </Transition>
      </RouterView>
    </div>

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
      <RouterLink v-if="store.role === 'manager' || store.role === 'admin'" to="/reports" class="mobile-nav-item" active-class="active">
        <i class="pi pi-chart-bar mobile-nav-icon" />
        <span class="mobile-nav-label">Отчёты</span>
      </RouterLink>
    </nav>

    <Toast position="top-center" />
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { useWarehouseStore } from './stores/warehouse.js'
import Toast from 'primevue/toast'

const store = useWarehouseStore()
const router = useRouter()

// Route order for determining slide direction
const routeOrder = ['login', 'sales', 'incoming', 'inventory', 'reports']

const transitionName = ref('slide-left')

router.beforeEach((to, from) => {
  const fromIdx = routeOrder.indexOf(from.name)
  const toIdx = routeOrder.indexOf(to.name)

  if (fromIdx === -1 || toIdx === -1) {
    transitionName.value = 'fade'
  } else if (toIdx > fromIdx) {
    transitionName.value = 'slide-left'
  } else {
    transitionName.value = 'slide-right'
  }
})
</script>

<style scoped>
.mobile-app {
  height: 100vh;
  height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.route-container {
  flex: 1;
  position: relative;
  overflow: hidden;
  min-height: 0;
}

.route-view {
  position: absolute;
  inset: 0;
  overflow: hidden;
}

/* Transitions */
.slide-left-enter-active,
.slide-left-leave-active,
.slide-right-enter-active,
.slide-right-leave-active {
  transition: transform 0.28s cubic-bezier(0.4, 0, 0.2, 1),
              opacity 0.28s cubic-bezier(0.4, 0, 0.2, 1);
  position: absolute;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}

.slide-left-enter-from {
  transform: translateX(100%);
  opacity: 0;
}
.slide-left-leave-to {
  transform: translateX(-30%);
  opacity: 0;
}
.slide-left-enter-to,
.slide-left-leave-from {
  transform: translateX(0);
  opacity: 1;
}

.slide-right-enter-from {
  transform: translateX(-100%);
  opacity: 0;
}
.slide-right-leave-to {
  transform: translateX(30%);
  opacity: 0;
}
.slide-right-enter-to,
.slide-right-leave-from {
  transform: translateX(0);
  opacity: 1;
}

/* Fade (login → app) */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.22s ease;
  position: absolute;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
