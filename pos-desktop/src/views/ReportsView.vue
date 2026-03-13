<template>
  <div class="reports-view">
    <div class="view-header">
      <div>
        <h1 class="view-title">Отчёты</h1>
        <p class="view-subtitle">{{ selectedDate }}</p>
      </div>
      <div class="header-actions">
        <Select
          v-if="session.user?.role !== 'cashier'"
          v-model="selectedWarehouseId"
          :options="[{ id: null, name: 'Все склады' }, ...warehouses]"
          option-label="name"
          option-value="id"
          placeholder="Склад"
          style="width:160px"
          @change="loadAll"
        />
        <DatePicker v-model="dateFilter" date-format="yy-mm-dd" @date-select="loadAll" />
        <Button label="Экспорт CSV" icon="pi pi-download" class="p-button-secondary" @click="exportCSV" />
      </div>
    </div>

    <!-- Summary Cards -->
    <div class="summary-cards" v-if="daily">
      <div class="stat-card">
        <div class="stat-label">Транзакции</div>
        <div class="stat-value font-mono gradient-text">{{ daily.summary?.transaction_count || 0 }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Валовые продажи</div>
        <div class="stat-value font-mono gradient-text">{{ formatAmount(daily.summary?.gross_sales) }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Чистые продажи</div>
        <div class="stat-value font-mono gradient-text">{{ formatAmount(daily.summary?.net_sales) }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Ср. / Транзакция</div>
        <div class="stat-value font-mono gradient-text">{{ formatAmount(daily.summary?.avg_transaction) }}</div>
      </div>
    </div>

    <div class="reports-grid">
      <!-- Hourly Chart -->
      <div class="card report-card">
        <h3 class="card-title">Продажи по часам</h3>
        <Chart type="bar" :data="hourlyChartData" :options="chartOptions" style="height:200px" />
      </div>

      <!-- Payment Methods -->
      <div class="card report-card">
        <h3 class="card-title">Способы оплаты</h3>
        <Chart v-if="daily?.by_method?.length" type="doughnut" :data="methodChartData" :options="pieOptions" style="height:200px" />
        <div v-else class="empty-chart">Нет данных</div>
      </div>
    </div>

    <!-- Top Products -->
    <div class="card" style="margin-bottom: 15px;">
      <div class="card-header">
        <h3 class="card-title">Топ товаров</h3>
      </div>
      <DataTable :value="topProducts" scrollable scroll-height="flex" :loading="loading">
        <Column field="name" header="Товар" />
        <Column field="total_qty" header="Продано" style="width:100px" />
        <Column field="total_revenue" header="Выручка" style="width:130px">
          <template #body="{ data }">
            <span class="font-mono">{{ formatAmount(data.total_revenue) }}</span>
          </template>
        </Column>
        <Column field="gross_profit" header="Прибыль" style="width:120px">
          <template #body="{ data }">
            <span class="font-mono text-success">{{ formatAmount(data.gross_profit) }}</span>
          </template>
        </Column>
      </DataTable>
    </div>

    <!-- Transactions List (with refund button) -->
    <div class="card" style="flex:1;overflow:hidden;display:flex;flex-direction:column">
      <div class="card-header">
        <h3 class="card-title">Транзакции</h3>
      </div>
      <DataTable :value="transactions" scrollable scroll-height="flex" :loading="loading">
        <Column field="ref_no" header="Номер">
          <template #body="{ data }">
            <span class="font-mono" style="font-size:12px">{{ data.ref_no }}</span>
          </template>
        </Column>
        <Column field="cashier_name" header="Кассир" />
        <Column field="total" header="Итого" style="width:110px">
          <template #body="{ data }">
            <span class="font-mono">{{ formatAmount(data.total) }}</span>
          </template>
        </Column>
        <Column field="payment_method" header="Способ" style="width:90px" />
        <Column field="status" header="Статус" style="width:130px">
          <template #body="{ data }">
            <Tag :value="data.status" :severity="statusSeverity(data.status)" />
          </template>
        </Column>
        <Column field="created_at" header="Время" style="width:100px">
          <template #body="{ data }">
            <span class="font-mono" style="font-size:12px">{{ formatTime(data.created_at) }}</span>
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

    <!-- Refund Dialog -->
    <RefundDialog
      v-model="showRefund"
      :transaction-id="refundTxnId"
      @refunded="loadAll"
    />

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useSessionStore } from '../stores/session.js'
import { useToast } from 'primevue/usetoast'
import RefundDialog from '../components/RefundDialog.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import Select from 'primevue/select'
import Tag from 'primevue/tag'
import Chart from 'primevue/chart'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()
const session = useSessionStore()

const dateFilter = ref(new Date())
const daily = ref(null)
const topProducts = ref([])
const transactions = ref([])
const loading = ref(false)
const showRefund = ref(false)
const refundTxnId = ref(null)
const warehouses = ref([])
const selectedWarehouseId = ref(null)

const selectedDate = computed(() => {
  return dateFilter.value?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0]
})

onMounted(async () => {
  try {
    warehouses.value = await api.get('/api/warehouses')
    // Cashier defaults to their own warehouse
    if (session.user?.role === 'cashier') {
      selectedWarehouseId.value = session.user.warehouse_id || null
    }
  } catch (e) {}
  await loadAll()
})

async function loadAll() {
  loading.value = true
  try {
    const date = selectedDate.value
    const wq = selectedWarehouseId.value ? `&warehouse_id=${selectedWarehouseId.value}` : ''
    const [dailyData, topData, txnData] = await Promise.all([
      api.get(`/api/reports/daily?date=${date}${wq}`),
      api.get(`/api/reports/products?from=${date}&to=${date}${wq}`),
      api.get(`/api/transactions?from=${date}T00:00:00&to=${date}T23:59:59&limit=100`)
    ])
    daily.value = dailyData
    topProducts.value = topData
    transactions.value = txnData.data || txnData
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const hourlyChartData = computed(() => {
  const hours = daily.value?.by_hour || []
  return {
    labels: hours.map(h => `${String(h.hour).padStart(2,'0')}:00`),
    datasets: [{
      label: 'Продажи',
      data: hours.map(h => parseFloat(h.sales)),
      backgroundColor: 'rgba(123,104,238,0.5)',
      borderColor: '#7b68ee',
      borderWidth: 2,
      borderRadius: 6
    }]
  }
})

const methodChartData = computed(() => {
  const methods = daily.value?.by_method || []
  const colors = ['#7b68ee', '#00d4aa', '#ffb02e']
  return {
    labels: methods.map(m => m.payment_method),
    datasets: [{
      data: methods.map(m => parseFloat(m.total)),
      backgroundColor: colors
    }]
  }
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: {
    x: { ticks: { color: '#9898bb' }, grid: { color: 'rgba(255,255,255,0.05)' } },
    y: { ticks: { color: '#9898bb' }, grid: { color: 'rgba(255,255,255,0.05)' } }
  }
}

const pieOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { position: 'right', labels: { color: '#9898bb' } } }
}

function openRefund(txn) {
  refundTxnId.value = txn.id
  showRefund.value = true
}

function formatAmount(n) { return parseFloat(n || 0).toFixed(2) }
function formatTime(dt) {
  return dt ? new Date(dt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) : '—'
}

function statusSeverity(status) {
  const map = { completed: 'success', refunded: 'secondary', partially_refunded: 'warn', voided: 'danger' }
  return map[status] || 'secondary'
}

function exportCSV() {
  const rows = transactions.value.map(t => [t.ref_no, t.cashier_name, t.total, t.payment_method, t.status, t.created_at].join(','))
  const csv = ['Ref No,Cashier,Total,Method,Status,Date', ...rows].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `report-${selectedDate.value}.csv`
  a.click()
}
</script>

<style scoped>
.reports-view {
  padding: 20px;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.view-title { font-size: 24px; font-weight: 800; color: var(--text-primary); }
.view-subtitle { font-size: 13px; color: var(--text-muted); margin-top: 2px; }
.header-actions { display: flex; gap: 10px; }

.summary-cards {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  margin-bottom: 15px;
}

.stat-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 16px 20px;
}

.stat-label { font-size: 12px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 8px; }
.stat-value { font-size: 24px; font-weight: 700; }

.reports-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-bottom: 15px;
}

.report-card {
  padding: 16px;
}

.card-header {
  padding: 12px;
}

.card-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: 12px;
}

.empty-chart {
  height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
}
</style>
