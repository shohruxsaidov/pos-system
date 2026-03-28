<template>
  <div class="inventory-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Склад</h1>
        <p class="view-subtitle">{{ totalProducts }} товаров</p>
      </div>
      <div class="header-actions">
        <div class="search-wrapper">
          <i class="pi pi-search search-icon" />
          <input
            v-model="search"
            class="search-input"
            placeholder="Поиск или штрихкод..."
            @input="debouncedSearch"
          />
          <button v-if="search" class="clear-btn" @click="search = ''; loadProducts()">✕</button>
        </div>
        <Select v-model="categoryFilter" :options="[{ id: null, name: 'Все категории' }, ...categories]"
          option-label="name" option-value="id" style="width:180px" @change="loadProducts" />
        <Button v-if="canManage" label="Добавить товар" icon="pi pi-plus" @click="openCreate" />
      </div>
    </div>

    <!-- Filter Tabs -->
    <div class="filter-tabs">
      <button
        v-for="tab in tabs"
        :key="tab.value"
        class="filter-tab"
        :class="{ active: activeFilter === tab.value }"
        @click="activeFilter = tab.value"
      >
        {{ tab.label }}
        <span class="tab-count" v-if="getTabCount(tab.value) > 0">{{ getTabCount(tab.value) }}</span>
      </button>
    </div>

    <!-- Stats Bar -->
    <div class="stats-bar">
      <div class="stat-item">
        <span class="stat-value">{{ filteredProducts.length }}</span>
        <span class="stat-label">Товаров</span>
      </div>
      <div class="stat-divider" />
      <div class="stat-item">
        <span class="stat-value font-mono">{{ formatCompact(totalValue) }}</span>
        <span class="stat-label">Общая стоимость</span>
      </div>
      <div class="stat-divider" />
      <div class="stat-item">
        <span class="stat-value" style="color:var(--danger)">{{ oversoldCount }}</span>
        <span class="stat-label">Дефицит</span>
      </div>
      <div class="stat-divider" />
      <div class="stat-item">
        <span class="stat-value" style="color:var(--warning)">{{ lowCount }}</span>
        <span class="stat-label">Мало</span>
      </div>
    </div>

    <!-- Product Cards Grid -->
    <div class="cards-container">
      <div v-if="loading" class="loading-state">
        <i class="pi pi-spin pi-spinner" style="font-size:2.5rem;color:var(--accent-1)" />
      </div>

      <div v-else-if="filteredProducts.length === 0" class="empty-state">
        <i class="pi pi-box" style="font-size:48px;color:var(--text-muted)" />
        <p>Товары не найдены</p>
      </div>

      <div v-else class="cards-grid">
        <div
          v-for="product in filteredProducts"
          :key="product.id"
          class="product-card"
        >
          <div class="card-main">
            <div class="product-info">
              <div class="product-name" v-html="highlight(product.name)" />
              <div class="product-barcode font-mono" v-html="highlight(product.barcode || '—')" />
              <div class="product-category text-muted">{{ product.category_name || 'Без категории' }}</div>
            </div>
            <div class="card-right">
              <div class="product-price font-mono">{{ formatPrice(product.price) }}</div>
              <div class="product-cost font-mono text-muted">Себ: {{ formatPrice(product.cost) }}</div>
              <div :class="['stock-badge', stockBadgeClass(product.stock_qty, product.low_stock_threshold)]">
                {{ stockLabel(product.stock_qty, product.low_stock_threshold) }}
              </div>
            </div>
          </div>

          <div class="card-actions">
            <button v-if="canManage" class="action-btn" @click="openEdit(product)" title="Редактировать">
              <i class="pi pi-pencil" />
            </button>
            <button v-if="canManage" class="action-btn" @click="openStockAdjust(product)" title="Коррект. склада">
              <i class="pi pi-chart-line" />
            </button>
            <button class="action-btn" @click="generateBarcode(product)" title="Штрихкод">
              <i class="pi pi-barcode" />
            </button>
            <button class="action-btn" @click="openPrintLabel(product)" title="Печать этикетки">
              <i class="pi pi-print" />
            </button>
            <button v-if="canManage" class="action-btn danger-btn" @click="deleteProduct(product)" title="Удалить">
              <i class="pi pi-trash" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Drawer -->
    <Drawer v-model:visible="showDrawer" :header="editingProduct ? 'Редактировать товар' : 'Новый товар'"
      position="right" style="width:480px">
      <div class="drawer-form">
        <div class="field-group">
          <label class="field-label">Название товара *</label>
          <InputText v-model="form.name" class="w-full" placeholder="Название товара" />
        </div>
        <div class="field-group">
          <label class="field-label">Штрихкоды</label>
          <div class="barcodes-list">
            <div v-for="(bc, idx) in form.barcodes" :key="idx" class="barcode-entry">
              <button
                class="primary-star"
                :class="{ active: bc.is_primary }"
                @click="setPrimaryBarcode(idx)"
                type="button"
                title="Сделать основным"
              >★</button>
              <InputText v-model="bc.barcode" class="flex-1" placeholder="Сканировать или ввести" style="font-family:var(--font-mono);font-size:13px" />
              <button class="bc-remove-btn" @click="form.barcodes.splice(idx, 1)" type="button" title="Удалить">
                <i class="pi pi-times" />
              </button>
            </div>
            <div class="barcode-add-row">
              <button class="add-barcode-btn" type="button" @click="addBarcodeField">
                <i class="pi pi-plus" /> Добавить
              </button>
              <button class="add-barcode-btn" type="button" @click="generateBarcodeInForm">
                <i class="pi pi-refresh" /> Сгенерировать
              </button>
            </div>
          </div>
        </div>
        <div class="field-row">
          <div class="field-group">
            <label class="field-label">Цена *</label>
            <InputText v-model="form.price" type="number" class="w-full" placeholder="0.00" />
          </div>
          <div class="field-group">
            <label class="field-label">Себестоимость</label>
            <InputText v-model="form.cost" type="number" class="w-full" placeholder="0.00" />
          </div>
        </div>
        <div class="field-row">
          <div class="field-group">
            <label class="field-label">Кол-во на складе</label>
            <InputText v-model="form.stock_qty" type="number" class="w-full" placeholder="0" />
          </div>
          <div class="field-group">
            <label class="field-label">Единица</label>
            <div class="unit-chips">
              <button v-for="u in UNITS" :key="u" class="unit-chip" :class="{ active: form.unit === u }" type="button"
                @click="form.unit = u">{{ u }}</button>
            </div>
          </div>
        </div>
        <div class="field-group">
          <label class="field-label">Категория</label>
          <Select v-model="form.category_id" :options="categories" option-label="name" option-value="id"
            placeholder="Выбрать категорию" class="w-full" />
        </div>
        <div class="field-group">
          <label class="field-label">Порог низкого запаса</label>
          <InputText v-model="form.low_stock_threshold" type="number" style="width:120px" placeholder="5" />
        </div>
      </div>

      <template #footer>
        <div class="drawer-footer">
          <Button label="Отмена" class="p-button-secondary" @click="showDrawer = false" />
          <Button :label="editingProduct ? 'Сохранить изменения' : 'Создать товар'" :loading="saving"
            @click="saveProduct" style="flex:1" />
        </div>
      </template>
    </Drawer>

    <!-- Stock Adjust Dialog -->
    <Dialog v-model:visible="showStockAdjust" modal :header="`Корректировать склад — ${adjustingProduct?.name}`"
      :style="{ width: '440px' }">
      <div class="stock-adjust-content">
        <div class="current-stock">
          <span class="text-secondary">Текущий остаток</span>
          <span class="font-mono" style="font-size:24px;font-weight:700">{{ adjustingProduct?.stock_qty }}</span>
        </div>
        <div class="toggle-row-three">
          <button :class="['toggle-btn', { active: adjustMode === 'add' }]" @click="adjustMode = 'add'; adjustQty = ''">
            <i class="pi pi-plus" /> Добавить
          </button>
          <button :class="['toggle-btn', { active: adjustMode === 'remove' }]" @click="adjustMode = 'remove'; adjustQty = ''">
            <i class="pi pi-minus" /> Убрать
          </button>
          <button :class="['toggle-btn', { active: adjustMode === 'set' }]" @click="adjustMode = 'set'; adjustQty = ''">
            <i class="pi pi-equals" /> Точно
          </button>
        </div>
        <div class="field-group">
          <label class="field-label">{{ adjustMode === 'set' ? 'Точное количество' : 'Количество' }}</label>
          <div class="qty-input-row">
            <button class="qty-step-btn" @click="stepQty(-1)"><i class="pi pi-minus" /></button>
            <InputText v-model="adjustQty" type="number" class="w-full" style="text-align:center;font-size:18px;font-weight:700" placeholder="0.00" min="0" step="0.001" />
            <button class="qty-step-btn" @click="stepQty(1)"><i class="pi pi-plus" /></button>
          </div>
        </div>
        <div v-if="adjustQty !== '' && adjustQty !== null" class="adjust-preview" :class="adjustPreviewClass">
          <span class="text-secondary" style="font-size:13px">Будет:</span>
          <span class="font-mono" style="font-size:20px;font-weight:700">{{ adjustPreviewQty }}</span>
          <span class="preview-delta font-mono" style="font-size:13px">{{ adjustPreviewDelta }}</span>
        </div>
        <div class="field-group">
          <label class="field-label">Причина</label>
          <Select v-model="adjustReason" :options="adjustReasons" class="w-full" />
        </div>
      </div>
      <template #footer>
        <Button label="Отмена" class="p-button-secondary" @click="showStockAdjust = false" />
        <Button label="Применить" :disabled="!adjustQty || !adjustReason" :loading="saving" @click="applyStockAdjust"
          style="flex:1" />
      </template>
    </Dialog>

    <!-- Print Label Dialog -->
    <PrintLabelDialog v-model="showPrintLabel" :product="printProduct" @print="handlePrint" />

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import { useSessionStore } from '../stores/session.js'
import PrintLabelDialog from '../components/PrintLabelDialog.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Drawer from 'primevue/drawer'
import Dialog from 'primevue/dialog'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()
const session = useSessionStore()
const canManage = computed(() => session.user?.role !== 'cashier')

