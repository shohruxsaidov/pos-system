<template>
  <div class="incoming-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Приём товара</h1>
        <p class="view-subtitle">{{ today }}</p>
      </div>
      <div class="header-actions">
        <Button label="История" icon="pi pi-history" class="p-button-secondary"
          @click="$router.push('/incoming/history')" />
        <Button label="Подтвердить приём" icon="pi pi-check" :disabled="items.length === 0 || saving" :loading="saving"
          @click="confirmReceipt" />
      </div>
    </div>

    <!-- Meta row: supplier, warehouse, notes -->
    <div class="card meta-card">
      <div class="meta-row">
        <div class="field-group" style="flex:1">
          <label class="field-label">Поставщик</label>
          <InputText v-model="supplier" placeholder="Название поставщика" class="w-full" />
        </div>
        <div class="field-group" v-if="warehouses.length > 0" style="width:200px">
          <label class="field-label">Склад</label>
          <Select v-model="warehouseId" :options="warehouses" option-label="name" option-value="id" class="w-full" />
        </div>
        <div class="field-group" style="flex:1">
          <label class="field-label">Заметки</label>
          <InputText v-model="notes" placeholder="Примечания к поставке" class="w-full" />
        </div>
      </div>
    </div>

    <!-- Add item bar -->
    <div class="card add-bar">
      <!-- Search input -->
      <div v-if="!selectedProduct && !manualMode" class="add-section search-section">
        <label class="field-label">Штрихкод или название</label>
        <div class="search-row">
          <input ref="searchInput" v-model="searchQuery" class="search-input" placeholder="Сканируйте или введите..."
            autocomplete="off" @keydown.enter="handleEnter" @input="onSearchInput" />
          <button class="icon-btn" @click="focusSearch">
            <i class="pi pi-barcode" />
          </button>
        </div>
      </div>

      <!-- Search results dropdown -->
      <div v-if="searchResults.length > 0 && !selectedProduct" class="search-dropdown">
        <div v-for="p in searchResults" :key="p.id" class="result-item" @click="selectProduct(p)">
          <div class="result-name">{{ p.name }}</div>
          <div class="result-meta">
            <span class="font-mono result-barcode">{{ p.barcode || '—' }}</span>
            <span :class="['result-stock', stockClass(p.stock_qty)]">{{ p.stock_qty }} шт</span>
          </div>
        </div>
      </div>

      <!-- Not found -->
      <div v-if="notFound && !selectedProduct && !manualMode" class="not-found-box">
        <i class="pi pi-exclamation-triangle" />
        <span>Товар не найден</span>
        <button class="link-btn" @click="startManual">Добавить вручную</button>
      </div>

      <!-- Selected product chip -->
      <div v-if="selectedProduct" class="selected-chip">
        <div class="chip-info">
          <span class="chip-name">{{ selectedProduct.name }}</span>
          <span class="chip-barcode font-mono">{{ selectedProduct.barcode || '—' }}</span>
          <span :class="['chip-stock', stockClass(selectedProduct.stock_qty)]">
            {{ selectedProduct.stock_qty }} {{ selectedProduct.unit || 'шт' }}
          </span>
        </div>
        <button class="icon-btn-sm" @click="clearProduct"><i class="pi pi-times" /></button>
      </div>

      <!-- Manual name field -->
      <div v-if="manualMode && !selectedProduct" class="add-section" style="min-width:200px">
        <label class="field-label">
          Название
          <button class="link-btn" @click="cancelManual" style="margin-left:8px">отмена</button>
        </label>
        <InputText v-model="manualName" class="w-full" placeholder="Введите название" />
      </div>

      <!-- Qty / Cost / Expiry / Add button -->
      <template v-if="selectedProduct || manualMode">
        <div class="add-section" style="width:110px">
          <label class="field-label">Кол-во</label>
          <InputNumber v-model="itemForm.qty" :min="1" :show-buttons="false" class="w-full" placeholder="0" />
        </div>
        <div class="add-section" style="width:140px">
          <label class="field-label">Себестоимость</label>
          <InputNumber v-model="itemForm.cost" :min="0" :max-fraction-digits="2" class="w-full" placeholder="0.00" />
        </div>
        <div class="add-section" style="width:140px">
          <label class="field-label">Годен до</label>
          <InputText v-model="itemForm.expiry" class="w-full" placeholder="ГГГГ-ММ-ДД" />
        </div>
        <div class="add-section add-btn-section">
          <label class="field-label">&nbsp;</label>
          <Button icon="pi pi-plus" label="Добавить" :disabled="!itemForm.qty || (manualMode && !manualName)"
            @click="addItem" />
        </div>
      </template>
    </div>

    <!-- Items table -->
    <div class="card items-card">
      <div class="items-header">
        <h3 class="items-title">
          Товары <span class="items-count">{{ items.length }}</span>
        </h3>
        <span class="total-label">
          Итого: <span class="total-value font-mono">{{ formatPrice(totalCost) }}</span>
        </span>
      </div>

      <div v-if="items.length === 0" class="empty-items">
        <i class="pi pi-inbox empty-icon" />
        <p>Добавьте товары через строку выше</p>
      </div>

      <DataTable v-else :value="items" size="small">
        <Column header="Товар">
          <template #body="{ data }">
            <div class="item-name">{{ data.product_name }}</div>
            <div v-if="data.barcode" class="item-barcode font-mono">{{ data.barcode }}</div>
          </template>
        </Column>
        <Column header="Кол-во" style="width:90px;text-align:right">
          <template #body="{ data }">
            <span class="font-mono">{{ data.qty_received }} {{ data.unit }}</span>
          </template>
        </Column>
        <Column header="Себест." style="width:120px;text-align:right">
          <template #body="{ data }">
            <span class="font-mono">{{ formatPrice(data.cost_per_unit) }}</span>
          </template>
        </Column>
        <Column header="Сумма" style="width:130px;text-align:right">
          <template #body="{ data }">
            <span class="font-mono amount-text">{{ formatPrice(data.subtotal) }}</span>
          </template>
        </Column>
        <Column header="Годен до" style="width:110px">
          <template #body="{ data }">
            <span class="text-muted">{{ data.expiry_date || '—' }}</span>
          </template>
        </Column>
        <Column style="width:40px">
          <template #body="{ index }">
            <button class="delete-btn" @click="removeItem(index)">
              <i class="pi pi-times" />
            </button>
          </template>
        </Column>
      </DataTable>
    </div>

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import InputNumber from 'primevue/inputnumber'
import Select from 'primevue/select'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const supplier = ref('')
const notes = ref('')
const warehouseId = ref(1)
const warehouses = ref([])
const items = ref([])
const saving = ref(false)

