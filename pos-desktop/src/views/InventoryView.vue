<template>
  <div class="inventory-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Inventory</h1>
        <p class="view-subtitle">{{ totalProducts }} products</p>
      </div>
      <div class="header-actions">
        <InputText v-model="search" placeholder="Search..." class="search-input" @input="debouncedSearch" />
        <Select v-model="categoryFilter" :options="[{id:null,name:'All Categories'},...categories]" option-label="name" option-value="id" style="width:180px" />
        <Select v-model="stockFilter" :options="stockFilterOptions" option-label="label" option-value="value" style="width:160px" />
        <Button label="Add Product" icon="pi pi-plus" @click="openCreate" />
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
      v-model:selection="selectedProducts"
    >
      <Column selection-mode="multiple" style="width:50px" />
      <Column field="barcode" header="Barcode" style="width:140px">
        <template #body="{ data }">
          <span class="font-mono" style="font-size:12px">{{ data.barcode || '—' }}</span>
        </template>
      </Column>
      <Column field="name" header="Product" sortable />
      <Column field="category_name" header="Category" style="width:130px" />
      <Column field="price" header="Price" sortable style="width:100px">
        <template #body="{ data }">
          <span class="font-mono">₱{{ formatPrice(data.price) }}</span>
        </template>
      </Column>
      <Column field="cost" header="Cost" style="width:100px">
        <template #body="{ data }">
          <span class="font-mono text-muted">₱{{ formatPrice(data.cost) }}</span>
        </template>
      </Column>
      <Column field="stock_qty" header="Stock" sortable style="width:140px">
        <template #body="{ data }">
          <div :class="['stock-badge', stockBadgeClass(data.stock_qty)]">
            {{ stockLabel(data.stock_qty) }}
          </div>
        </template>
      </Column>
      <Column field="unit" header="Unit" style="width:70px" />
      <Column header="Actions" style="width:200px">
        <template #body="{ data }">
          <div class="row-actions">
            <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px" @click="openEdit(data)" v-tooltip="'Edit'" />
            <Button icon="pi pi-chart-line" class="p-button-secondary" style="height:36px;width:36px" @click="openStockAdjust(data)" v-tooltip="'Adjust Stock'" />
            <Button icon="pi pi-barcode" class="p-button-secondary" style="height:36px;width:36px" @click="generateBarcode(data)" v-tooltip="'Generate Barcode'" />
            <Button icon="pi pi-print" class="p-button-secondary" style="height:36px;width:36px" @click="openPrintLabel(data)" v-tooltip="'Print Label'" />
            <Button icon="pi pi-trash" class="p-button-danger" style="height:36px;width:36px" @click="deleteProduct(data)" v-tooltip="'Delete'" />
          </div>
        </template>
      </Column>
    </DataTable>

    <!-- Create/Edit Drawer -->
    <Drawer v-model:visible="showDrawer" :header="editingProduct ? 'Edit Product' : 'New Product'" position="right" style="width:480px">
      <div class="drawer-form">
        <div class="field-group">
          <label class="field-label">Product Name *</label>
          <InputText v-model="form.name" class="w-full" placeholder="Product name" />
        </div>
        <div class="field-group">
          <label class="field-label">Barcode</label>
          <InputText v-model="form.barcode" class="w-full" placeholder="Scan or enter barcode" />
        </div>
        <div class="field-row">
          <div class="field-group">
            <label class="field-label">Price *</label>
            <InputText v-model="form.price" type="number" class="w-full" placeholder="0.00" />
          </div>
          <div class="field-group">
            <label class="field-label">Cost</label>
            <InputText v-model="form.cost" type="number" class="w-full" placeholder="0.00" />
          </div>
        </div>
        <div class="field-row">
          <div class="field-group">
            <label class="field-label">Stock Qty</label>
            <InputText v-model="form.stock_qty" type="number" class="w-full" placeholder="0" />
          </div>
          <div class="field-group">
            <label class="field-label">Unit</label>
            <InputText v-model="form.unit" class="w-full" placeholder="pcs" />
          </div>
        </div>
        <div class="field-group">
          <label class="field-label">Category</label>
          <Select v-model="form.category_id" :options="categories" option-label="name" option-value="id" placeholder="Select category" class="w-full" />
        </div>
        <div class="field-group">
          <label class="field-label">Image URL</label>
          <InputText v-model="form.image_url" class="w-full" placeholder="https://..." />
        </div>
      </div>

      <template #footer>
        <div class="drawer-footer">
          <Button label="Cancel" class="p-button-secondary" @click="showDrawer = false" />
          <Button :label="editingProduct ? 'Save Changes' : 'Create Product'" :loading="saving" @click="saveProduct" style="flex:1" />
        </div>
      </template>
    </Drawer>

    <!-- Stock Adjust Dialog -->
    <Dialog v-model:visible="showStockAdjust" modal :header="`Adjust Stock — ${adjustingProduct?.name}`" :style="{ width: '420px' }">
      <div class="stock-adjust-content">
        <div class="current-stock">
          <span class="text-secondary">Current Stock</span>
          <span class="font-mono" style="font-size:24px;font-weight:700">{{ adjustingProduct?.stock_qty }}</span>
        </div>
        <div class="field-group">
          <label class="field-label">Adjustment Delta (+ add, − remove)</label>
          <InputText v-model="adjustDelta" type="number" class="w-full" placeholder="+10 or -5" />
        </div>
        <div class="field-group">
          <label class="field-label">Reason</label>
          <Select v-model="adjustReason" :options="adjustReasons" class="w-full" />
        </div>
      </div>
      <template #footer>
        <Button label="Cancel" class="p-button-secondary" @click="showStockAdjust = false" />
        <Button label="Apply Adjustment" :disabled="!adjustDelta || !adjustReason" :loading="saving" @click="applyStockAdjust" style="flex:1" />
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
const selectedProducts = ref([])
const showDrawer = ref(false)
const showStockAdjust = ref(false)
const showPrintLabel = ref(false)
const editingProduct = ref(null)
const adjustingProduct = ref(null)
const printProduct = ref(null)
const totalProducts = ref(0)
let searchTimeout = null

