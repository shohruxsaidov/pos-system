<template>
  <div class="pos-layout">
    <!-- Left: Product Grid -->
    <div class="pos-products">
      <!-- Search Bar -->
      <div class="pos-search">
        <Button icon="pi pi-arrow-left" class="p-button-secondary" @click="router.push('/')"
          style="height:56px;width:56px" v-tooltip="'Склад'" />
        <IconField style="flex:1">
          <InputIcon class="pi pi-barcode" />
          <InputText ref="searchRef" v-model="searchQuery" placeholder="Сканировать штрихкод или найти товар..."
            class="w-full" @keydown.enter="handleBarcodeEnter" @input="debouncedSearch" @dblclick="openKeyboard"
            inputmode="none" />
          <InputIcon v-if="searchQuery" class="pi pi-times search-clear" @click="clearSearch" v-tooltip="'Очистить'" />
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
          <div class="product-name" v-html="highlight(item.name)" v-tooltip.top="item.name" />
          <div class="product-price font-mono">{{ formatPrice(item.price) }}</div>
          <div class="product-stock" :class="stockClass(item.stock_qty)">
            {{ stockLabel(item.stock_qty) }}
          </div>
        </div>
      </div>

    </div>

    <!-- Resize handle -->
    <div class="cart-resizer" :class="{ dragging: isResizing }" @mousedown="startResize" @dblclick="resetCartWidth"
      title="Перетащите, чтобы изменить ширину (двойной клик — сброс)" />

    <!-- Right: Cart -->
    <div class="pos-cart" :style="{ width: cartWidth + 'px' }">
      <!-- Session tabs -->
      <div class="session-tabs">
        <div v-for="s in cart.sessions" :key="s.id"
          :class="['session-tab', { 'session-tab--active': s.id === cart.activeId }]" @click="cart.switchSession(s.id)">
          <span class="session-label">{{ s.label }}</span>
          <span v-if="s.items.length" class="session-badge">{{Math.floor(s.items.reduce((sum, i) => sum + i.qty, 0))
          }}</span>
          <button class="session-close" @click.stop="cart.closeSession(s.id)"
            :title="s.items.length ? 'Закрыть (товары будут удалены)' : 'Закрыть'">✕</button>
        </div>
        <button v-if="cart.sessions.length < 8" class="session-new" @click="cart.newSession()" title="Новый клиент">+
          Новый</button>
      </div>

      <!-- Cart Items -->
      <div class="cart-items">
        <DataTable :value="cart.items" scrollable scroll-height="flex" class="cart-table">
          <Column field="name" header="Товар">
            <template #body="{ data }">
              <span class="cart-product-name">{{ data.name }}</span>
            </template>
          </Column>
          <Column field="unit_price" header="Цена" style="width:90px">
            <template #body="{ data }">
              <button class="qty-value font-mono qty-value-btn" @click="openPriceEdit(data)">{{
                formatPrice(data.unit_price) }}</button>
            </template>
          </Column>
          <Column header="Кол-во" style="width:120px">
            <template #body="{ data }">
              <div class="qty-control">
                <button class="qty-btn" @click="cart.updateQty(data.product_id, data.qty - 1)">−</button>
                <button class="qty-value font-mono qty-value-btn" @click="openQtyEdit(data)">{{ formatQty(data.qty)
                }}</button>
                <button class="qty-btn" @click="cart.updateQty(data.product_id, data.qty + 1)">+</button>
              </div>
            </template>
          </Column>
          <Column style="width:90px">
            <template #header>
              Итого
              <Button v-if="cart.itemCount > 0" class="p-button-danger" style="height: auto !important; "
                @click="cart.clear()" v-tooltip="'Очистить корзину'">
                {{ cart.itemCount }}
              </Button>
            </template>
            <template #body="{ data }">
              <span class="font-mono cart-line-total">{{ formatPrice(lineTotal(data)) }}</span>
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

    <!-- Cart Amount → Qty Dialog -->
    <Dialog v-model:visible="showPriceDialog" modal header="Ввести сумму" :style="{ width: '320px' }">
      <div style="display:flex;flex-direction:column;gap:12px">
        <div style="text-align:center;font-size:13px;color:var(--text-secondary);font-weight:600">
          {{ editingCartItem?.name }} · {{ formatPrice(editingCartItem?.unit_price) }} за ед.
        </div>
        <NumPad v-model="editPrice" :show-display="true" />
        <div style="text-align:center;font-size:13px;color:var(--text-muted)">
          Кол-во: <span class="font-mono" style="color:var(--text-accent)">{{ computedQtyFromAmount }}</span>
          · К оплате: <span class="font-mono" style="color:var(--text-accent)">{{ formatPrice(enteredAmount) }}</span>
        </div>
      </div>
      <template #footer>
        <Button label="Отмена" class="p-button-secondary" @click="showPriceDialog = false" style="height:56px" />
        <Button label="Применить" icon="pi pi-check" @click="confirmPriceEdit"
          style="height:56px;flex:1;background:var(--gradient-hero);border:none" />
      </template>
    </Dialog>

    <!-- Cart Qty Edit Dialog -->
    <Dialog v-model:visible="showQtyDialog" modal header="Изменить количество" :style="{ width: '320px' }">
      <div style="display:flex;flex-direction:column;gap:12px">
        <div style="text-align:center;font-size:13px;color:var(--text-secondary);font-weight:600">
          {{ editingCartItem?.name }}
        </div>
        <NumPad v-model="editQty" :show-display="true" />
      </div>
      <template #footer>
        <Button label="Отмена" class="p-button-secondary" @click="showQtyDialog = false" style="height:56px" />
        <Button label="Применить" icon="pi pi-check" @click="confirmQtyEdit"
          style="height:56px;flex:1;background:var(--gradient-hero);border:none" />
      </template>
    </Dialog>

    <!-- Payment Modal -->
    <PaymentModal v-model="showPayment" @paid="handlePayment" />

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useCartStore } from '../stores/cart.js'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import { useVirtualKeyboard } from '../composables/useVirtualKeyboard.js'
import { lineTotal, roundMoney } from '../utils/money.js'
import PaymentModal from '../components/PaymentModal.vue'
import NumPad from '../components/NumPad.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import Tag from 'primevue/tag'
import Toast from 'primevue/toast'
import Dialog from 'primevue/dialog'
const router = useRouter()
const cart = useCartStore()
const api = useApi()
const toast = useToast()
const { show: showKeyboard, hide: hideKeyboard } = useVirtualKeyboard()

