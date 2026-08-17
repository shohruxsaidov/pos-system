<template>
  <div class="txn-view">
    <div class="view-header">
      <div>
        <h1 class="view-title">Транзакции</h1>
        <p class="view-subtitle">{{ total }} записей</p>
      </div>
      <div class="header-actions">
        <IconField>
          <InputIcon class="pi pi-search" />
          <InputText v-model="search" placeholder="Номер / Кассир" @input="onSearchInput" />
        </IconField>
        <Select
          v-model="statusFilter"
          :options="statusOptions"
          option-label="label"
          option-value="value"
          placeholder="Все статусы"
          style="width:160px"
          @change="load(1)"
        />
        <DatePicker v-model="dateFrom" date-format="yy-mm-dd" placeholder="От" @date-select="load(1)" />
        <DatePicker v-model="dateTo" date-format="yy-mm-dd" placeholder="До" @date-select="load(1)" />
        <Button label="Экспорт CSV" icon="pi pi-download" class="p-button-secondary" @click="exportCSV" />
      </div>
    </div>

    <div class="card" style="flex:1;overflow:hidden;display:flex;flex-direction:column">
      <DataTable
        :value="transactions"
        :loading="loading"
        scrollable
        scroll-height="flex"
        lazy
        :rows="pageSize"
        :total-records="total"
        paginator
        :rows-per-page-options="[25, 50, 100]"
        @page="onPage"
        v-model:first="firstRow"
      >
        <Column field="ref_no" header="Номер" style="width:180px">
          <template #body="{ data }">
            <span class="font-mono" style="font-size:12px" v-html="highlight(data.ref_no)" />
          </template>
        </Column>
        <Column field="cashier_name" header="Кассир">
          <template #body="{ data }">
            <span v-html="highlight(data.cashier_name || '')" />
          </template>
        </Column>
        <Column field="customer_name" header="Клиент">
          <template #body="{ data }">
            <span style="color:var(--text-secondary)" v-html="highlight(data.customer_name || '—')" />
          </template>
        </Column>
        <Column field="total" header="Итого" style="width:120px">
          <template #body="{ data }">
            <span class="font-mono">{{ formatAmount(data.total) }}</span>
          </template>
        </Column>
        <Column field="payment_method" header="Способ" style="width:100px" />
        <Column field="status" header="Статус" style="width:150px">
          <template #body="{ data }">
            <Tag :value="statusLabel(data.status)" :severity="statusSeverity(data.status)" />
          </template>
        </Column>
        <Column field="created_at" header="Дата / Время" style="width:140px">
          <template #body="{ data }">
            <span class="font-mono" style="font-size:12px">{{ formatDateTime(data.created_at) }}</span>
          </template>
        </Column>
        <Column header="" style="width:160px">
          <template #body="{ data }">
            <div style="display:flex;gap:6px">
              <Button
                label="Детали"
                icon="pi pi-eye"
                class="p-button-secondary"
                style="height:32px;font-size:12px"
                @click="openDetails(data)"
              />
              <Button
                v-if="data.status === 'completed' || data.status === 'partially_refunded'"
                label="Возврат"
                class="p-button-secondary"
                style="height:32px;font-size:12px"
                @click="openRefund(data)"
              />
            </div>
          </template>
        </Column>
      </DataTable>
    </div>

    <!-- Transaction Details Modal -->
    <Dialog v-model:visible="showDetails" modal header="Детали транзакции" :style="{ width: '560px' }">
      <div v-if="detailsLoading" class="details-loading">
        <i class="pi pi-spin pi-spinner" style="font-size:24px;color:var(--accent-1)" />
      </div>
      <div v-else-if="detailsTxn" class="details-body">
        <!-- Header info -->
        <div class="details-meta">
          <div class="details-row">
            <span class="details-label">Номер</span>
            <span class="font-mono details-ref">{{ detailsTxn.ref_no }}</span>
          </div>
          <div class="details-row">
            <span class="details-label">Дата</span>
            <span class="font-mono">{{ formatDateTime(detailsTxn.created_at) }}</span>
          </div>
          <div class="details-row">
            <span class="details-label">Кассир</span>
            <span>{{ detailsTxn.cashier_name || '—' }}</span>
          </div>
          <div class="details-row">
            <span class="details-label">Клиент</span>
            <span>{{ detailsTxn.customer_name || '—' }}</span>
          </div>
          <div class="details-row">
            <span class="details-label">Статус</span>
            <Tag :value="statusLabel(detailsTxn.status)" :severity="statusSeverity(detailsTxn.status)" />
          </div>
        </div>

        <!-- Payments -->
        <div class="details-section-title">Платежи</div>
        <div class="details-payments">
          <div v-for="(p, i) in detailsTxn.payments" :key="i" class="payment-row">
            <div class="payment-method-badge" :class="p.method">
              {{ methodLabel(p.method) }}
            </div>
            <div class="payment-info">
              <span class="font-mono payment-amount">{{ formatAmount(p.amount) }}</span>
              <span v-if="p.change_given > 0" class="payment-change font-mono">сдача {{ formatAmount(p.change_given) }}</span>
              <span v-if="p.reference" class="payment-ref">{{ p.reference }}</span>
            </div>
          </div>
        </div>

        <!-- Items -->
        <div class="details-section-title">Товары</div>
        <div class="details-items">
          <div v-for="item in detailsTxn.items" :key="item.id" class="detail-item">
            <div class="detail-item-name">{{ item.name || item.product_name }}</div>
            <div class="detail-item-right">
              <span class="detail-item-qty font-mono">× {{ item.qty }}</span>
              <span class="detail-item-price font-mono">{{ formatAmount(item.unit_price) }}</span>
              <span class="detail-item-sub font-mono">= {{ formatAmount(item.subtotal) }}</span>
            </div>
          </div>
        </div>

        <!-- Totals -->
        <div class="details-totals">
          <div class="details-row" v-if="detailsTxn.discount > 0">
            <span class="details-label">Скидка</span>
            <span class="font-mono">{{ formatAmount(detailsTxn.discount) }}</span>
          </div>
          <div class="details-row" v-if="detailsTxn.tax > 0">
            <span class="details-label">Налог</span>
            <span class="font-mono">{{ formatAmount(detailsTxn.tax) }}</span>
          </div>
          <div class="details-row details-total-row">
            <span class="details-label">Итого</span>
            <span class="font-mono details-total-val">{{ formatAmount(detailsTxn.total) }}</span>
          </div>
        </div>
      </div>
    </Dialog>

    <RefundDialog v-model="showRefund" :transaction-id="refundTxnId" @refunded="load(currentPage)" />
    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import RefundDialog from '../components/RefundDialog.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import Select from 'primevue/select'