const searchInput = ref(null)
const searchQuery = ref('')
const searchResults = ref([])
const selectedProduct = ref(null)
const notFound = ref(false)
const manualMode = ref(false)
const manualName = ref('')
const searching = ref(false)
const itemForm = ref({ qty: null, cost: null, expiry: '' })


const today = computed(() => new Date().toLocaleDateString('ru-RU', {
  day: 'numeric', month: 'long', year: 'numeric'
}))

const totalCost = computed(() =>
  items.value.reduce((s, i) => s + (i.subtotal || 0), 0)
)

function formatPrice(n) {
  const [int, dec] = parseFloat(n || 0).toFixed(2).split('.')
  return int.replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + '.' + dec
}

function stockClass(qty) {
  if (qty <= 0) return 'stock-danger'
  if (qty <= 5) return 'stock-warn'
  return 'stock-ok'
}

onMounted(async () => {
  try {
    const whs = await api.get('/api/warehouses')
    warehouses.value = whs.filter(w => w.is_active)
    if (warehouses.value.length > 0) warehouseId.value = warehouses.value[0].id
  } catch (e) { }
  focusSearch()
})

function focusSearch() {
  searchInput.value?.focus()
}

let searchTimer = null
function onSearchInput() {
  notFound.value = false
  searchResults.value = []
  clearTimeout(searchTimer)
  if (!searchQuery.value.trim()) return
  searchTimer = setTimeout(doSearch, 300)
}