function openKeyboard() {
  const el = searchRef.value?.$el
  if (el) {
    showKeyboard(el)
    el.focus()
  }
}

// Resizable cart width (persisted)
const DEFAULT_CART_WIDTH = 700
const MIN_CART_WIDTH = 360
const MAX_CART_WIDTH = 1100
const cartWidth = ref(parseInt(localStorage.getItem('pos-cart-width')) || DEFAULT_CART_WIDTH)
const isResizing = ref(false)

function startResize(e) {
  e.preventDefault()
  isResizing.value = true
  const startX = e.clientX
  const startWidth = cartWidth.value

  const onMove = (ev) => {
    // Cart is on the right, so dragging left widens it
    const delta = startX - ev.clientX
    cartWidth.value = Math.min(MAX_CART_WIDTH, Math.max(MIN_CART_WIDTH, startWidth + delta))
  }
  const onUp = () => {
    isResizing.value = false
    localStorage.setItem('pos-cart-width', String(cartWidth.value))
    window.removeEventListener('mousemove', onMove)
    window.removeEventListener('mouseup', onUp)
  }
  window.addEventListener('mousemove', onMove)
  window.addEventListener('mouseup', onUp)
}

function resetCartWidth() {
  cartWidth.value = DEFAULT_CART_WIDTH
  localStorage.setItem('pos-cart-width', String(cartWidth.value))
}

const products = ref([])
const categories = ref([])
const searchQuery = ref('')
const selectedCategory = ref(null)
const showPayment = ref(false)
const searchRef = ref(null)
let searchTimeout = null

// Cart qty + price edit dialogs
const showQtyDialog = ref(false)
const showPriceDialog = ref(false)
const editingCartItem = ref(null)
const editQty = ref('1')
const editPrice = ref('0')

function openQtyEdit(item) {
  editingCartItem.value = item
  editQty.value = String(item.qty)
  showQtyDialog.value = true
}

function confirmQtyEdit() {
  const qty = parseFloat(editQty.value) || 1
  cart.updateQty(editingCartItem.value.product_id, qty)
  showQtyDialog.value = false
}

// The entered sum is what gets charged; qty is whatever weight that buys.
// It is shown trimmed to 4 decimals but applied at full precision — rounding
// 4 000 / 75 000 to 0.05 would charge 3 750 instead.
const enteredAmount = computed(() => roundMoney(parseFloat(editPrice.value) || 0))

const computedQtyFromAmount = computed(() => {
  const price = editingCartItem.value?.unit_price || 0
  if (price <= 0 || enteredAmount.value <= 0) return '0'
  return formatQty(enteredAmount.value / price)
})

function openPriceEdit(item) {
  editingCartItem.value = item
  editPrice.value = ''
  showPriceDialog.value = true
}

function confirmPriceEdit() {
  cart.setLineAmount(editingCartItem.value.product_id, enteredAmount.value)
  showPriceDialog.value = false
}


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

function clearSearch() {
  searchQuery.value = ''
  loadProducts()
  searchRef.value?.$el?.focus()
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
  hideKeyboard()
  cart.addItem(product)
  searchQuery.value = ''
}

