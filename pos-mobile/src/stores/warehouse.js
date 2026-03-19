import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const BASE_URL = import.meta.env.VITE_API_URL || ''

export const useWarehouseStore = defineStore('warehouse', () => {
  const token = ref(localStorage.getItem('wh_token') || '')
  const user = ref(JSON.parse(localStorage.getItem('wh_user') || 'null'))
  const products = ref([])
  const receipts = ref([])

  const isLoggedIn = computed(() => !!token.value && !!user.value)
  const warehouseId = computed(() => user.value?.warehouse_id || 1)
  const role = computed(() => user.value?.role || '')
  const canSell = computed(() => ['cashier', 'manager', 'admin'].includes(role.value))
  const isWarehouse = computed(() => role.value === 'warehouse')

  function login(userData, jwt) {
    user.value = userData
    token.value = jwt
    localStorage.setItem('wh_user', JSON.stringify(userData))
    localStorage.setItem('wh_token', jwt)
  }

  function logout() {
    user.value = null
    token.value = ''
    localStorage.removeItem('wh_user')
    localStorage.removeItem('wh_token')
  }

  async function fetchProducts() {
    const res = await authFetch('/api/inventory/mobile')
    products.value = await res.json()
  }

  async function fetchReceipts() {
    const res = await authFetch('/api/incoming')
    receipts.value = await res.json()
  }

  async function authFetch(path, opts = {}) {
    const res = await fetch(`${BASE_URL}${path}`, {
      ...opts,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token.value}`,
        ...opts.headers
      }
    })
    if (res.status === 401) {
      logout()
      const { default: router } = await import('../router/index.js')
      router.push({ name: 'login' })
    }
    return res
  }

  return { token, user, products, receipts, isLoggedIn, warehouseId, role, canSell, isWarehouse, login, logout, fetchProducts, fetchReceipts, authFetch }
})
