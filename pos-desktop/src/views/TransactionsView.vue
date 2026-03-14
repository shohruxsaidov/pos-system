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
            <span class="font-mono" style="font-size:12px">{{ data.ref_no }}</span>
          </template>
        </Column>
        <Column field="cashier_name" header="Кассир" />
        <Column field="customer_name" header="Клиент">
          <template #body="{ data }">
            <span style="color:var(--text-secondary)">{{ data.customer_name || '—' }}</span>
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
        <Column header="" style="width:90px">
          <template #body="{ data }">
            <Button
              v-if="data.status === 'completed' || data.status === 'partially_refunded'"
              label="Возврат"
              class="p-button-secondary"
              style="height:32px;font-size:12px"
              @click="openRefund(data)"
            />
          </template>
        </Column>
      </DataTable>
    </div>

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

onMounted(() => load(1))

async function load(page = 1) {
  loading.value = true
  currentPage.value = page
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

function fmtDate(d) {
  return d instanceof Date ? d.toISOString().split('T')[0] : d
}

function formatAmount(n) { return parseFloat(n || 0).toFixed(2) }

function formatDateTime(dt) {
  if (!dt) return '—'
  const d = new Date(dt)
  return `${d.toLocaleDateString('ru')} ${d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })}`
}

function statusLabel(s) {
  const map = { completed: 'Завершена', refunded: 'Возврат', partially_refunded: 'Частичный', voided: 'Отменена' }
  return map[s] || s
}

function statusSeverity(s) {
  const map = { completed: 'success', refunded: 'secondary', partially_refunded: 'warn', voided: 'danger' }
  return map[s] || 'secondary'
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
</style>