async function handlePayment(paymentData) {
  try {
    await api.post('/api/transactions', {
      items: cart.items,
      customer_id: cart.customerId,
      discount: cart.discount,
      tax: 0,
      payments: paymentData.payments,
      print_receipt: paymentData.printReceipt
    })

    toast.add({ severity: 'success', summary: 'Продажа завершена', detail: `${formatPrice(cart.total)} получено`, life: 3000 })
    cart.clear()
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка продажи', detail: e.message, life: 5000 })
  }
}

function highlight(text) {
  if (!searchQuery.value || !text) return text
  const escaped = searchQuery.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return String(text).replace(new RegExp(`(${escaped})`, 'gi'), '<mark class="search-highlight">$1</mark>')
}

function formatPrice(n) {
  const [int, dec] = parseFloat(n || 0).toFixed(2).split('.')
  return int.replace(/\B(?=(\d{3})+(?!\d))/g, '\u00A0') + '.' + dec
}

// Quantities derived from an entered sum are long fractions (4 000 / 75 000 =
// 0.0533…) — show at most 4 decimals, without trailing zeros.
function formatQty(n) {
  const q = Number(n) || 0
  return String(parseFloat(q.toFixed(4)))
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

:deep(.search-clear) {
  pointer-events: auto;
  cursor: pointer;
  color: var(--text-secondary);
  transition: color 0.15s;
}

:deep(.search-clear:hover) {
  color: var(--text-primary);
}

.category-tabs {
  display: flex;
  gap: 6px;
  flex-wrap: nowrap;
  overflow-x: auto;
  padding-bottom: 4px;
  min-height: 34px;
  scrollbar-width: none;
  /* Firefox */
}

.category-tabs::-webkit-scrollbar {
  display: none;
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
  width: 155px;
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
  height: 34px;
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

/* Resize handle between products and cart */
.cart-resizer {
  width: 6px;
  flex-shrink: 0;
  cursor: col-resize;
  background: var(--border-subtle);
  transition: background 0.15s;
}

.cart-resizer:hover,
.cart-resizer.dragging {
  background: var(--accent-1);
}

/* Cart */
.pos-cart {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  background: var(--bg-sidebar);
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

.cart-product-name {
  font-weight: 700;
  color: var(--text-primary);
  font-size: 20px;
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

.cart-line-total {
  font-size: 18px;
  font-weight: 700;
}

.qty-value {
  max-width: 120px;
  text-align: center;
  font-size: 18px;
  font-weight: 700;
  overflow-x: auto;
  scrollbar-width: none;
  /* Firefox */
}

.qty-value::-webkit-scrollbar {
  display: none;
}

.qty-value-btn {
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 6px;
  color: var(--text-primary);
  cursor: pointer;
  padding: 6px 8px;
  transition: all 0.12s;
}

.qty-value-btn:hover {
  border-color: var(--accent-1);
  background: var(--accent-glow);
  color: var(--text-accent);
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

:deep(.search-highlight) {
  background: rgba(255, 214, 0, 0.30);
  color: #ffd600;
  border-radius: 3px;
  padding: 0 2px;
  font-weight: 700;
}

/* Session tabs */
.session-tabs {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 8px 10px 0;
  background: var(--bg-sidebar);
  border-bottom: 1px solid var(--border-subtle);
  overflow-x: auto;
  scrollbar-width: none;
  flex-shrink: 0;
}

.session-tabs::-webkit-scrollbar {
  display: none;
}

.session-tab {
  display: flex;
  align-items: center;
  gap: 5px;
  height: 40px;
  padding: 0 10px;
  border-radius: 8px 8px 0 0;
  background: var(--bg-input);
  border: 1px solid var(--border-subtle);
  border-bottom: none;
  cursor: pointer;
  font-size: 12px;
  color: var(--text-secondary);
  white-space: nowrap;
  transition: all 0.12s;
  user-select: none;
  flex-shrink: 0;
}

.session-tab:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.session-tab--active {
  background: var(--bg-surface);
  border-color: var(--border-default);
  color: var(--text-primary);
  font-weight: 600;
  position: relative;
}

.session-tab--active::after {
  content: '';
  position: absolute;
  bottom: -1px;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--gradient-accent);
  border-radius: 2px 2px 0 0;
}

.session-label {
  max-width: 80px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.session-badge {
  background: var(--accent-glow);
  color: var(--text-accent);
  border-radius: 10px;
  padding: 1px 6px;
  font-size: 11px;
  font-weight: 700;
}

.session-close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 17px;
  padding: 0;
  line-height: 1;
  border-radius: 6px;
  transition: all 0.1s;
}

.session-close:hover {
  background: var(--danger-bg);
  color: var(--danger);
}

.session-new {
  background: none;
  border: 1px dashed var(--border-default);
  border-radius: 8px 8px 0 0;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  padding: 8px 18px;
  white-space: nowrap;
  flex-shrink: 0;
  transition: all 0.12s;
  margin-bottom: 0;
}

.session-new:hover {
  border-color: var(--accent-1);
  color: var(--text-accent);
  background: var(--accent-glow);
}
</style>
