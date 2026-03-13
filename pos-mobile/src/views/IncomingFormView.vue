<template>
  <div class="incoming-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Приёмка товара</h1>
        <div class="reader-status" :class="{ ready: readerReady }">
          <div class="reader-dot" />
          {{ readerReady ? 'Сканер готов' : 'Нажмите для активации' }}
        </div>
      </div>
      <div class="header-right">
        <span class="item-count font-mono">{{ items.length }} позиций</span>
        <button class="logout-btn" @click="logout">
          <i class="pi pi-sign-out" />
        </button>
      </div>
    </div>

    <!-- Hidden barcode input (always focused) -->
    <input
      ref="barcodeInput"
      v-model="barcodeBuffer"
      class="hidden-barcode"
      @keydown.enter="handleBarcodeScan"
      @focus="readerReady = true"
      @blur="readerReady = false"
      autocomplete="off"
      autocorrect="off"
      autocapitalize="off"
      spellcheck="false"
    />

    <!-- Supplier / Notes -->
    <div class="receipt-meta">
      <input v-model="supplier" class="meta-input" placeholder="Поставщик (необязательно)" />
      <input v-model="notes" class="meta-input" placeholder="Примечания (необязательно)" />
    </div>

    <!-- Item Cards -->
    <div class="items-list" @click="focusBarcodeInput">
      <div v-if="items.length === 0" class="empty-state">
        <i class="pi pi-barcode" style="font-size:48px;color:var(--text-muted)" />
        <p>Отсканируйте штрихкод для добавления</p>
      </div>
      <IncomingItemCard
        v-for="(item, idx) in items"
        :key="idx"
        :item="item"
        @remove="removeItem(idx)"
        @edit-field="(field, val) => openNumpadForField(idx, field, val)"
        @edit-expiry="() => openExpiryPicker(idx)"
      />
    </div>

    <!-- Footer -->
    <div class="view-footer">
      <div class="total-display">
        <span class="text-secondary">Итого</span>
        <span class="font-mono gradient-text" style="font-size:22px;font-weight:700">
          {{ formatAmount(totalCost) }}
        </span>
      </div>
      <button class="confirm-btn" :disabled="items.length === 0 || confirming" @click="confirmReceipt">
        <span v-if="confirming"><i class="pi pi-spin pi-spinner" /> Сохранение...</span>
        <span v-else>Подтвердить приёмку ({{ items.length }} поз.)</span>
      </button>
    </div>

    <!-- Numpad for field editing -->
    <BottomNumPad
      :visible="numpadVisible"
      v-model="numpadValue"
      :label="numpadLabel"
      :integer="numpadInteger"
      @close="numpadVisible = false"
      @confirm="applyNumpadValue"
    />

    <!-- Product Not Found -->
    <ProductNotFound
      :visible="showNotFound"
      :barcode="scannedBarcode"
      @close="showNotFound = false"
      @skip="showNotFound = false"
      @created="addManualProduct"
    />

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useWarehouseStore } from '../stores/warehouse.js'
import { useToast } from 'primevue/usetoast'
import IncomingItemCard from '../components/IncomingItemCard.vue'
import BottomNumPad from '../components/BottomNumPad.vue'
import ProductNotFound from '../components/ProductNotFound.vue'
import Toast from 'primevue/toast'

const router = useRouter()
const store = useWarehouseStore()
const toast = useToast()

const items = ref([])
const supplier = ref('')
const notes = ref('')
const confirming = ref(false)
const barcodeInput = ref(null)
const barcodeBuffer = ref('')
const readerReady = ref(false)

const numpadVisible = ref(false)
const numpadValue = ref('')
const numpadLabel = ref('')
const numpadInteger = ref(true)
const numpadEditIdx = ref(null)
const numpadEditField = ref(null)

const showNotFound = ref(false)
const scannedBarcode = ref('')

const totalCost = computed(() =>
  items.value.reduce((sum, i) => sum + (i.qty_received || 0) * (i.cost_per_unit || 0), 0)
)

onMounted(() => {
  focusBarcodeInput()
})

function focusBarcodeInput() {
  barcodeInput.value?.focus()
}

async function handleBarcodeScan() {
  const barcode = barcodeBuffer.value.trim()
  barcodeBuffer.value = ''
  if (!barcode) return

  try {
    const res = await store.authFetch(`/api/products/barcode/${encodeURIComponent(barcode)}`)
    if (!res.ok) {
      scannedBarcode.value = barcode
      showNotFound.value = true
      return
    }
    const product = await res.json()
    addProductToList(product)
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  }
}

