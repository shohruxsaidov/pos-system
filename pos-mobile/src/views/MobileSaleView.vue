<template>
  <div class="sale-view">

    <!-- Header -->
    <div class="sale-header">
      <div class="header-info">
        <span class="header-cashier">{{ store.user?.name }}</span>
        <span class="header-role">Касса</span>
      </div>
      <div class="header-actions">
        <button class="logout-btn" @click="logout">
          <i class="pi pi-sign-out" />
        </button>
        <button class="cart-fab" :class="{ 'has-items': cartCount > 0 }" @click="showCart = true">
          <i class="pi pi-shopping-cart" />
          <span v-if="cartCount > 0" class="cart-badge">{{ cartCount }}</span>
        </button>
      </div>
    </div>

    <!-- Search bar -->
    <div class="search-wrap">
      <div class="search-field">
        <i class="pi pi-search search-icon" />
        <input
          ref="searchRef"
          v-model="search"
          class="search-input"
          placeholder="Поиск или штрихкод..."
          inputmode="text"
          autocomplete="off"
          @keydown.enter="handleScanEnter"
        />
        <button v-if="search" class="search-clear" @click="clearSearch">
          <i class="pi pi-times" />
        </button>
      </div>
    </div>

    <!-- Product area -->
    <div class="products-area">

      <div v-if="loading" class="state-center">
        <i class="pi pi-spin pi-spinner" style="font-size: 36px; color: var(--text-muted)" />
      </div>

      <div v-else-if="filteredProducts.length === 0 && search" class="state-center">
        <i class="pi pi-search" style="font-size: 40px; color: var(--text-muted)" />
        <p class="state-text">Ничего не найдено</p>
        <p class="state-hint">«{{ search }}»</p>
      </div>

      <div v-else-if="filteredProducts.length === 0" class="state-center">
        <i class="pi pi-box" style="font-size: 40px; color: var(--text-muted)" />
        <p class="state-text">Нет товаров</p>
      </div>

      <div v-else class="products-grid">
        <button
          v-for="p in filteredProducts"
          :key="p.id"
          class="product-card"
          @click="addToCart(p)"
        >
          <div class="product-name">{{ p.name }}</div>
          <div class="product-price font-mono">{{ Number(p.price).toFixed(2) }}</div>
          <div class="product-footer">
            <span class="stock-badge" :class="stockClass(p.stock_qty)">
              {{ stockLabel(p.stock_qty) }}
            </span>
            <span class="add-icon">+</span>
          </div>
          <!-- Cart quantity overlay -->
          <div v-if="cartQty(p.id) > 0" class="in-cart-badge">{{ cartQty(p.id) }}</div>
        </button>
      </div>

    </div>

    <!-- Sticky cart bar (when cart has items) -->
    <div v-if="cartCount > 0 && !showCart" class="cart-bar" @click="showCart = true">
      <span class="cart-bar-count">{{ cartCount }} товар{{ cartCountSuffix }}</span>
      <span class="cart-bar-total font-mono">{{ cartTotal.toFixed(2) }}</span>
      <span class="cart-bar-action">Корзина <i class="pi pi-angle-up" /></span>
    </div>

    <!-- Cart Sheet -->
    <CartSheet
      v-model:visible="showCart"
      :items="cart"
      @change-qty="changeQty"
      @remove="removeFromCart"
      @checkout="openPayment"
    />

    <!-- Payment Sheet -->
    <PaymentSheet
      v-if="showPayment"
      :total="cartTotal"
      :processing="processing"
      @confirm="processSale"
      @close="showPayment = false"
    />

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { useWarehouseStore } from '../stores/warehouse.js'
import { loadProductsCache } from '../composables/useOfflineQueue.js'
import CartSheet from '../components/CartSheet.vue'
import PaymentSheet from '../components/PaymentSheet.vue'

const store = useWarehouseStore()
const toast = useToast()
const router = useRouter()

function logout() {
  store.logout()
  router.push({ name: 'login' })
}

const allProducts = ref([])
const loading = ref(true)
const search = ref('')
const searchRef = ref(null)
const cart = ref([])
const showCart = ref(false)
const showPayment = ref(false)
const processing = ref(false)