const allProducts = ref([])
const categories = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const categoryFilter = ref(null)
const activeFilter = ref('all')
const showDrawer = ref(false)
const showStockAdjust = ref(false)
const showPrintLabel = ref(false)
const editingProduct = ref(null)
const adjustingProduct = ref(null)
const printProduct = ref(null)
const adjustMode = ref('add')
let searchTimeout = null

const tabs = [
  { label: 'Все', value: 'all' },
  { label: 'Мало', value: 'low' },
  { label: 'Дефицит', value: 'oversold' }
]

const adjustReasons = ['Корректировка приёма', 'Повреждено', 'Корректировка счёта', 'Возврат поставщику', 'Другое']
const UNITS = ['шт', 'кг', 'г', 'л', 'упак', 'коробка']

const defaultForm = () => ({
  name: '', barcodes: [], price: '', cost: '', stock_qty: 0,
  unit: 'шт', category_id: null, image_url: '', low_stock_threshold: 5
})

const form = ref(defaultForm())
const adjustQty = ref('')
const adjustReason = ref('')

const adjustPreviewQty = computed(() => {
  const current = adjustingProduct.value?.stock_qty ?? 0
  const val = parseFloat(adjustQty.value)
  if (isNaN(val)) return current
  if (adjustMode.value === 'add') return current + val
  if (adjustMode.value === 'remove') return current - val
  return val // set mode
})

