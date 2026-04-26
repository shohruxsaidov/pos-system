import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

let _counter = 1

function createSession() {
  const n = _counter++
  return {
    id: n,
    label: `Клиент ${n}`,
    items: [],
    discount: 0,
    customerId: null,
    customerName: ''
  }
}

export const useCartStore = defineStore('cart', () => {
  const sessions = ref([createSession()])
  const activeId = ref(sessions.value[0].id)

  const activeSession = computed(() =>
    sessions.value.find(s => s.id === activeId.value) ?? sessions.value[0]
  )

  // All existing getters delegate to the active session
  const items = computed(() => activeSession.value.items)
  const discount = computed(() => activeSession.value.discount)
  const customerId = computed(() => activeSession.value.customerId)
  const customerName = computed(() => activeSession.value.customerName)

  const subtotal = computed(() =>
    items.value.reduce((sum, item) => sum + item.unit_price * item.qty - (item.discount || 0), 0)
  )
  const total = computed(() => subtotal.value - discount.value)
  const itemCount = computed(() => items.value.reduce((sum, i) => sum + i.qty, 0))

  function addItem(product, qty = 1, customPrice = null) {
    const price = customPrice !== null ? parseFloat(customPrice) : parseFloat(product.price)
    const existing = activeSession.value.items.find(i => i.product_id === product.id)
    if (existing) {
      existing.qty = parseFloat((existing.qty + qty).toFixed(4))
      if (customPrice !== null) existing.unit_price = price
    } else {
      activeSession.value.items.push({
        product_id: product.id,
        name: product.name,
        barcode: product.barcode,
        unit_price: price,
        qty,
        discount: 0
      })
    }
  }

  function removeItem(productId) {
    activeSession.value.items = activeSession.value.items.filter(i => i.product_id !== productId)
  }

  function updateQty(productId, qty) {
    const item = activeSession.value.items.find(i => i.product_id === productId)
    if (item) {
      if (qty <= 0) removeItem(productId)
      else item.qty = Math.round(qty * 10000) / 10000
    }
  }

  function updateDiscount(productId, disc) {
    const item = activeSession.value.items.find(i => i.product_id === productId)
    if (item) item.discount = disc
  }

  function setDiscount(amount) {
    activeSession.value.discount = amount
  }

  function setCustomer(id, name) {
    activeSession.value.customerId = id
    activeSession.value.customerName = name
  }

  function clear() {
    activeSession.value.items = []
    activeSession.value.discount = 0
    activeSession.value.customerId = null
    activeSession.value.customerName = ''
  }

  // ── Multi-session management ──────────────────────────────────────────────

  function newSession() {
    if (sessions.value.length >= 8) return
    const s = createSession()
    sessions.value.push(s)
    activeId.value = s.id
  }

  function switchSession(id) {
    activeId.value = id
  }

  function closeSession(id) {
    if (sessions.value.length <= 1) {
      clear()
      return
    }
    const idx = sessions.value.findIndex(s => s.id === id)
    sessions.value.splice(idx, 1)
    if (activeId.value === id) {
      activeId.value = sessions.value[Math.min(idx, sessions.value.length - 1)].id
    }
  }

  return {
    sessions, activeId, activeSession,
    items, discount, customerId, customerName,
    subtotal, total, itemCount,
    addItem, removeItem, updateQty, updateDiscount,
    setDiscount, setCustomer, clear,
    newSession, switchSession, closeSession
  }
})