// ── Products ──────────────────────────────────────────────
onMounted(async () => {
  // Show cached products instantly — no spinner if cache exists
  const cached = loadProductsCache()
  if (cached) {
    allProducts.value = cached
    loading.value = false
  }
  try {
    await store.fetchProducts()
    allProducts.value = store.products
  } catch {
    if (!cached) {
      toast.add({ severity: 'error', summary: 'Ошибка', detail: 'Не удалось загрузить товары', life: 3000 })
    }
  } finally {
    loading.value = false
  }
})

const filteredProducts = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return allProducts.value
  return allProducts.value.filter(p =>
    p.name.toLowerCase().includes(q) ||
    (p.barcode && p.barcode.toLowerCase().includes(q))
  )
})

function stockClass(qty) {
  if (qty < 0) return 'stock-danger'
  if (qty === 0) return 'stock-danger'
  if (qty <= 5) return 'stock-warn'
  return 'stock-ok'
}

function stockLabel(qty) {
  if (qty < 0) return `−${Math.abs(qty)}`
  if (qty === 0) return 'Нет'
  if (qty <= 5) return `Мало: ${qty}`
  return `${qty} шт`
}

// ── Barcode scan (Enter key) ───────────────────────────────
async function handleScanEnter() {
  const q = search.value.trim()
  if (!q) return

  // Exact barcode match → add to cart instantly
  const match = allProducts.value.find(p => p.barcode === q)
  if (match) {
    addToCart(match)
    search.value = ''
    return
  }

  // Otherwise just search by name
}

function clearSearch() {
  search.value = ''
  searchRef.value?.focus()
}

// ── Cart ──────────────────────────────────────────────────
function addToCart(product) {
  const existing = cart.value.find(i => i.product_id === product.id)
  if (existing) {
    existing.qty++
  } else {
    cart.value.push({
      product_id: product.id,
      name: product.name,
      unit_price: Number(product.price),
      qty: 1,
      unit: product.unit || 'шт'
    })
  }
}

function changeQty(idx, delta) {
  const item = cart.value[idx]
  if (!item) return
  const newQty = item.qty + delta
  if (newQty < 1) {
    cart.value.splice(idx, 1)
  } else {
    item.qty = newQty
  }
}

function removeFromCart(idx) {
  cart.value.splice(idx, 1)
}

function cartQty(productId) {
  return cart.value.find(i => i.product_id === productId)?.qty || 0
}

const cartTotal = computed(() => cart.value.reduce((sum, i) => sum + i.unit_price * i.qty, 0))
const cartCount = computed(() => cart.value.reduce((sum, i) => sum + i.qty, 0))

const cartCountSuffix = computed(() => {
  const n = cartCount.value % 10
  if (n === 1 && cartCount.value % 100 !== 11) return ''
  if (n >= 2 && n <= 4 && (cartCount.value % 100 < 10 || cartCount.value % 100 >= 20)) return 'а'
  return 'ов'
})

// ── Payment ───────────────────────────────────────────────
function openPayment() {
  showCart.value = false
  showPayment.value = true
}

async function processSale({ method, tendered, changeGiven }) {
  if (processing.value) return
  processing.value = true

  try {
    const result = await store.submitSale({
      items: cart.value.map(i => ({
        product_id: i.product_id,
        qty: i.qty,
        unit_price: i.unit_price,
        discount: 0
      })),
      payment_method: method,
      tendered,
      change_given: changeGiven,
      total: cartTotal.value
    })

    // Sync local display stock (already patched in store, refresh from store)
    allProducts.value = store.products.length ? store.products : allProducts.value

    cart.value = []
    showPayment.value = false

    if (result.offline) {
      toast.add({
        severity: 'warn',
        summary: 'Сохранено офлайн',
        detail: `${store.queueLength} в очереди`,
        life: 4000
      })
    } else {
      toast.add({
        severity: 'success',
        summary: `Продажа ${result.data.ref_no}`,
        detail: `Сумма: ${Number(result.data.total ?? cartTotal.value).toFixed(2)}`,
        life: 4000
      })
    }
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 4000 })
  } finally {
    processing.value = false
  }
}
</script>

<style scoped>
.sale-view {
  height: 100%;
  position: relative;
  display: flex;
  flex-direction: column;
  background: var(--bg-base);
  overflow: hidden;
}

/* Header */
.sale-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px 10px;
  background: var(--bg-sidebar);
  border-bottom: 1px solid var(--border-subtle);
  flex-shrink: 0;
}

