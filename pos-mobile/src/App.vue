<template>
  <div class="mobile-app">
    <div class="route-container">
      <RouterView v-slot="{ Component, route }">
        <Transition :name="transitionName">
          <component :is="Component" :key="route.name" class="route-view" />
        </Transition>
      </RouterView>
    </div>

    <!-- Offline / Syncing Banner -->
    <Transition name="banner-slide">
      <div
        v-if="store.isLoggedIn && (!isOnline || store.queueLength > 0)"
        class="offline-banner"
        :class="{ syncing: store.isSyncing }"
      >
        <template v-if="!isOnline">
          <i class="pi pi-wifi" style="opacity:0.5" />
          <span>Офлайн режим</span>
          <span v-if="store.queueLength > 0" class="pending-pill">
            {{ store.queueLength }} в очереди
          </span>
        </template>
        <template v-else-if="store.isSyncing">
          <i class="pi pi-spin pi-spinner" />
          <span>Синхронизация...</span>
        </template>
        <template v-else>
          <i class="pi pi-cloud-upload" />
          <span>Отправка {{ store.queueLength }} продаж...</span>
        </template>
      </div>
    </Transition>

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
import { ref, watch, onMounted } from 'vue'
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { useWarehouseStore } from './stores/warehouse.js'
import { useConnectivity } from './composables/useConnectivity.js'
import { useToast } from 'primevue/usetoast'
import Toast from 'primevue/toast'

const store = useWarehouseStore()
const router = useRouter()
const toast = useToast()
const { isOnline, probe } = useConnectivity()

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

// Wire connectivity state into store and trigger sync on reconnect
watch(isOnline, async (online) => {
  store.isOnline = online
  if (online && store.queueLength > 0) {
    const result = await store.syncQueue()
    if (result?.synced > 0) {
      toast.add({
        severity: 'success',
        summary: 'Синхронизировано',
        detail: `${result.synced} продаж отправлено`,
        life: 4000
      })
    }
  }
}, { immediate: true })

onMounted(() => {
  // Sync on tab visibility restore
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && store.queueLength > 0) {
      probe().then(() => { if (store.isOnline) store.syncQueue() })
    }
  })

  // Periodic retry every 30s if queue not empty
  setInterval(() => {
    if (store.queueLength > 0 && store.isOnline) store.syncQueue()
  }, 30_000)
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

/* Offline / Syncing Banner */
.offline-banner {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 36px;
  padding: 0 16px;
  background: rgba(255, 176, 46, 0.12);
  border-top: 1px solid rgba(255, 176, 46, 0.2);
  color: var(--warning);
  font-size: 13px;
  font-weight: 600;
  overflow: hidden;
}

.offline-banner.syncing {
  background: rgba(123, 104, 238, 0.10);
  border-top-color: rgba(123, 104, 238, 0.2);
  color: var(--accent-1);
}

.pending-pill {
  background: rgba(255, 176, 46, 0.2);
  border-radius: 10px;
  padding: 1px 8px;
  font-size: 11px;
}

/* Banner slide transition */
.banner-slide-enter-active,
.banner-slide-leave-active {
  transition: max-height 0.25s ease, opacity 0.25s ease;
  max-height: 48px;
  overflow: hidden;
}
.banner-slide-enter-from,
.banner-slide-leave-to {
  max-height: 0;
  opacity: 0;
}
</style>
