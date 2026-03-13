<template>
  <div class="inventory-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Склад</h1>
        <p class="view-subtitle">{{ totalProducts }} товаров</p>
      </div>
      <div class="header-actions">
        <InputText v-model="search" placeholder="Поиск..." class="search-input" @input="debouncedSearch" />
        <Select v-model="categoryFilter" :options="[{id:null,name:'Все категории'},...categories]" option-label="name" option-value="id" style="width:180px" />
        <Select v-model="stockFilter" :options="stockFilterOptions" option-label="label" option-value="value" style="width:160px" />
        <Button label="Добавить товар" icon="pi pi-plus" @click="openCreate" />
      </div>
    </div>

    <!-- DataTable -->
    <DataTable
      :value="products"
      :loading="loading"
      scrollable
      scroll-height="flex"
      class="inventory-table"
      row-hover
    >
      <Column field="barcode" header="Штрихкод" style="width:140px">
        <template #body="{ data }">
          <span class="font-mono" style="font-size:12px">{{ data.barcode || '—' }}</span>
        </template>
      </Column>
      <Column field="name" header="Товар" sortable />
      <Column field="category_name" header="Категория" style="width:130px" />
      <Column field="price" header="Цена" sortable style="width:100px">
        <template #body="{ data }">
          <span class="font-mono">{{ formatPrice(data.price) }}</span>
        </template>
      </Column>
      <Column field="cost" header="Себест." style="width:100px">
        <template #body="{ data }">
          <span class="font-mono text-muted">{{ formatPrice(data.cost) }}</span>
        </template>
      </Column>
      <Column field="stock_qty" header="Склад" sortable style="width:140px">
        <template #body="{ data }">
          <div :class="['stock-badge', stockBadgeClass(data.stock_qty)]">
            {{ stockLabel(data.stock_qty) }}
          </div>
        </template>
      </Column>
      <Column field="unit" header="Ед." style="width:70px" />
      <Column header="Действия" style="width:200px">
        <template #body="{ data }">
          <div class="row-actions">
            <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px" @click="openEdit(data)" v-tooltip="'Редактировать'" />
            <Button icon="pi pi-chart-line" class="p-button-secondary" style="height:36px;width:36px" @click="openStockAdjust(data)" v-tooltip="'Корректировать склад'" />
            <Button icon="pi pi-barcode" class="p-button-secondary" style="height:36px;width:36px" @click="generateBarcode(data)" v-tooltip="'Создать штрихкод'" />
            <Button icon="pi pi-print" class="p-button-secondary" style="height:36px;width:36px" @click="openPrintLabel(data)" v-tooltip="'Печать этикетки'" />
            <Button icon="pi pi-trash" class="p-button-danger" style="height:36px;width:36px" @click="deleteProduct(data)" v-tooltip="'Удалить'" />
          </div>
        </template>
      </Column>
    </DataTable>

    <!-- Create/Edit Drawer -->
    <Drawer v-model:visible="showDrawer" :header="editingProduct ? 'Редактировать товар' : 'Новый товар'" position="right" style="width:480px">
      <div class="drawer-form">
        <div class="field-group">
          <label class="field-label">Название товара *</label>
          <InputText v-model="form.name" class="w-full" placeholder="Название товара" />
        </div>
        <div class="field-group">
          <label class="field-label">Штрихкод</label>
          <div class="p-inputgroup">
            <InputText v-model="form.barcode" class="w-full" placeholder="Сканировать или ввести штрихкод" />
            <Button icon="pi pi-refresh" class="p-button-secondary" @click="generateBarcodeInForm" v-tooltip="'Сгенерировать штрихкод'" />
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
            <InputText v-model="form.unit" class="w-full" placeholder="шт" />
          </div>
        </div>
        <div class="field-group">
          <label class="field-label">Категория</label>
          <Select v-model="form.category_id" :options="categories" option-label="name" option-value="id" placeholder="Выбрать категорию" class="w-full" />
        </div>
        <div class="field-group">
          <label class="field-label">URL изображения</label>
          <InputText v-model="form.image_url" class="w-full" placeholder="https://..." />
        </div>
      </div>

      <template #footer>
        <div class="drawer-footer">
          <Button label="Отмена" class="p-button-secondary" @click="showDrawer = false" />
          <Button :label="editingProduct ? 'Сохранить изменения' : 'Создать товар'" :loading="saving" @click="saveProduct" style="flex:1" />
        </div>
      </template>
    </Drawer>

    <!-- Stock Adjust Dialog -->
    <Dialog v-model:visible="showStockAdjust" modal :header="`Корректировать склад — ${adjustingProduct?.name}`" :style="{ width: '420px' }">
      <div class="stock-adjust-content">
        <div class="current-stock">
          <span class="text-secondary">Текущий остаток</span>
          <span class="font-mono" style="font-size:24px;font-weight:700">{{ adjustingProduct?.stock_qty }}</span>
        </div>
        <div class="field-group">
          <label class="field-label">Изменение запаса (+ добавить, − убрать)</label>
          <InputText v-model="adjustDelta" type="number" class="w-full" placeholder="+10 или -5" />
        </div>
        <div class="field-group">
          <label class="field-label">Причина</label>
          <Select v-model="adjustReason" :options="adjustReasons" class="w-full" />
        </div>
      </div>
      <template #footer>
        <Button label="Отмена" class="p-button-secondary" @click="showStockAdjust = false" />
        <Button label="Применить" :disabled="!adjustDelta || !adjustReason" :loading="saving" @click="applyStockAdjust" style="flex:1" />
      </template>
    </Dialog>

    <!-- Print Label Dialog -->
    <PrintLabelDialog v-model="showPrintLabel" :product="printProduct" @print="handlePrint" />

    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import PrintLabelDialog from '../components/PrintLabelDialog.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Drawer from 'primevue/drawer'
