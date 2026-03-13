<template>
  <div class="app-shell">
    <!-- Sidebar Nav (when logged in) -->
    <aside v-if="session.isLoggedIn" class="sidebar">
      <div class="sidebar-brand">
        <div class="brand-icon">
          <i class="pi pi-shopping-bag" />
        </div>
        <span class="brand-name">POS</span>
      </div>

      <nav class="sidebar-nav">
        <RouterLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="nav-item"
          active-class="nav-item--active"
        >
          <i :class="item.icon" class="nav-icon" />
          <span class="nav-label">{{ item.label }}</span>
        </RouterLink>
      </nav>

      <div class="sidebar-footer">
        <div class="user-card">
          <div class="user-avatar">{{ session.user?.name?.[0] }}</div>
          <div class="user-info">
            <div class="user-name">{{ session.user?.name }}</div>
            <div class="user-role">{{ session.user?.role }}</div>
          </div>
        </div>
        <Button
          icon="pi pi-sign-out"
          class="p-button-secondary logout-btn"
          @click="logout"
          v-tooltip.right="'Выйти'"
        />
      </div>
    </aside>

    <!-- Main Content -->
    <main class="main-content">
      <RouterView />
    </main>

    <!-- Status Bar (always visible when logged in) -->
    <StatusBar v-if="session.isLoggedIn" />

    <!-- Toast -->
    <Toast position="top-right" />
    <ConfirmDialog />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { useSessionStore } from './stores/session.js'
import StatusBar from './components/StatusBar.vue'
import Button from 'primevue/button'
import Toast from 'primevue/toast'
import ConfirmDialog from 'primevue/confirmdialog'

const session = useSessionStore()
const router = useRouter()

const navItems = computed(() => {
  const items = [
    { to: '/pos', icon: 'pi pi-shopping-cart', label: 'POS' },
    { to: '/inventory', icon: 'pi pi-box', label: 'Склад' },
    { to: '/customers', icon: 'pi pi-users', label: 'Клиенты' }
  ]
  if (['manager', 'admin'].includes(session.user?.role)) {
    items.push({ to: '/reports', icon: 'pi pi-chart-bar', label: 'Отчёты' })
    items.push({ to: '/settings', icon: 'pi pi-cog', label: 'Настройки' })
  }
  return items
})

function logout() {
  session.logout()
  router.push('/login')
}
</script>

<style scoped>
.app-shell {
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.app-shell > .main-content {
  flex: 1;
  overflow: hidden;
  display: flex;
}

/* When sidebar is present, layout changes */
.app-shell:has(.sidebar) {
  flex-direction: row;
  flex-wrap: wrap;
}

.app-shell:has(.sidebar) > .main-content {
  flex: 1;
}

.app-shell:has(.sidebar) > :last-child {
  width: 100%;
  flex-shrink: 0;
}

.sidebar {
  width: 220px;
  background: var(--bg-sidebar);
  border-right: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  min-height: calc(100vh - 40px); /* Account for status bar height */
}

.sidebar-brand {
  height: 64px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 16px;
  border-bottom: 1px solid var(--border-subtle);
}

.brand-icon {
  width: 36px;
  height: 36px;
  background: var(--gradient-hero);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 16px;
  box-shadow: var(--shadow-accent);
}

.brand-name {
  font-size: 18px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.sidebar-nav {
  flex: 1;
  padding: 12px 8px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 12px;
  border-radius: 12px;
  color: var(--text-secondary);
  text-decoration: none;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.15s;
}

.nav-item:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.nav-item--active {
  background: var(--accent-glow);
  color: var(--text-accent);
  font-weight: 600;
}

.nav-item--active .nav-icon {
  color: var(--accent-1);
}

.nav-icon {
  font-size: 18px;
  width: 24px;
}

.sidebar-footer {
  padding: 12px;
  border-top: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  gap: 8px;
}

.user-card {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  overflow: hidden;
}

.user-avatar {
  width: 36px;
  height: 36px;
  background: var(--gradient-accent);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  color: #fff;
  flex-shrink: 0;
}

.user-info { overflow: hidden; }

.user-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.user-role {
  font-size: 11px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.logout-btn {
  height: 36px !important;
  width: 36px !important;
  border-radius: 8px !important;
  padding: 0 !important;
  flex-shrink: 0;
}

.main-content {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
</style>
