import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { lineTotal, roundMoney, sumMoney } from '../utils/money.js'

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

  const subtotal = computed(() => sumMoney(items.value.map(lineTotal)))
  const total = computed(() => roundMoney(subtotal.value - discount.value))
  // Weight-priced lines carry fractional quantities — keep the badge readable.
  const itemCount = computed(() =>
    Math.round(items.value.reduce((sum, i) => sum + i.qty, 0) * 1000) / 1000
  )

  function addItem(product, qty = 1, customPrice = null) {
    const price = customPrice !== null ? parseFloat(customPrice) : parseFloat(product.price)
    const existing = activeSession.value.items.find(i => i.product_id === product.id)
    if (existing) {
      existing.qty = parseFloat((existing.qty + qty).toFixed(4))
      existing.amount = null // qty changed — the entered sum no longer applies
      if (customPrice !== null) existing.unit_price = price
    } else {
      activeSession.value.items.push({
        product_id: product.id,
        name: product.name,
        barcode: product.barcode,
        unit_price: price,
        qty,
        discount: 0,
        amount: null
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
      else {
        item.qty = Math.round(qty * 10000) / 10000
        item.amount = null // qty is now what was asked for, not a sum
      }
    }
  }

  /**
   * Sell a given sum's worth of a line ("4 000 of rice at 75 000/kg").
   *
   * The sum is what the customer pays, so it is stored verbatim and qty is the
   * exact ratio — deliberately left unrounded, because rounding it to 0.05 kg
   * would silently turn a 4 000 sale into 3 750.
   */
  function setLineAmount(productId, amount) {
    const item = activeSession.value.items.find(i => i.product_id === productId)
    if (!item) return
    const sum = roundMoney(amount)
    if (sum <= 0 || !(item.unit_price > 0)) {
      removeItem(productId)
      return
    }
    item.amount = sum
    item.qty = sum / item.unit_price
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
    addItem, removeItem, updateQty, setLineAmount, updateDiscount,
    setDiscount, setCustomer, clear,
    newSession, switchSession, closeSession
  }
})
