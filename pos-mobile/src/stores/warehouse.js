import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  generateClientRef, getQueue, enqueue, dequeue,
  saveProductsCache, loadProductsCache, patchProductStock
} from '../composables/useOfflineQueue.js'

const BASE_URL = import.meta.env.VITE_API_URL || ''

export const useWarehouseStore = defineStore('warehouse', () => {
  const token = ref(sessionStorage.getItem('wh_token') || '')
  const user = ref(JSON.parse(sessionStorage.getItem('wh_user') || 'null'))
  const products = ref([])
  const receipts = ref([])

  // Offline state
  const isOnline = ref(true)
  const queueLength = ref(getQueue().length)
  const isSyncing = ref(false)

  const isLoggedIn = computed(() => !!token.value && !!user.value)
  const warehouseId = computed(() => user.value?.warehouse_id || 1)
  const role = computed(() => user.value?.role || '')
  const canSell = computed(() => ['cashier', 'manager', 'admin'].includes(role.value))
  const isWarehouse = computed(() => role.value === 'warehouse')

  function login(userData, jwt) {
    user.value = userData
    token.value = jwt
    sessionStorage.setItem('wh_user', JSON.stringify(userData))
    sessionStorage.setItem('wh_token', jwt)
  }

  function logout() {
    user.value = null
    token.value = ''
    sessionStorage.removeItem('wh_user')
    sessionStorage.removeItem('wh_token')
  }

  async function fetchProducts() {
    try {
      const res = await authFetch('/api/inventory/mobile')
      const data = await res.json()
      if (Array.isArray(data)) {
        products.value = data
        saveProductsCache(data)
      }
    } catch {
      const cached = loadProductsCache()
      if (cached) products.value = cached
    }
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

  async function submitSale(payload) {
    const client_ref = generateClientRef()
    const body = { ...payload, client_ref }

    if (isOnline.value) {
      try {
        const res = await authFetch('/api/transactions', {
          method: 'POST',
          body: JSON.stringify(body)
        })
        const data = await res.json()
        if (!res.ok) throw new Error(data.error || 'Ошибка при оформлении')
        // Update local product stock
        for (const item of payload.items) {
          patchProductStock(item.product_id, -item.qty, products.value)
        }
        return { ok: true, data, offline: false }
      } catch (err) {
        // Only go offline on network errors, not HTTP errors
        if (!(err instanceof TypeError) && !err.name?.includes('Abort')) {
          throw err
        }
        isOnline.value = false
      }
    }

    // Offline path
    try {
      enqueue(body)
      queueLength.value++
      for (const item of payload.items) {
        patchProductStock(item.product_id, -item.qty, products.value)
      }
      return { ok: true, data: { ref_no: client_ref }, offline: true }
    } catch {
      throw new Error('Не удалось сохранить продажу: хранилище переполнено')
    }
  }

  async function syncQueue() {
    const queue = getQueue()
    if (!queue.length || isSyncing.value || !isOnline.value) return null

    isSyncing.value = true
    let synced = 0
    let failed = 0

    for (const sale of queue) {
      try {
        const res = await authFetch('/api/transactions', {
          method: 'POST',
          body: JSON.stringify(sale)
        })
        if (res.status === 401) break
        if (res.ok || res.status === 200) {
          dequeue(sale.client_ref)
          synced++
        } else {
          failed++
          break
        }
      } catch {
        failed++
        break
      }
    }

    isSyncing.value = false
    queueLength.value = getQueue().length

    if (synced > 0) fetchProducts().catch(() => {})

    return { synced, failed }
  }

  return {
    token, user, products, receipts,
    isOnline, queueLength, isSyncing,
    isLoggedIn, warehouseId, role, canSell, isWarehouse,
    login, logout, fetchProducts, fetchReceipts, authFetch,
    submitSale, syncQueue
  }
})
