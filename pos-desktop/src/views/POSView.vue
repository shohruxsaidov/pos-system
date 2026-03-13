<template>
  <div class="pos-layout">
    <!-- Left: Product Grid -->
    <div class="pos-products">
      <!-- Search Bar -->
      <div class="pos-search">
        <IconField>
          <InputIcon class="pi pi-barcode" />
          <InputText ref="searchRef" v-model="searchQuery" placeholder="Сканировать штрихкод или найти товар..."
            class="w-full" @keydown.enter="handleBarcodeEnter" @input="debouncedSearch" inputmode="none" />
        </IconField>
        <Button icon="pi pi-refresh" class="p-button-secondary" @click="loadProducts" style="height:56px;width:56px" />
      </div>

      <!-- Category Filter -->
      <div class="category-tabs">
        <button class="cat-tab" :class="{ active: !selectedCategory }"
          @click="selectedCategory = null; loadProducts()">Все</button>
        <button v-for="cat in categories" :key="cat.id" class="cat-tab" :class="{ active: selectedCategory === cat.id }"
          @click="selectedCategory = cat.id; loadProducts()">{{ cat.name }}</button>
      </div>
      <div class="products-area">
        <div v-for="item in products" :key="item.id" class="product-card"
          :class="{ 'out-of-stock': item.stock_qty <= 0 }" @click="addToCart(item)">
          <div class="product-name">{{ item.name }}</div>
          <div class="product-price font-mono">{{ formatPrice(item.price) }}</div>
          <div class="product-stock" :class="stockClass(item.stock_qty)">
            {{ stockLabel(item.stock_qty) }}
          </div>
        </div>
      </div>

    </div>

    <!-- Right: Cart -->
    <div class="pos-cart">
      <div class="cart-header">
        <h2 class="cart-title">Корзина</h2>
        <Tag v-if="cart.itemCount > 0" :value="`${cart.itemCount} поз.`" class="cart-count" />
        <Button v-if="cart.itemCount > 0" icon="pi pi-trash" class="p-button-danger" style="height:40px;width:40px"
          @click="cart.clear()" v-tooltip="'Очистить корзину'" />
      </div>

      <!-- Cart Items -->
      <div class="cart-items">
        <DataTable :value="cart.items" scrollable scroll-height="flex" class="cart-table">
          <Column field="name" header="Товар" />
          <Column field="unit_price" header="Цена" style="width:90px">
            <template #body="{ data }">
              <span class="font-mono">{{ formatPrice(data.unit_price) }}</span>
            </template>
          </Column>
          <Column header="Кол-во" style="width:120px">
            <template #body="{ data }">
              <div class="qty-control">
                <button class="qty-btn" @click="cart.updateQty(data.product_id, data.qty - 1)">−</button>
                <span class="qty-value font-mono">{{ data.qty }}</span>
                <button class="qty-btn" @click="cart.updateQty(data.product_id, data.qty + 1)">+</button>
              </div>
            </template>
          </Column>
          <Column header="Итого" style="width:90px">
            <template #body="{ data }">
              <span class="font-mono">{{ formatPrice(data.unit_price * data.qty) }}</span>
            </template>
          </Column>
          <Column style="width:44px">
            <template #body="{ data }">
              <button class="remove-btn" @click="cart.removeItem(data.product_id)">✕</button>
            </template>
          </Column>
        </DataTable>
      </div>

      <!-- Cart Footer -->
      <div class="cart-footer">
        <div class="cart-totals">
          <div class="total-row">
            <span class="text-secondary">Подытог</span>
            <span class="font-mono">{{ formatPrice(cart.subtotal) }}</span>
          </div>
          <div class="total-row" v-if="cart.discount > 0">
            <span class="text-secondary">Скидка</span>
            <span class="font-mono text-danger">-{{ formatPrice(cart.discount) }}</span>
          </div>
          <div class="total-row grand-total">
            <span>Итого</span>
            <span class="font-mono gradient-text" style="font-size:24px;font-weight:700">
              {{ formatPrice(cart.total) }}
            </span>
          </div>
        </div>

        <Button label="Оплатить" :disabled="cart.itemCount === 0" class="touch-lg pay-btn" icon="pi pi-credit-card"
          @click="showPayment = true" />
      </div>
    </div>

    <!-- Payment Modal -->
    <PaymentModal v-model="showPayment" @paid="handlePayment" />

    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useCartStore } from '../stores/cart.js'
import { useApi } from '../composables/useApi.js'
import { useSessionStore } from '../stores/session.js'
import { useToast } from 'primevue/usetoast'
import PaymentModal from '../components/PaymentModal.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import Tag from 'primevue/tag'
import Toast from 'primevue/toast'
import VirtualScroller from 'primevue/virtualscroller'

const cart = useCartStore()
const api = useApi()
const session = useSessionStore()
const toast = useToast()

const products = ref([])
const categories = ref([])
const searchQuery = ref('')
const selectedCategory = ref(null)
const showPayment = ref(false)
const searchRef = ref(null)
let searchTimeout = null

onMounted(async () => {
  await Promise.all([loadProducts(), loadCategories()])
  searchRef.value?.$el?.focus()
})