async function doSearch() {
  if (!searchQuery.value.trim()) return
  searching.value = true
  try {
    const res = await api.get(`/api/products?search=${encodeURIComponent(searchQuery.value)}&limit=8`)
    const results = Array.isArray(res) ? res : (res.data || [])
    searchResults.value = results
    if (results.length === 0) notFound.value = true
  } catch (e) {
    searchResults.value = []
  } finally {
    searching.value = false
  }
}

async function handleEnter() {
  if (!searchQuery.value.trim()) return
  try {
    const product = await api.get(`/api/products/barcode/${encodeURIComponent(searchQuery.value.trim())}`)
    selectProduct(product)
  } catch (e) {
    await doSearch()
  }
}

function selectProduct(p) {
  selectedProduct.value = p
  searchQuery.value = ''
  searchResults.value = []
  notFound.value = false
  itemForm.value = { qty: 1, cost: parseFloat(p.cost || 0), expiry: '' }
}

function clearProduct() {
  selectedProduct.value = null
  manualMode.value = false
  manualName.value = ''
  itemForm.value = { qty: null, cost: null, expiry: '' }
  focusSearch()
}

function startManual() {
  manualMode.value = true
  notFound.value = false
  itemForm.value = { qty: 1, cost: 0, expiry: '' }
}

function cancelManual() {
  manualMode.value = false
  manualName.value = ''
  itemForm.value = { qty: null, cost: null, expiry: '' }
  searchQuery.value = ''
  notFound.value = false
}

function addItem() {
  const qty = Number(itemForm.value.qty) || 0
  const cost = Number(itemForm.value.cost) || 0
  if (!qty) return

  items.value.push({
    product_id: selectedProduct.value?.id || null,
    product_name: selectedProduct.value?.name || manualName.value,
    barcode: selectedProduct.value?.barcode || null,
    unit: selectedProduct.value?.unit || 'шт',
    qty_received: qty,
    cost_per_unit: cost,
    expiry_date: itemForm.value.expiry || null,
    subtotal: qty * cost
  })

  selectedProduct.value = null
  manualMode.value = false
  manualName.value = ''
  searchQuery.value = ''
  searchResults.value = []
  notFound.value = false
  itemForm.value = { qty: null, cost: null, expiry: '' }
  focusSearch()
}

function removeItem(index) {
  items.value.splice(index, 1)
}

async function confirmReceipt() {
  if (!items.value.length) return
  saving.value = true
  try {
    const payload = {
      supplier: supplier.value || null,
      notes: notes.value || null,
      warehouse_id: warehouseId.value,
      items: items.value.map(i => ({
        product_id: i.product_id,
        product_name: i.product_name,
        qty_received: i.qty_received,
        cost_per_unit: i.cost_per_unit,
        expiry_date: i.expiry_date,
        unit: i.unit
      }))
    }
    const res = await api.post('/api/incoming', payload)
    toast.add({ severity: 'success', summary: 'Приём оформлен', detail: `Накладная ${res.ref_no}`, life: 4000 })
    items.value = []
    supplier.value = ''
    notes.value = ''
    focusSearch()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 4000 })
  } finally {
    saving.value = false
  }
}

</script>

<style scoped>
.incoming-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: auto;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-shrink: 0;
}

.view-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
  margin: 0;
}

.view-subtitle {
  font-size: 13px;
  color: var(--text-secondary);
  margin: 2px 0 0;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 20px;
}

/* Meta row */
.meta-card {
  padding: 16px 20px;
}

.meta-row {
  display: flex;
  gap: 12px;
  align-items: flex-end;
}

.field-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  display: flex;
  align-items: center;
}

.w-full {
  width: 100%;
}

/* Add bar */
.add-bar {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.add-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.search-section {
  flex: 1;
  min-width: 220px;
}

.search-row {
  display: flex;
  gap: 8px;
}

.search-input {
  flex: 1;
  height: 48px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-primary);
  font-size: 15px;
  padding: 0 14px;
  outline: none;
  transition: border-color 0.15s;
  font-family: var(--font-sans);
}

