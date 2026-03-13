import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCartStore = defineStore('cart', () => {
  const items = ref([])
  const discount = ref(0)
  const customerId = ref(null)
  const customerName = ref('')

  const subtotal = computed(() =>
    items.value.reduce((sum, item) => sum + item.unit_price * item.qty - (item.discount || 0), 0)
  )

  const total = computed(() => subtotal.value - discount.value)

  const itemCount = computed(() => items.value.reduce((sum, i) => sum + i.qty, 0))

  function addItem(product, qty = 1) {
    const existing = items.value.find(i => i.product_id === product.id)
    if (existing) {
      existing.qty += qty
    } else {
      items.value.push({
        product_id: product.id,
        name: product.name,
        barcode: product.barcode,
        unit_price: parseFloat(product.price),
        qty,
        discount: 0
      })
    }
  }

  function removeItem(productId) {
    items.value = items.value.filter(i => i.product_id !== productId)
  }

  function updateQty(productId, qty) {
    const item = items.value.find(i => i.product_id === productId)
    if (item) {
      if (qty <= 0) removeItem(productId)
      else item.qty = qty
    }
  }

  function updateDiscount(productId, disc) {
    const item = items.value.find(i => i.product_id === productId)
    if (item) item.discount = disc
  }

  function setDiscount(amount) {
    discount.value = amount
  }

  function setCustomer(id, name) {
    customerId.value = id
    customerName.value = name
  }

  function clear() {
    items.value = []
    discount.value = 0
    customerId.value = null
    customerName.value = ''
  }

  return {
    items, discount, customerId, customerName,
    subtotal, total, itemCount,
    addItem, removeItem, updateQty, updateDiscount,
    setDiscount, setCustomer, clear
  }
})