const adjustPreviewDelta = computed(() => {
  const current = adjustingProduct.value?.stock_qty ?? 0
  const delta = adjustPreviewQty.value - current
  if (delta === 0) return '±0'
  return delta > 0 ? `+${delta}` : `${delta}`
})

const adjustPreviewClass = computed(() => {
  const delta = adjustPreviewQty.value - (adjustingProduct.value?.stock_qty ?? 0)
  if (delta > 0) return 'preview-add'
  if (delta < 0) return 'preview-remove'
  return 'preview-neutral'
})

const totalProducts = computed(() => allProducts.value.length)

const filteredProducts = computed(() => {
  let items = allProducts.value

  if (search.value) {
    const q = search.value.toLowerCase()
    items = items.filter(p =>
      p.name.toLowerCase().includes(q) ||
      (Array.isArray(p.barcodes) && p.barcodes.some(b => b.barcode.includes(q))) ||
      (p.barcode && p.barcode.includes(q)) ||
      (p.category_name && p.category_name.toLowerCase().includes(q))
    )
  }

  if (activeFilter.value === 'low') items = items.filter(p => p.stock_qty > 0 && p.stock_qty <= (p.low_stock_threshold || 5))
  else if (activeFilter.value === 'oversold') items = items.filter(p => p.stock_qty < 0)

  return items
})

const totalValue = computed(() =>
  filteredProducts.value.reduce((sum, p) => sum + (parseFloat(p.price) * Math.max(0, p.stock_qty)), 0)
)

const oversoldCount = computed(() => allProducts.value.filter(p => p.stock_qty < 0).length)
const lowCount = computed(() => allProducts.value.filter(p => p.stock_qty > 0 && p.stock_qty <= (p.low_stock_threshold || 5)).length)

