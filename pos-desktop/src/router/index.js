import { createRouter, createWebHashHistory } from 'vue-router'
import { useSessionStore } from '../stores/session.js'

const routes = [
  {
    path: '/',
    redirect: '/home'
  },
  {
    path: '/home',
    name: 'home',
    component: () => import('../views/HomeView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/LoginView.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/pos',
    name: 'pos',
    component: () => import('../views/POSView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/inventory',
    name: 'inventory',
    component: () => import('../views/InventoryView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/categories',
    name: 'categories',
    component: () => import('../views/CategoriesView.vue'),
    meta: { requiresAuth: true, roles: ['manager', 'admin'] }
  },
  {
    path: '/reports',
    name: 'reports',
    component: () => import('../views/ReportsView.vue'),
    meta: { requiresAuth: true, roles: ['manager', 'admin'] }
  },
  {
    path: '/transactions',
    name: 'transactions',
    component: () => import('../views/TransactionsView.vue'),
    meta: { requiresAuth: true, roles: ['manager', 'admin'] }
  },
  {
    path: '/customers',
    name: 'customers',
    component: () => import('../views/CustomersView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/warehouse',
    name: 'warehouse',
    component: () => import('../views/WarehouseView.vue'),
    meta: { requiresAuth: true, roles: ['manager', 'admin'] }
  },
  {
    path: '/settings',
    name: 'settings',
    component: () => import('../views/SettingsView.vue'),
    meta: { requiresAuth: true, roles: ['manager', 'admin'] }
  },
  {
    path: '/printer-settings',
    name: 'printer-settings',
    component: () => import('../views/PrinterSettingsView.vue'),
    meta: { requiresAuth: true, roles: ['manager', 'admin'] }
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

router.beforeEach((to) => {
  const session = useSessionStore()

  if (to.meta.requiresAuth !== false && !session.isLoggedIn) {
    return { name: 'login' }
  }

  if (to.meta.roles && !to.meta.roles.includes(session.user?.role)) {
    return { name: 'pos' }
  }
})

export default router