import Tag from 'primevue/tag'
import Toast from 'primevue/toast'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import InputText from 'primevue/inputtext'
import Dialog from 'primevue/dialog'

const api = useApi()
const toast = useToast()

const transactions = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(50)
const firstRow = ref(0)

const search = ref('')
const statusFilter = ref(null)
const dateFrom = ref(null)
const dateTo = ref(null)

let searchDebounce = null

const statusOptions = [
  { label: 'Все статусы', value: null },
  { label: 'Завершена', value: 'completed' },
  { label: 'Возврат', value: 'refunded' },
  { label: 'Частичный возврат', value: 'partially_refunded' },
  { label: 'Отменена', value: 'voided' },
]

const showRefund = ref(false)
const refundTxnId = ref(null)

const showDetails = ref(false)
const detailsTxn = ref(null)
const detailsLoading = ref(false)

onMounted(() => load(1))

async function load(page = 1) {
  loading.value = true
  currentPage.value = page
  firstRow.value = (page - 1) * pageSize.value
  try {
    const params = new URLSearchParams({
      page,
      limit: pageSize.value,
    })
    if (search.value.trim()) params.set('search', search.value.trim())
    if (statusFilter.value) params.set('status', statusFilter.value)
    if (dateFrom.value) params.set('from', fmtDate(dateFrom.value) + 'T00:00:00')
    if (dateTo.value) params.set('to', fmtDate(dateTo.value) + 'T23:59:59')

    const res = await api.get(`/api/transactions?${params}`)
    transactions.value = res.data || res
    total.value = res.total || transactions.value.length
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

function onSearchInput() {
  clearTimeout(searchDebounce)
  searchDebounce = setTimeout(() => load(1), 350)
}

function onPage(e) {
  pageSize.value = e.rows
  firstRow.value = e.first
  load(e.page + 1)
}

function openRefund(txn) {
  refundTxnId.value = txn.id
  showRefund.value = true
}

async function openDetails(txn) {
  detailsTxn.value = null
  detailsLoading.value = true
  showDetails.value = true
  try {
    detailsTxn.value = await api.get(`/api/transactions/${txn.id}`)
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
    showDetails.value = false
  } finally {
    detailsLoading.value = false
  }
}

function fmtDate(d) {
  if (!(d instanceof Date)) return d
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function formatAmount(n) { return parseFloat(n || 0).toFixed(2) }

function formatDateTime(dt) {
  if (!dt) return '—'
  const d = new Date(dt)
  return `${d.toLocaleDateString('ru')} ${d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })}`
}

function methodLabel(m) {
  const map = { cash: 'Наличные', card: 'Карта', transfer: 'Перевод', mixed: 'Смешанная' }
  return map[m] || m
}

function statusLabel(s) {
  const map = { completed: 'Завершена', refunded: 'Возврат', partially_refunded: 'Частичный', voided: 'Отменена' }
  return map[s] || s
}

function statusSeverity(s) {
  const map = { completed: 'success', refunded: 'secondary', partially_refunded: 'warn', voided: 'danger' }
  return map[s] || 'secondary'
}

function highlight(text) {
  if (!search.value || !text) return text
  const escaped = search.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return String(text).replace(new RegExp(`(${escaped})`, 'gi'), '<mark class="search-highlight">$1</mark>')
}

function exportCSV() {
  const rows = transactions.value.map(t =>
    [t.ref_no, t.cashier_name, t.customer_name || '', t.total, t.payment_method, t.status, t.created_at].join(',')
  )
  const csv = ['Ref No,Cashier,Customer,Total,Method,Status,Date', ...rows].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `transactions-${new Date().toISOString().split('T')[0]}.csv`
  a.click()
}
</script>

<style scoped>
.txn-view {
  padding: 20px;
  display: flex;
  flex-direction: column;
  height: 100%;
  gap: 15px;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.view-title { font-size: 24px; font-weight: 800; color: var(--text-primary); }
.view-subtitle { font-size: 13px; color: var(--text-muted); margin-top: 2px; }
.header-actions { display: flex; gap: 10px; align-items: center; }

:deep(.search-highlight) {
  background: rgba(255, 214, 0, 0.30);
  color: #ffd600;
  border-radius: 3px;
  padding: 0 2px;
  font-weight: 700;
}

/* Details modal */
.details-loading {
  display: flex;
  justify-content: center;
  padding: 40px;
}

.details-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.details-meta {
  display: flex;
  flex-direction: column;
  gap: 8px;
  background: var(--bg-elevated);
  border-radius: 10px;
  padding: 14px 16px;
}

.details-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 13px;
}

.details-label {
  color: var(--text-secondary);
  font-weight: 500;
}

.details-ref {
  font-size: 12px;
  color: var(--text-accent);
}

.details-section-title {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-muted);
}

.details-items {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.detail-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  background: var(--bg-elevated);
  border-radius: 8px;
  font-size: 13px;
}

.detail-item-name {
  color: var(--text-primary);
  font-weight: 500;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-right: 12px;
}

.detail-item-right {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-shrink: 0;
}

.detail-item-qty  { color: var(--text-muted); font-size: 12px; }
.detail-item-price { color: var(--text-secondary); font-size: 12px; }
.detail-item-sub  { color: var(--text-primary); font-weight: 600; }

.details-totals {
  display: flex;
  flex-direction: column;
  gap: 6px;
  border-top: 1px solid var(--border-subtle);
  padding-top: 12px;
}

.details-total-row {
  margin-top: 4px;
}

.details-total-val {
  font-size: 18px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* Payments section */
.details-payments {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.payment-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  background: var(--bg-elevated);
  border-radius: 8px;
}

.payment-method-badge {
  font-size: 12px;
  font-weight: 700;
  padding: 4px 10px;
  border-radius: 6px;
  white-space: nowrap;
  background: var(--bg-surface);
  color: var(--text-secondary);
  border: 1px solid var(--border-subtle);
}

.payment-method-badge.cash {
  background: rgba(0, 212, 170, 0.10);
  color: var(--success);
  border-color: rgba(0, 212, 170, 0.20);
}

.payment-method-badge.card {
  background: rgba(123, 104, 238, 0.12);
  color: var(--text-accent);
  border-color: rgba(123, 104, 238, 0.25);
}

.payment-method-badge.transfer {
  background: rgba(255, 176, 46, 0.10);
  color: var(--warning);
  border-color: rgba(255, 176, 46, 0.20);
}

.payment-info {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
}

.payment-amount {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-primary);
}

.payment-change {
  font-size: 12px;
  color: var(--text-muted);
}

.payment-ref {
  font-size: 12px;
  color: var(--text-accent);
  font-family: var(--font-mono);
  margin-left: auto;
}
</style>