function getTabCount(filter) {
  if (filter === 'all') return 0
  if (filter === 'low') return lowCount.value
  if (filter === 'oversold') return oversoldCount.value
  return 0
}

function formatCompact(n) {
  if (n >= 1_000_000_000) return (n / 1_000_000_000).toFixed(1).replace(/\.0$/, '') + 'B'
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1).replace(/\.0$/, '') + 'M'
  if (n >= 1_000) return (n / 1_000).toFixed(1).replace(/\.0$/, '') + 'K'
  return n.toLocaleString('ru')
}

onMounted(async () => {
  await Promise.all([loadProducts(), loadCategories()])
})

async function loadProducts() {
  loading.value = true
  try {
    const params = new URLSearchParams({ limit: 1000 })
    if (categoryFilter.value) params.set('category_id', categoryFilter.value)
    const data = await api.get(`/api/products?${params}`)
    allProducts.value = data.data || data
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

async function loadCategories() {
  categories.value = await api.get('/api/categories')
}

function debouncedSearch() {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {}, 0) // search is client-side via computed
}

function openCreate() {
  editingProduct.value = null
  form.value = defaultForm()
  showDrawer.value = true
}

function openEdit(product) {
  editingProduct.value = product
  form.value = {
    ...product,
    barcodes: Array.isArray(product.barcodes) ? product.barcodes.map(b => ({ ...b })) : []
  }
  showDrawer.value = true
}

function openStockAdjust(product) {
  adjustingProduct.value = product
  adjustQty.value = ''
  adjustReason.value = ''
  adjustMode.value = 'add'
  showStockAdjust.value = true
}

function stepQty(dir) {
  const current = parseFloat(adjustQty.value) || 0
  const next = Math.round((current + dir) * 1000) / 1000
  if (adjustMode.value !== 'set' && next < 0) return
  adjustQty.value = String(next)
}

function openPrintLabel(product) {
  printProduct.value = product
  showPrintLabel.value = true
}

async function saveProduct() {
  saving.value = true
  try {
    const cleanBarcodes = form.value.barcodes.filter(b => b.barcode?.trim())
    if (cleanBarcodes.length > 0 && !cleanBarcodes.some(b => b.is_primary)) {
      cleanBarcodes[0].is_primary = 1
    }
    const payload = { ...form.value, barcodes: cleanBarcodes }

    if (editingProduct.value) {
      await api.put(`/api/products/${editingProduct.value.id}`, payload)
      toast.add({ severity: 'success', summary: 'Обновлено', detail: form.value.name, life: 2000 })
    } else {
      await api.post('/api/products', payload)
      toast.add({ severity: 'success', summary: 'Создано', detail: form.value.name, life: 2000 })
    }
    showDrawer.value = false
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function applyStockAdjust() {
  saving.value = true
  try {
    const qty = parseFloat(adjustQty.value)
    let delta
    if (adjustMode.value === 'add') delta = qty
    else if (adjustMode.value === 'remove') delta = -qty
    else delta = qty - (adjustingProduct.value?.stock_qty ?? 0) // set mode
    await api.patch(`/api/products/${adjustingProduct.value.id}/stock`, {
      delta,
      reason: adjustReason.value
    })
    toast.add({ severity: 'success', summary: 'Склад скорректирован', detail: `${delta > 0 ? '+' : ''}${delta}`, life: 2000 })
    showStockAdjust.value = false
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function generateBarcode(product) {
  try {
    const data = await api.get(`/api/barcode/generate?product_id=${product.id}`)
    if (data.generated) {
      toast.add({ severity: 'success', summary: 'Штрихкод создан', detail: data.barcode, life: 3000 })
      await loadProducts()
    } else {
      toast.add({ severity: 'info', summary: 'Штрихкод уже есть', detail: data.barcode, life: 2000 })
    }
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  }
}

function addBarcodeField() {
  const isPrimary = form.value.barcodes.length === 0 ? 1 : 0
  form.value.barcodes.push({ barcode: '', is_primary: isPrimary })
}

function setPrimaryBarcode(idx) {
  form.value.barcodes.forEach((b, i) => { b.is_primary = i === idx ? 1 : 0 })
}

async function generateBarcodeInForm() {
  const base = String(Math.floor(Math.random() * 1_000_000_000_000)).padStart(12, '0')
  let sum = 0
  base.split('').forEach((d, i) => { sum += parseInt(d) * (i % 2 === 0 ? 1 : 3) })
  const check = (10 - (sum % 10)) % 10
  const newBarcode = base + check
  const isPrimary = form.value.barcodes.length === 0 ? 1 : 0
  form.value.barcodes.push({ barcode: newBarcode, is_primary: isPrimary })
  toast.add({ severity: 'success', summary: 'Штрихкод сгенерирован', detail: newBarcode, life: 3000 })
}

async function deleteProduct(product) {
  if (!confirm(`Удалить "${product.name}"?`)) return
  try {
    await api.delete(`/api/products/${product.id}`)
    toast.add({ severity: 'success', summary: 'Удалено', life: 2000 })
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  }
}

async function handlePrint({ product, barcode, copies, size }) {
  try {
    await api.post('/api/barcode/print', {
      product_id: product.id,
      barcode: barcode || product.barcode,
      product_name: product.name,
      price: product.price,
      copies, size
    })
    toast.add({ severity: 'success', summary: 'Команда печати отправлена', life: 2000 })
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка печати', detail: e.message, life: 3000 })
  }
}

function highlight(text) {
  if (!search.value || !text) return text
  const escaped = search.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return String(text).replace(new RegExp(`(${escaped})`, 'gi'), '<mark class="search-highlight">$1</mark>')
}

function formatPrice(n) { return parseFloat(n || 0).toFixed(2) }

function stockLabel(qty, threshold = 5) {
  if (qty < 0) return `Дефицит (${qty})`
  if (qty === 0) return 'Нет в наличии'
  if (qty <= threshold) return `Мало (${qty})`
  return `${qty} на складе`
}

function stockBadgeClass(qty, threshold = 5) {
  if (qty < 0) return 'danger glow'
  if (qty === 0) return 'danger'
  if (qty <= threshold) return 'warning'
  return 'success'
}
</script>

<style scoped>
.inventory-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 12px;
  overflow: hidden;
}

/* Header */
.view-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-shrink: 0;
}

.view-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
}

.view-subtitle {
  font-size: 13px;
  color: var(--text-muted);
  margin-top: 2px;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

/* Search */
.search-wrapper {
  display: flex;
  align-items: center;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  height: 44px;
  padding: 0 14px;
  gap: 8px;
  width: 240px;
}

.search-wrapper:focus-within {
  border-color: var(--border-focus);
}

.search-icon { color: var(--text-muted); font-size: 14px; }

.search-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-primary);
  font-size: 14px;
  font-family: var(--font-sans);
}

.clear-btn {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 14px;
  line-height: 1;
}

/* Filter Tabs */
.filter-tabs {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.filter-tab {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 18px;
  border-radius: 20px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.15s;
}

.filter-tab:hover { border-color: rgba(123,104,238,0.4); color: var(--text-primary); }

.filter-tab.active {
  background: var(--accent-glow);
  color: var(--text-accent);
  border-color: var(--accent-1);
}

.tab-count {
  background: var(--danger-bg);
  color: var(--danger);
  border-radius: 10px;
  padding: 2px 7px;
  font-size: 11px;
}

/* Stats Bar */
.stats-bar {
  display: flex;
  align-items: center;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 10px 20px;
  flex-shrink: 0;
  gap: 0;
}

.stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.stat-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-accent);
}

