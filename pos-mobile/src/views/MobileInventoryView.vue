<template>
  <div class="inventory-view">
    <!-- Header -->
    <div class="view-header">
      <div class="search-bar">
        <div class="search-wrapper">
          <i class="pi pi-search search-icon" />
          <input
            v-model="search"
            class="search-input"
            placeholder="Поиск или сканирование..."
            @input="debouncedFilter"
          />
          <button v-if="search" class="clear-btn" @click="search = ''; filterProducts()">✕</button>
        </div>
      </div>
    </div>

    <!-- Filter Tabs -->
    <div class="filter-tabs">
      <button
        v-for="tab in tabs"
        :key="tab.value"
        class="filter-tab"
        :class="{ active: activeFilter === tab.value }"
        @click="activeFilter = tab.value; filterProducts()"
      >
        {{ tab.label }}
        <span class="tab-count" v-if="getTabCount(tab.value) > 0">{{ getTabCount(tab.value) }}</span>
      </button>
    </div>

    <!-- Product List -->
    <div
      class="product-list"
      ref="listRef"
      @scroll="handleScroll"
    >
      <div v-if="loading" class="loading-state">
        <i class="pi pi-spin pi-spinner" style="font-size:32px;color:var(--accent-1)" />
      </div>

      <div v-else-if="filteredProducts.length === 0" class="empty-state">
        <i class="pi pi-box" style="font-size:40px;color:var(--text-muted)" />
        <p>Товары не найдены</p>
      </div>

      <MobileProductCard
        v-for="product in filteredProducts"
        :key="product.id"
        :product="product"
        @adjust="openAdjust(product)"
        @print="openPrint(product)"
      />

      <!-- Pull to refresh hint -->
      <div class="list-footer text-muted" style="text-align:center;padding:20px;font-size:12px">
        {{ filteredProducts.length }} товаров
      </div>
    </div>

    <!-- Stock Adjust Sheet -->
    <StockAdjustSheet
      :visible="showAdjust"
      :product="adjustProduct"
      @close="showAdjust = false"
      @confirm="applyAdjustment"
    />

    <!-- Print Sheet -->
    <div v-if="showPrint" class="print-overlay" @click.self="showPrint = false">
      <div class="print-sheet">
        <div class="sheet-handle" />
        <h3 style="text-align:center;margin-bottom:16px">Печать этикетки</h3>
        <div class="print-product-name">{{ printProduct?.name }}</div>
        <svg ref="printSvg" style="width:100%;max-width:300px;display:block;margin:0 auto" />
        <div class="print-controls">
          <div class="copies-row">
            <span class="text-secondary">Копии</span>
            <div style="display:flex;align-items:center;gap:12px">
              <button class="copies-btn" @click="printCopies = Math.max(1, printCopies-1)">−</button>
              <span class="font-mono" style="font-size:20px;width:32px;text-align:center">{{ printCopies }}</span>
              <button class="copies-btn" @click="printCopies = Math.min(20, printCopies+1)">+</button>
            </div>
          </div>
        </div>
        <button class="print-btn" @click="sendPrint">
          <i class="pi pi-print" /> Печать {{ printCopies }} шт.
        </button>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { useWarehouseStore } from '../stores/warehouse.js'
import { useToast } from 'primevue/usetoast'
import MobileProductCard from '../components/MobileProductCard.vue'
import StockAdjustSheet from '../components/StockAdjustSheet.vue'
import JsBarcode from 'jsbarcode'

const store = useWarehouseStore()
const toast = useToast()

const allProducts = ref([])
const loading = ref(false)
const search = ref('')
const activeFilter = ref('all')
const showAdjust = ref(false)
const adjustProduct = ref(null)
const showPrint = ref(false)
const printProduct = ref(null)
const printCopies = ref(1)
const printSvg = ref(null)
const listRef = ref(null)
let filterTimeout = null

const tabs = [
  { label: 'Все', value: 'all' },
  { label: 'Мало', value: 'low' },
  { label: 'Дефицит', value: 'oversold' }
]

const filteredProducts = computed(() => {
  let items = allProducts.value

  // Apply search
  if (search.value) {
    const q = search.value.toLowerCase()
    items = items.filter(p =>
      p.name.toLowerCase().includes(q) ||
      (p.barcode && p.barcode.includes(q))
    )
  }

  // Apply filter
  if (activeFilter.value === 'low') items = items.filter(p => p.stock_qty > 0 && p.stock_qty <= 5)
  else if (activeFilter.value === 'oversold') items = items.filter(p => p.stock_qty < 0)

  return items
})