async function loadProducts() {
  try {
    const params = new URLSearchParams({ limit: 200 })
    if (searchQuery.value) params.set('search', searchQuery.value)
    if (selectedCategory.value) params.set('category_id', selectedCategory.value)
    const data = await api.get(`/api/products?${params}`)
    products.value = data.data || data
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  }
}

async function loadCategories() {
  try {
    categories.value = await api.get('/api/categories')
  } catch (e) { }
}

function debouncedSearch() {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(loadProducts, 300)
}

async function handleBarcodeEnter() {
  if (!searchQuery.value.trim()) return
  try {
    const product = await api.get(`/api/products/barcode/${encodeURIComponent(searchQuery.value.trim())}`)
    addToCart(product)
    searchQuery.value = ''
    searchRef.value?.$el?.focus()
  } catch (e) {
    // Not a barcode match, use search results
  }
}

function addToCart(product) {
  if (!product.is_active) return
  cart.addItem(product)
  toast.add({ severity: 'success', summary: 'Добавлено', detail: product.name, life: 1000 })
}

async function handlePayment(paymentData) {
  try {
    await api.post('/api/transactions', {
      items: cart.items,
      customer_id: cart.customerId,
      discount: cart.discount,
      tax: 0,
      payment_method: paymentData.method,
      tendered: paymentData.tendered,
      change_given: paymentData.change_given,
      payment_reference: paymentData.reference
    })

    toast.add({ severity: 'success', summary: 'Продажа завершена', detail: `${formatPrice(cart.total)} получено`, life: 3000 })
    cart.clear()
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка продажи', detail: e.message, life: 5000 })
  }
}

function formatPrice(n) {
  return parseFloat(n || 0).toFixed(2)
}

function stockLabel(qty) {
  if (qty < 0) return `Перепродано (${qty})`
  if (qty === 0) return 'Нет в наличии'
  if (qty <= 5) return `Мало (${qty})`
  return `${qty} на складе`
}

function stockClass(qty) {
  if (qty < 0) return 'badge-danger glow'
  if (qty === 0) return 'badge-danger'
  if (qty <= 5) return 'badge-warning'
  return 'badge-success'
}
</script>

<style scoped>
.pos-layout {
  display: flex;
  height: 100%;
  overflow: hidden;
}

.pos-products {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 16px;
  gap: 12px;
  overflow: hidden;
  border-right: 1px solid var(--border-subtle);
}

.pos-search {
  display: flex;
  gap: 8px;
}

.category-tabs {
  display: flex;
  gap: 6px;
  flex-wrap: nowrap;
  overflow-x: auto;
  padding-bottom: 4px;
}

.category-tabs::-webkit-scrollbar {
  height: 3px;
}

.cat-tab {
  padding: 6px 14px;
  border-radius: 20px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.15s;
}

.cat-tab.active,
.cat-tab:hover {
  background: var(--accent-glow);
  color: var(--text-accent);
  border-color: var(--accent-1);
}

.products-area {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  overflow-y: auto;
}

.product-scroller {
  height: 100%;
  width: 100%;
}


.product-card {
  width: 180px;
  min-width: 140px;
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 14px;
  cursor: pointer;
  transition: all 0.15s;
  display: flex;
  flex-direction: column;
  gap: 6px;
  height: 102px;
}

.product-card:hover {
  border-color: rgba(123, 104, 238, 0.5);
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.product-card.out-of-stock {
  opacity: 0.5;
}

.product-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.product-price {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-accent);
}

.product-stock {
  font-size: 11px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 6px;
  align-self: flex-start;
}

.badge-success {
  background: var(--success-bg);
  color: var(--success);
}

.badge-warning {
  background: var(--warning-bg);
  color: var(--warning);
}

.badge-danger {
  background: var(--danger-bg);
  color: var(--danger);
}

.badge-danger.glow {
  animation: pulse-danger 2s infinite;
}

/* Cart */
.pos-cart {
  width: 420px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  background: var(--bg-sidebar);
}

.cart-header {
  padding: 16px;
  border-bottom: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  gap: 8px;
}

.cart-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
  flex: 1;
}

.cart-items {
  flex: 1;
  overflow: hidden;
}

.cart-table {
  height: 100%;
}

.qty-control {
  display: flex;
  align-items: center;
  gap: 6px;
}

.qty-btn {
  width: 32px;
  height: 32px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 8px;
  color: var(--text-primary);
  font-size: 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.qty-btn:hover {
  background: var(--bg-hover);
}

.qty-value {
  width: 28px;
  text-align: center;
  font-size: 14px;
}

.remove-btn {
  width: 28px;
  height: 28px;
  background: var(--danger-bg);
  border: none;
  border-radius: 6px;
  color: var(--danger);
  cursor: pointer;
  font-size: 12px;
}

.cart-footer {
  padding: 16px;
  border-top: 1px solid var(--border-subtle);
}

.cart-totals {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 14px;
}

.total-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 15px;
}

.grand-total {
  padding-top: 10px;
  border-top: 1px solid var(--border-subtle);
  font-weight: 600;
  font-size: 16px;
}

.pay-btn {
  width: 100%;
}

.w-full {
  width: 100%;
}
</style>