.stat-label {
  font-size: 11px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.stat-divider {
  width: 1px;
  height: 36px;
  background: var(--border-default);
  margin: 0 8px;
}

/* Cards Container */
.cards-container {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
}

.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 12px;
  padding-bottom: 12px;
}

.loading-state, .empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 80px 20px;
  color: var(--text-muted);
  font-size: 15px;
}

/* Product Card */
.product-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 14px 16px;
  transition: border-color 0.2s;
}

.product-card:hover {
  border-color: rgba(123, 104, 238, 0.35);
}

.card-main {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
  gap: 12px;
}

.product-info { flex: 1; min-width: 0; }
.product-name { font-size: 14px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.product-barcode { font-size: 12px; color: var(--text-muted); margin-bottom: 2px; }
.product-category { font-size: 12px; }

.card-right { display: flex; flex-direction: column; align-items: flex-end; gap: 4px; flex-shrink: 0; }
.product-price { font-size: 15px; font-weight: 700; color: var(--text-accent); }
.product-cost { font-size: 12px; }

.card-actions {
  display: flex;
  gap: 6px;
}

.action-btn {
  flex: 1;
  height: 38px;
  border-radius: 10px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  color: var(--text-secondary);
  font-size: 14px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.12s;
}

.action-btn:hover {
  color: var(--text-accent);
  border-color: var(--accent-1);
  background: var(--accent-glow);
}

.danger-btn:hover {
  color: var(--danger);
  border-color: var(--danger);
  background: var(--danger-bg);
}

/* Stock Badge */
.stock-badge {
  display: inline-flex;
  align-items: center;
  padding: 3px 9px;
  border-radius: 8px;
  font-size: 11px;
  font-weight: 600;
  font-family: var(--font-mono);
}

.stock-badge.success { background: var(--success-bg); color: var(--success); }
.stock-badge.warning { background: var(--warning-bg); color: var(--warning); }
.stock-badge.danger { background: var(--danger-bg); color: var(--danger); }
.stock-badge.danger.glow { animation: pulse-danger 2s infinite; }

/* Drawer Form */
.drawer-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 4px 0;
}