function addProductToList(product) {
  const existing = items.value.find(i => i.product_id === product.id)
  if (existing) {
    existing.qty_received = (existing.qty_received || 0) + 1
    toast.add({ severity: 'info', summary: 'Количество обновлено', detail: product.name, life: 1500 })
  } else {
    items.value.unshift({
      product_id: product.id,
      product_name: product.name,
      barcode: product.barcode,
      qty_received: 1,
      cost_per_unit: parseFloat(product.cost || 0),
      expiry_date: null
    })
    toast.add({ severity: 'success', summary: 'Добавлено', detail: product.name, life: 1500 })
  }
  focusBarcodeInput()
}

function addManualProduct(productData) {
  items.value.unshift({
    product_id: null,
    product_name: productData.name,
    barcode: productData.barcode,
    qty_received: 1,
    cost_per_unit: parseFloat(productData.price || 0),
    expiry_date: null
  })
  showNotFound.value = false
  focusBarcodeInput()
}

function removeItem(idx) {
  items.value.splice(idx, 1)
}

function openNumpadForField(idx, field, currentVal) {
  numpadEditIdx.value = idx
  numpadEditField.value = field
  numpadValue.value = String(currentVal || '')
  numpadLabel.value = field === 'qty' ? 'Количество' : 'Цена за единицу'
  numpadInteger.value = field === 'qty'
  numpadVisible.value = true
}

function applyNumpadValue(val) {
  const idx = numpadEditIdx.value
  const field = numpadEditField.value
  if (idx === null || !field) return
  if (field === 'qty') items.value[idx].qty_received = parseInt(val) || 0
  if (field === 'cost') items.value[idx].cost_per_unit = parseFloat(val) || 0
}

function openExpiryPicker(idx) {
  const date = prompt('Введите дату истечения (ГГГГ-ММ-ДД):')
  if (date) items.value[idx].expiry_date = date
}

async function confirmReceipt() {
  if (items.value.length === 0 || confirming.value) return
  confirming.value = true

  try {
    const res = await store.authFetch('/api/incoming', {
      method: 'POST',
      body: JSON.stringify({
        supplier: supplier.value,
        notes: notes.value,
        items: items.value
      })
    })

    const data = await res.json()
    if (!res.ok) throw new Error(data.error)

    toast.add({ severity: 'success', summary: 'Приёмка подтверждена', detail: `${data.ref_no} — ${formatAmount(data.total_cost)}`, life: 4000 })
    items.value = []
    supplier.value = ''
    notes.value = ''
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 4000 })
  } finally {
    confirming.value = false
    focusBarcodeInput()
  }
}

function logout() {
  store.logout()
  router.push('/login')
}

function formatAmount(n) { return parseFloat(n || 0).toFixed(2) }
</script>

<style scoped>
.incoming-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 16px 16px 10px;
  flex-shrink: 0;
}

.view-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }

.reader-status {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 4px;
}

.reader-status.ready { color: var(--success); }

.reader-dot {
  width: 8px; height: 8px;
  border-radius: 50%;
  background: var(--text-muted);
}

.reader-status.ready .reader-dot {
  background: var(--success);
  box-shadow: 0 0 8px var(--success);
  animation: pulse-glow 2s infinite;
}

@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 4px var(--success); }
  50% { box-shadow: 0 0 12px var(--success); }
}

.header-right { display: flex; align-items: center; gap: 10px; }
.item-count { font-size: 14px; color: var(--text-accent); }

.logout-btn {
  width: 40px; height: 40px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  color: var(--text-muted);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.hidden-barcode {
  position: absolute;
  opacity: 0;
  width: 1px;
  height: 1px;
  pointer-events: none;
}

.receipt-meta {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 0 16px 10px;
  flex-shrink: 0;
}

.meta-input {
  height: 52px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-primary);
  font-size: 15px;
  padding: 0 16px;
  font-family: var(--font-sans);
}

.meta-input::placeholder { color: var(--text-muted); }

.items-list {
  flex: 1;
  overflow-y: auto;
  padding: 0 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  -webkit-overflow-scrolling: touch;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 60px 20px;
  color: var(--text-muted);
  font-size: 15px;
}

.view-footer {
  padding: 12px 16px;
  padding-bottom: calc(12px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--border-subtle);
  background: var(--bg-sidebar);
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex-shrink: 0;
}

.total-display {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.confirm-btn {
  height: 64px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 16px;
  color: #fff;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 4px 20px rgba(123,104,238,0.35);
}

.confirm-btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