const stockFilterOptions = [
  { label: 'All Stock', value: null },
  { label: 'Low Stock', value: 'low' },
  { label: 'Out of Stock', value: 'out' },
  { label: 'Oversold', value: 'oversold' }
]

const adjustReasons = ['Receiving correction', 'Damaged', 'Count correction', 'Return to supplier', 'Other']

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
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
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
      toast.add({ severity: 'success', summary: 'Updated', detail: form.value.name, life: 2000 })
    } else {
      await api.post('/api/products', form.value)
      toast.add({ severity: 'success', summary: 'Created', detail: form.value.name, life: 2000 })
    }
    showDrawer.value = false
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
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
    toast.add({ severity: 'success', summary: 'Stock Adjusted', life: 2000 })
    showStockAdjust.value = false
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function generateBarcode(product) {
  try {
    const data = await api.get(`/api/barcode/generate?product_id=${product.id}`)
    if (data.generated) {
      toast.add({ severity: 'success', summary: 'Barcode Generated', detail: data.barcode, life: 3000 })
      await loadProducts()
    } else {
      toast.add({ severity: 'info', summary: 'Already has barcode', detail: data.barcode, life: 2000 })
    }
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  }
}

async function deleteProduct(product) {
  if (!confirm(`Delete "${product.name}"?`)) return
  try {
    await api.delete(`/api/products/${product.id}`)
    toast.add({ severity: 'success', summary: 'Deleted', life: 2000 })
    await loadProducts()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
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
    toast.add({ severity: 'success', summary: 'Print command sent', life: 2000 })
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Print failed', detail: e.message, life: 3000 })
  }
}

function formatPrice(n) { return parseFloat(n || 0).toFixed(2) }
function stockLabel(qty) {
  if (qty < 0) return `Oversold (${qty})`
  if (qty === 0) return 'Out of Stock'
  if (qty <= 5) return `Low (${qty})`
  return `${qty} in stock`
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