.field-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.field-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.drawer-footer {
  display: flex;
  gap: 10px;
  padding: 16px;
}

/* Stock Adjust Dialog */
.stock-adjust-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.current-stock {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--bg-surface);
  border-radius: 12px;
  padding: 16px;
}

.toggle-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.toggle-row-three {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 8px;
}

.qty-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.qty-step-btn {
  width: 48px;
  height: 48px;
  flex-shrink: 0;
  border-radius: 12px;
  border: 1px solid var(--border-default);
  background: var(--bg-surface);
  color: var(--text-secondary);
  font-size: 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.12s;
}

.qty-step-btn:hover {
  color: var(--text-accent);
  border-color: var(--accent-1);
  background: var(--accent-glow);
}

:deep(.qty-center input) { text-align: center; font-size: 18px; font-weight: 700; }
:deep(.qty-center.p-inputtext) { text-align: center; font-size: 18px; font-weight: 700; }

.adjust-preview {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-radius: 12px;
  padding: 12px 16px;
  border: 1px solid;
}

.adjust-preview.preview-add {
  background: var(--success-bg);
  border-color: rgba(0, 212, 170, 0.25);
  color: var(--success);
}

.adjust-preview.preview-remove {
  background: var(--danger-bg);
  border-color: rgba(255, 92, 92, 0.25);
  color: var(--danger);
}

.adjust-preview.preview-neutral {
  background: var(--bg-surface);
  border-color: var(--border-default);
  color: var(--text-secondary);
}

.preview-delta {
  opacity: 0.75;
}

.toggle-btn {
  height: 48px;
  border-radius: 12px;
  border: 1px solid var(--border-default);
  background: var(--bg-surface);
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: all 0.15s;
}

.toggle-btn.active {
  background: var(--gradient-hero);
  border-color: transparent;
  color: #fff;
}

.w-full { width: 100%; }

/* Barcode management */
.barcodes-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.barcode-entry {
  display: flex;
  align-items: center;
  gap: 6px;
}

.primary-star {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid var(--border-default);
  background: var(--bg-input);
  color: var(--text-muted);
  font-size: 15px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.12s;
}

.primary-star.active {
  color: var(--warning);
  border-color: var(--warning);
  background: var(--warning-bg);
}

.bc-remove-btn {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid var(--border-default);
  background: var(--bg-input);
  color: var(--text-muted);
  font-size: 13px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.12s;
}

.bc-remove-btn:hover {
  color: var(--danger);
  border-color: var(--danger);
  background: var(--danger-bg);
}

.barcode-add-row {
  display: flex;
  gap: 6px;
  margin-top: 2px;
}

.add-barcode-btn {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 0 14px;
  height: 34px;
  border-radius: 8px;
  border: 1px dashed var(--border-default);
  background: transparent;
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.12s;
}

.add-barcode-btn:hover {
  border-color: var(--accent-1);
  color: var(--text-accent);
  background: var(--accent-glow);
}

.unit-chips {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.unit-chip {
  height: 40px;
  padding: 0 16px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 20px;
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s, color 0.15s;
}

.unit-chip:hover { border-color: rgba(123, 104, 238, 0.4); color: var(--text-primary); }

.unit-chip.active {
  border-color: var(--accent-1);
  background: rgba(123, 104, 238, 0.15);
  color: var(--text-accent);
}

:deep(.search-highlight) {
  background: rgba(255, 214, 0, 0.30);
  color: #ffd600;
  border-radius: 3px;
  padding: 0 2px;
  font-weight: 700;
}
</style>