function getTabCount(filter) {
  if (filter === 'all') return 0
  if (filter === 'low') return allProducts.value.filter(p => p.stock_qty > 0 && p.stock_qty <= 5).length
  if (filter === 'oversold') return allProducts.value.filter(p => p.stock_qty < 0).length
  return 0
}

onMounted(loadProducts)

async function loadProducts() {
  loading.value = true
  try {
    const res = await store.authFetch('/api/inventory/mobile')
    allProducts.value = await res.json()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

function debouncedFilter() {
  clearTimeout(filterTimeout)
  filterTimeout = setTimeout(filterProducts, 300)
}

function filterProducts() {
  // Reactive computed handles this; just trigger if needed
}

function handleScroll() {
  // Pull-to-refresh simulation
  if (listRef.value?.scrollTop === 0) {
    loadProducts()
  }
}

function openAdjust(product) {
  adjustProduct.value = product
  showAdjust.value = true
}

async function applyAdjustment({ delta, reason }) {
  try {
    const res = await store.authFetch(`/api/products/${adjustProduct.value.id}/stock`, {
      method: 'PATCH',
      body: JSON.stringify({ delta, reason })
    })
    if (!res.ok) { const d = await res.json(); throw new Error(d.error) }

    // Update local
    const product = allProducts.value.find(p => p.id === adjustProduct.value.id)
    if (product) product.stock_qty += delta

    toast.add({ severity: 'success', summary: 'Остаток скорректирован', detail: `${delta > 0 ? '+' : ''}${delta}`, life: 2000 })
    showAdjust.value = false
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  }
}

function openPrint(product) {
  printProduct.value = product
  printCopies.value = 1
  showPrint.value = true
  nextTick(() => {
    if (printSvg.value && product.barcode) {
      JsBarcode(printSvg.value, product.barcode, {
        format: 'CODE128', width: 2, height: 48,
        displayValue: true, fontSize: 11,
        lineColor: '#111', background: '#fff'
      })
    }
  })
}

async function sendPrint() {
  try {
    const res = await store.authFetch('/api/barcode/print', {
      method: 'POST',
      body: JSON.stringify({
        product_id: printProduct.value.id,
        barcode: printProduct.value.barcode,
        product_name: printProduct.value.name,
        price: printProduct.value.price,
        copies: printCopies.value,
        size: '58mm'
      })
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data.error)
    toast.add({ severity: 'success', summary: 'Печать отправлена', life: 2000 })
    showPrint.value = false
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка печати', detail: e.message, life: 3000 })
  }
}
</script>

<style scoped>
.inventory-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.view-header { padding: 12px 16px 0; flex-shrink: 0; }

.search-bar { margin-bottom: 8px; }

.search-wrapper {
  display: flex;
  align-items: center;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  height: 56px;
  padding: 0 16px;
  gap: 10px;
}

.search-icon { color: var(--text-muted); }

.search-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-primary);
  font-size: 16px;
  font-family: var(--font-sans);
}

.clear-btn {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 16px;
}

.filter-tabs {
  display: flex;
  gap: 8px;
  padding: 8px 16px;
  overflow-x: auto;
  flex-shrink: 0;
}

.filter-tab {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: 20px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}

.filter-tab.active {
  background: var(--accent-glow);
  color: var(--text-accent);
  border-color: var(--accent-1);
}

.tab-count {
  background: var(--danger-bg);
  color: var(--danger);
  border-radius: 10px;
  padding: 2px 6px;
  font-size: 11px;
}

.product-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px 16px 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  -webkit-overflow-scrolling: touch;
}

.loading-state, .empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 60px 20px;
  color: var(--text-muted);
  font-size: 15px;
}

/* Print Sheet */
.print-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
}

.print-sheet {
  width: 100%;
  background: var(--bg-elevated);
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  padding: 0 20px calc(24px + env(safe-area-inset-bottom));
}

.sheet-handle {
  width: 40px; height: 4px;
  background: var(--border-default);
  border-radius: 2px;
  margin: 12px auto 20px;
}

.print-product-name {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  text-align: center;
  margin-bottom: 16px;
}

.print-controls { padding: 16px 0; }

.copies-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.copies-btn {
  width: 44px; height: 44px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  color: var(--text-primary);
  font-size: 20px;
  cursor: pointer;
}

.print-btn {
  width: 100%;
  height: 60px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 14px;
  color: #fff;
  font-size: 17px;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 12px;
}
</style>