.header-info { display: flex; flex-direction: column; gap: 2px; }

.header-cashier {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

.header-role {
  font-size: 11px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.logout-btn {
  width: 48px; height: 48px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  color: var(--text-muted);
  font-size: 18px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
  -webkit-tap-highlight-color: transparent;
}

.logout-btn:active {
  background: var(--danger-bg);
  border-color: var(--danger);
  color: var(--danger);
}

.cart-fab {
  position: relative;
  width: 48px; height: 48px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  color: var(--text-secondary);
  font-size: 20px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
  -webkit-tap-highlight-color: transparent;
}

.cart-fab.has-items {
  background: rgba(123,104,238,0.15);
  border-color: var(--accent-1);
  color: var(--accent-1);
}

.cart-badge {
  position: absolute;
  top: -6px; right: -6px;
  min-width: 20px; height: 20px;
  background: var(--gradient-hero);
  border-radius: 10px;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
}

/* Search */
.search-wrap {
  padding: 12px 16px;
  flex-shrink: 0;
}

.search-field {
  display: flex;
  align-items: center;
  gap: 0;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  padding: 0 14px;
  height: 52px;
}

.search-field:focus-within {
  border-color: var(--border-focus);
}

.search-icon { color: var(--text-muted); font-size: 16px; flex-shrink: 0; }

.search-input {
  flex: 1;
  background: none;
  border: none;
  outline: none;
  color: var(--text-primary);
  font-size: 16px;
  padding: 0 10px;
  font-family: var(--font-sans);
}

.search-input::placeholder { color: var(--text-muted); }

.search-clear {
  background: none;
  border: none;
  color: var(--text-muted);
  font-size: 14px;
  cursor: pointer;
  padding: 4px;
}

/* Products */
.products-area {
  flex: 1;
  overflow-y: auto;
  padding: 4px 16px;
  padding-bottom: 8px;
}

.state-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  gap: 8px;
}

.state-text { font-size: 16px; color: var(--text-muted); }
.state-hint { font-size: 13px; color: var(--text-muted); opacity: 0.6; }

.products-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
  padding-bottom: 80px;
}

.product-card {
  position: relative;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 14px 12px;
  cursor: pointer;
  text-align: left;
  display: flex;
  flex-direction: column;
  gap: 6px;
  -webkit-tap-highlight-color: transparent;
  transition: all 0.15s;
}

.product-card:active {
  transform: scale(0.97);
  border-color: var(--accent-1);
  background: var(--bg-hover);
}

.product-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.product-price {
  font-size: 17px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.product-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 2px;
}

.stock-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 7px;
  border-radius: 6px;
}

.stock-ok { background: var(--success-bg); color: var(--success); }
.stock-warn { background: var(--warning-bg); color: var(--warning); }
.stock-danger { background: var(--danger-bg); color: var(--danger); }

.add-icon {
  width: 24px; height: 24px;
  background: rgba(123,104,238,0.15);
  border-radius: 8px;
  color: var(--accent-1);
  font-size: 18px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}

/* In-cart badge */
.in-cart-badge {
  position: absolute;
  top: -6px; right: -6px;
  min-width: 22px; height: 22px;
  background: var(--gradient-hero);
  border-radius: 11px;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 5px;
  box-shadow: 0 2px 8px rgba(123,104,238,0.4);
}

/* Cart bar */
.cart-bar {
  position: absolute;
  bottom: calc(70px + env(safe-area-inset-bottom));
  left: 12px; right: 12px;
  height: 56px;
  background: var(--gradient-hero);
  border-radius: 16px;
  display: flex;
  align-items: center;
  padding: 0 18px;
  cursor: pointer;
  box-shadow: 0 4px 20px rgba(123,104,238,0.4);
  -webkit-tap-highlight-color: transparent;
}

.cart-bar-count {
  font-size: 14px;
  font-weight: 700;
  color: rgba(255,255,255,0.85);
  flex: 1;
}

.cart-bar-total {
  font-size: 18px;
  font-weight: 800;
  color: #fff;
  flex: 1;
  text-align: center;
}

.cart-bar-action {
  font-size: 13px;
  font-weight: 600;
  color: rgba(255,255,255,0.85);
  display: flex;
  align-items: center;
  gap: 4px;
  flex: 1;
  justify-content: flex-end;
}
</style>