.search-input:focus {
  border-color: var(--border-focus);
}

.icon-btn {
  width: 48px;
  height: 48px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  flex-shrink: 0;
  transition: all 0.12s;
}

.icon-btn:hover {
  border-color: var(--border-focus);
  color: var(--text-primary);
}

.icon-btn-sm {
  width: 28px;
  height: 28px;
  background: transparent;
  border: 1px solid var(--border-default);
  border-radius: 8px;
  color: var(--text-muted);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  flex-shrink: 0;
  transition: all 0.12s;
}

.icon-btn-sm:hover {
  background: var(--danger-bg);
  border-color: var(--danger);
  color: var(--danger);
}

/* Search dropdown — absolutely positioned below the add-bar */
.search-dropdown {
  position: absolute;
  top: calc(100% + 4px);
  left: 20px;
  width: 360px;
  background: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  overflow: hidden;
  max-height: 260px;
  overflow-y: auto;
  z-index: 100;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
}

.result-item {
  padding: 10px 14px;
  cursor: pointer;
  border-bottom: 1px solid var(--border-subtle);
  transition: background 0.1s;
}

.result-item:last-child {
  border-bottom: none;
}

.result-item:hover {
  background: var(--bg-hover);
}

.result-name {
  font-size: 13px;
  color: var(--text-primary);
  font-weight: 500;
}

.result-meta {
  display: flex;
  justify-content: space-between;
  margin-top: 3px;
}

.result-barcode {
  font-size: 11px;
  color: var(--text-muted);
}

.result-stock {
  font-size: 11px;
  font-weight: 600;
}

.stock-ok {
  color: var(--success);
}

.stock-warn {
  color: var(--warning);
}

.stock-danger {
  color: var(--danger);
}

.not-found-box {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: var(--warning-bg);
  border: 1px solid rgba(255, 176, 46, 0.2);
  border-radius: 10px;
  font-size: 13px;
  color: var(--warning);
  align-self: flex-end;
}

.link-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--accent-1);
  font-size: 12px;
  padding: 0;
  text-decoration: underline;
}

/* Selected product chip */
.selected-chip {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  background: var(--bg-elevated);
  border: 1px solid var(--border-focus);
  border-radius: 12px;
  flex: 1;
  min-width: 220px;
  max-width: 360px;
}

.chip-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.chip-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.chip-barcode {
  font-size: 11px;
  color: var(--text-muted);
}

.chip-stock {
  font-size: 11px;
  font-weight: 600;
}

.add-btn-section {
  justify-content: flex-end;
}

/* Items table */
.items-card {
  flex: 1;
}

.items-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.items-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-primary);
  display: flex;
  align-items: center;
  gap: 8px;
}

.items-count {
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  padding: 1px 8px;
  color: var(--text-secondary);
}

.total-label {
  font-size: 13px;
  color: var(--text-secondary);
}

.total-value {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

.empty-items {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 40px 20px;
  color: var(--text-muted);
}

.empty-icon {
  font-size: 36px;
}

.item-name {
  font-size: 13px;
  color: var(--text-primary);
  font-weight: 500;
}

.item-barcode {
  font-size: 11px;
  color: var(--text-muted);
  margin-top: 2px;
}

.amount-text {
  font-weight: 700;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.delete-btn {
  width: 28px;
  height: 28px;
  border: none;
  border-radius: 8px;
  background: var(--danger-bg);
  color: var(--danger);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  transition: all 0.12s;
}

.delete-btn:hover {
  background: var(--danger);
  color: #fff;
}

.text-muted {
  color: var(--text-secondary);
}

/* History dialog */
.dialog-loading {
  display: flex;
  justify-content: center;
  padding: 40px;
  font-size: 24px;
  color: var(--accent-1);
}

.expansion-content {
  padding: 8px 0 8px 40px;
  background: var(--bg-elevated);
}

.expansion-loading {
  padding: 12px 16px;
  color: var(--text-secondary);
  font-size: 13px;
}
</style>
