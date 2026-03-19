import { createRouter, createWebHashHistory } from 'vue-router'
import { useWarehouseStore } from '../stores/warehouse.js'

const routes = [
  { path: '/', redirect: '/sales' },
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/MobileLoginView.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/sales',
    name: 'sales',
    component: () => import('../views/MobileSaleView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/incoming',
    name: 'incoming',
    component: () => import('../views/IncomingFormView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/inventory',
    name: 'inventory',
    component: () => import('../views/MobileInventoryView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/reports',
    name: 'reports',
    component: () => import('../views/MobileReportsView.vue'),
    meta: { requiresAuth: true }
  }
]

const router = createRouter({
  history: createWebHashHistory('/mobile/'),
  routes
})

router.beforeEach((to) => {
  const store = useWarehouseStore()
  if (to.meta.requiresAuth !== false && !store.isLoggedIn) {
    return { name: 'login' }
  }
})

export default router