import Dialog from 'primevue/dialog'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const products = ref([])
const categories = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const categoryFilter = ref(null)
const stockFilter = ref(null)
const showDrawer = ref(false)
const showStockAdjust = ref(false)
const showPrintLabel = ref(false)
const editingProduct = ref(null)
const adjustingProduct = ref(null)
const printProduct = ref(null)
const totalProducts = ref(0)
let searchTimeout = null

const stockFilterOptions = [
  { label: 'Все', value: null },
  { label: 'Мало на складе', value: 'low' },
  { label: 'Нет в наличии', value: 'out' },
  { label: 'Перепродано', value: 'oversold' }
]

const adjustReasons = ['Корректировка приёма', 'Повреждено', 'Корректировка счёта', 'Возврат поставщику', 'Другое']

const defaultForm = () => ({
  name: '', barcode: '', price: '', cost: '', stock_qty: 0,
  unit: 'pcs', category_id: null, image_url: ''
})

const form = ref(defaultForm())
const adjustDelta = ref('')
const adjustReason = ref('')

onMounted(async () => {
  await Promise.all([loadProducts(), loadCategories()])
})

async function loadProducts() {
  loading.value = true
  try {
    const params = new URLSearchParams({ limit: 500 })
    if (search.value) params.set('search', search.value)
    if (categoryFilter.value) params.set('category_id', categoryFilter.value)
    if (stockFilter.value) params.set('stock_status', stockFilter.value)
    const data = await api.get(`/api/products?${params}`)
    products.value = data.data || data
    totalProducts.value = data.total || products.value.length
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
  searchTimeout = setTimeout(loadProducts, 300)
}

function openCreate() {
  editingProduct.value = null
  form.value = defaultForm()
  showDrawer.value = true
}

function openEdit(product) {
  editingProduct.value = product
  form.value = { ...product }
  showDrawer.value = true
}

function openStockAdjust(product) {
  adjustingProduct.value = product
  adjustDelta.value = ''
  adjustReason.value = ''
  showStockAdjust.value = true
}

function openPrintLabel(product) {
  printProduct.value = product
  showPrintLabel.value = true
}

async function saveProduct() {
  saving.value = true
  try {
    if (editingProduct.value) {
      await api.put(`/api/products/${editingProduct.value.id}`, form.value)
      toast.add({ severity: 'success', summary: 'Обновлено', detail: form.value.name, life: 2000 })
    } else {
      await api.post('/api/products', form.value)
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
    await api.patch(`/api/products/${adjustingProduct.value.id}/stock`, {
      delta: parseInt(adjustDelta.value),
      reason: adjustReason.value
    })
    toast.add({ severity: 'success', summary: 'Склад скорректирован', life: 2000 })
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

async function generateBarcodeInForm() {
  if (editingProduct.value?.id) {
    // Existing product — use API to generate and save
    try {
      const data = await api.get(`/api/barcode/generate?product_id=${editingProduct.value.id}`)
      form.value.barcode = data.barcode
      toast.add({ severity: 'success', summary: 'Штрихкод сгенерирован', detail: data.barcode, life: 3000 })
    } catch (e) {
      toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
    }
  } else {
    // New product — generate locally (random EAN13)
    const base = String(Math.floor(Math.random() * 1_000_000_000_000)).padStart(12, '0')
    let sum = 0
    base.split('').forEach((d, i) => { sum += parseInt(d) * (i % 2 === 0 ? 1 : 3) })
    const check = (10 - (sum % 10)) % 10
    form.value.barcode = base + check
    toast.add({ severity: 'success', summary: 'Штрихкод сгенерирован', detail: form.value.barcode, life: 3000 })
  }
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

async function handlePrint({ product, copies, size }) {
  try {
    await api.post('/api/barcode/print', {
      product_id: product.id,
      barcode: product.barcode,
      product_name: product.name,
      price: product.price,
      copies, size
    })
    toast.add({ severity: 'success', summary: 'Команда печати отправлена', life: 2000 })
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка печати', detail: e.message, life: 3000 })
  }
}

function formatPrice(n) { return parseFloat(n || 0).toFixed(2) }
function stockLabel(qty) {
  if (qty < 0) return `Перепродано (${qty})`
  if (qty === 0) return 'Нет в наличии'
  if (qty <= 5) return `Мало (${qty})`
  return `${qty} на складе`
}
function stockBadgeClass(qty) {
  if (qty < 0) return 'danger glow'
  if (qty === 0) return 'danger'
  if (qty <= 5) return 'warning'
  return 'success'
}
</script>

<style scoped>
.inventory-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: hidden;
}

.view-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
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

.search-input { width: 220px; }

.inventory-table { flex: 1; }

.row-actions { display: flex; gap: 4px; }

.drawer-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 4px 0;
}

.field-group { display: flex; flex-direction: column; gap: 6px; }
.field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }

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

.stock-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  font-family: var(--font-mono);
}
.stock-badge.success { background: var(--success-bg); color: var(--success); }
.stock-badge.warning { background: var(--warning-bg); color: var(--warning); }
.stock-badge.danger { background: var(--danger-bg); color: var(--danger); }
.stock-badge.danger.glow { animation: pulse-danger 2s infinite; }

.w-full { width: 100%; }
</style>
