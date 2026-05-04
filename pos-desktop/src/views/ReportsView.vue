<template>
  <div class="reports-view">
    <div class="view-header">
      <div>
        <h1 class="view-title">Отчёты</h1>
        <p class="view-subtitle">{{ selectedDate }}</p>
      </div>
      <div class="header-actions">
        <div class="actions-row">
          <Select v-if="session.user?.role !== 'cashier'" v-model="selectedWarehouseId"
            :options="[{ id: null, name: 'Все склады' }, ...warehouses]" option-label="name" option-value="id"
            placeholder="Склад" style="width:160px" @change="loadAll" />
          <SelectButton v-model="reportPeriod" :options="periodOptions" option-label="label" option-value="value"
            @change="onPeriodChange" />
          <DatePicker v-if="reportPeriod !== 'range'" v-model="dateFilter" date-format="yy-mm-dd"
            @date-select="loadAll" />
          <DatePicker v-else v-model="dateRangeFilter" selection-mode="range" date-format="yy-mm-dd"
            placeholder="Выберите период" :number-of-months="2" @date-select="onRangeSelect" style="width:260px" />
        </div>
        <div class="actions-row">
          <Button label="Экспорт CSV" icon="pi pi-download" class="p-button-secondary" @click="exportCSV" />
          <Button label="X-Отчёт" icon="pi pi-chart-bar" class="p-button-secondary" @click="showXReport = true" />
          <Button v-if="session.user?.role !== 'cashier'" label="Z-Отчёт" icon="pi pi-lock" severity="danger"
            @click="showZReport = true" />
        </div>
      </div>
    </div>

    <!-- Summary Cards -->
    <div class="summary-cards" v-if="daily">
      <div class="stat-card">
        <div class="stat-label">Транзакции</div>
        <div class="stat-value font-mono gradient-text">{{ daily.summary?.transaction_count || 0 }}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Чистые продажи</div>
        <div class="stat-value font-mono gradient-text">{{ formatAmount(daily.summary?.net_sales) }}</div>
      </div>
      <div class="stat-card" v-if="daily.summary?.total_discount > 0">
        <div class="stat-label">Скидки</div>
        <div class="stat-value font-mono" style="color:var(--danger)">− {{ formatAmount(daily.summary?.total_discount)
        }}</div>
      </div>
    </div>

    <div class="reports-grid">
      <!-- Hourly Chart — only for daily period -->
      <div v-if="reportPeriod === 'day'" class="card report-card">
        <h3 class="card-title">Продажи по часам</h3>
        <Chart type="bar" :data="hourlyChartData" :options="chartOptions" style="height:200px" />
      </div>

      <!-- Payment Methods -->
      <div class="card report-card" :style="reportPeriod !== 'day' ? 'grid-column: 1 / -1' : ''">
        <h3 class="card-title">Способы оплаты</h3>
        <template v-if="daily?.by_method?.length">
          <Chart type="doughnut" :data="methodChartData" :options="pieOptions" style="height:200px" />
          <div class="method-breakdown">
            <div v-for="m in daily.by_method" :key="m.payment_method" class="method-row">
              <span class="method-dot" :style="{ background: methodColor(m.payment_method) }"></span>
              <span class="method-name">{{ methodLabel(m.payment_method) }}</span>
              <span class="method-amount font-mono">{{ formatAmount(m.total) }}</span>
            </div>
          </div>
        </template>
        <div v-else class="empty-chart">Нет данных</div>
      </div>
    </div>

    <!-- Cashiers Breakdown -->
    <div v-if="session.user?.role !== 'cashier'" class="card" style="margin-bottom: 15px;">
      <div class="card-header">
        <h3 class="card-title">Кассиры</h3>
      </div>
      <DataTable :value="cashiers" :loading="loading" size="small">
        <Column field="name" header="Кассир" />
        <Column field="transaction_count" header="Транзакции" style="width:110px" />
        <Column field="total_sales" header="Продажи" style="width:130px">
          <template #body="{ data }">
            <span class="font-mono">{{ formatAmount(data.total_sales) }}</span>
          </template>
        </Column>
        <Column field="avg_transaction" header="Ср/Транзакция" style="width:130px">
          <template #body="{ data }">
            <span class="font-mono">{{ formatAmount(data.avg_transaction) }}</span>
          </template>
        </Column>
        <Column field="first_sale" header="Первая" style="width:100px">
          <template #body="{ data }">
            <span class="font-mono" style="font-size:12px">{{ formatTime(data.first_sale) }}</span>
          </template>
        </Column>
        <Column field="last_sale" header="Последняя" style="width:100px">
          <template #body="{ data }">
            <span class="font-mono" style="font-size:12px">{{ formatTime(data.last_sale) }}</span>
          </template>
        </Column>
      </DataTable>
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



    <!-- Z-Reports History -->
    <div v-if="session.user?.role !== 'cashier'" class="card" style="margin-bottom: 15px;">
      <div class="card-header" style="display:flex;justify-content:space-between;align-items:center">
        <h3 class="card-title" style="margin-bottom:0">История Z-отчётов</h3>
        <Button :icon="showZHistory ? 'pi pi-chevron-up' : 'pi pi-chevron-down'" text size="small"
          @click="showZHistory = !showZHistory" />
      </div>
      <div v-if="showZHistory">
        <DataTable :value="zReports" :loading="loading" size="small" data-key="id">
          <Column field="report_no" header="Отчёт" style="width:130px">
            <template #body="{ data }">
              <span class="font-mono" style="font-size:12px">{{ data.report_no }}</span>
            </template>
          </Column>
          <Column header="Период">
            <template #body="{ data }">
              <span class="font-mono" style="font-size:12px">
                {{ formatDateTime(data.opened_at) }} → {{ formatDateTime(data.closed_at) }}
              </span>
            </template>
          </Column>
          <Column field="closed_by_name" header="Закрыл" style="width:120px" />
          <Column field="transaction_count" header="Транзакции" style="width:110px" />
          <Column field="net_sales" header="Чистые продажи" style="width:140px">
            <template #body="{ data }">
              <span class="font-mono">{{ formatAmount(data.net_sales) }}</span>
            </template>
          </Column>
          <Column field="refund_amount" header="Возвраты" style="width:110px">
            <template #body="{ data }">
              <span class="font-mono" style="color:var(--danger)">{{ formatAmount(data.refund_amount) }}</span>
            </template>
          </Column>
          <template #expansion="{ data }">
            <div class="z-report-expansion">
              <div v-if="data.payment_methods?.length" class="expansion-section">
                <div class="expansion-title">Способы оплаты</div>
                <DataTable :value="data.payment_methods" size="small" style="font-size:13px">
                  <Column field="method" header="Способ">
                    <template #body="{ data: row }">{{ methodLabel(row.method) }}</template>
                  </Column>
                  <Column field="count" header="Кол-во" style="width:80px" />
                  <Column field="amount" header="Сумма" style="width:120px">
                    <template #body="{ data: row }">
                      <span class="font-mono">{{ formatAmount(row.amount) }}</span>
                    </template>
                  </Column>
                </DataTable>
              </div>
              <div v-if="data.cashier_summary?.length" class="expansion-section">
                <div class="expansion-title">Кассиры</div>
                <DataTable :value="data.cashier_summary" size="small" style="font-size:13px">
                  <Column field="name" header="Кассир" />
                  <Column field="count" header="Транзакции" style="width:100px" />
                  <Column field="sales" header="Продажи" style="width:120px">
                    <template #body="{ data: row }">
                      <span class="font-mono">{{ formatAmount(row.sales) }}</span>
                    </template>
                  </Column>
                </DataTable>
              </div>
            </div>
          </template>
        </DataTable>
      </div>
    </div>

    <!-- X/Z Report Dialogs -->
    <XReportDialog v-model="showXReport" :warehouse-id="selectedWarehouseId" />
    <ZReportDialog v-model="showZReport" :warehouse-id="selectedWarehouseId" @closed="loadAll(); loadZReports()" />

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useSessionStore } from '../stores/session.js'
import { useToast } from 'primevue/usetoast'
import XReportDialog from '../components/XReportDialog.vue'
import ZReportDialog from '../components/ZReportDialog.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import Select from 'primevue/select'
import SelectButton from 'primevue/selectbutton'
import Chart from 'primevue/chart'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()
const session = useSessionStore()

const dateFilter = ref(new Date())
const dateRangeFilter = ref(null)
const reportPeriod = ref('day')
const periodOptions = [
  { label: 'День', value: 'day' },
  { label: 'Неделя', value: 'week' },
  { label: 'Месяц', value: 'month' },
  { label: 'Диапазон', value: 'range' },
]
const daily = ref(null)
const topProducts = ref([])
const loading = ref(false)
const showXReport = ref(false)
const showZReport = ref(false)
const warehouses = ref([])
const selectedWarehouseId = ref(null)
const cashiers = ref([])
const zReports = ref([])
const showZHistory = ref(false)
const expandedZRows = ref({})

function fmtLocalDate(d) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const dateRange = computed(() => {
  if (reportPeriod.value === 'range') {
    const [from, to] = dateRangeFilter.value || []
    if (from && to) return { from: fmtLocalDate(from), to: fmtLocalDate(to) }
    const today = fmtLocalDate(new Date())
    return { from: today, to: today }
  }
  const d = dateFilter.value ? new Date(dateFilter.value) : new Date()
  if (reportPeriod.value === 'week') {
    const dayOfWeek = (d.getDay() + 6) % 7
    const monday = new Date(d)
    monday.setDate(d.getDate() - dayOfWeek)
    const sunday = new Date(monday)
    sunday.setDate(monday.getDate() + 6)
    return { from: fmtLocalDate(monday), to: fmtLocalDate(sunday) }
  } else if (reportPeriod.value === 'month') {
    const firstDay = new Date(d.getFullYear(), d.getMonth(), 1)
    const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0)
    return { from: fmtLocalDate(firstDay), to: fmtLocalDate(lastDay) }
  }
  const day = fmtLocalDate(d)
  return { from: day, to: day }
})

const selectedDate = computed(() => {
  const { from, to } = dateRange.value
  return from === to ? from : `${from} — ${to}`
})

const totalGrossProfit = computed(() =>
  topProducts.value.reduce((s, p) => s + +p.gross_profit, 0)
)

onMounted(async () => {
  try {
    warehouses.value = await api.get('/api/warehouses')
    // Cashier defaults to their own warehouse
    if (session.user?.role === 'cashier') {
      selectedWarehouseId.value = session.user.warehouse_id || null
    }
  } catch (e) { }
  await loadAll()
  if (session.user?.role !== 'cashier') loadZReports()
})

function onPeriodChange() {
  if (reportPeriod.value !== 'range') loadAll()
}

function onRangeSelect() {
  const [from, to] = dateRangeFilter.value || []
  if (from && to) loadAll()
}

async function loadAll() {
  loading.value = true
  try {
    const { from, to } = dateRange.value
    const wq = selectedWarehouseId.value ? `&warehouse_id=${selectedWarehouseId.value}` : ''
    const requests = [
      api.get(`/api/reports/daily?from=${from}&to=${to}${wq}`),
      api.get(`/api/reports/products?from=${from}&to=${to}${wq}`),
    ]
    if (session.user?.role !== 'cashier') {
      requests.push(api.get(`/api/reports/cashiers?from=${from}&to=${to}${wq}`))
    }
    const results = await Promise.all(requests)
    daily.value = results[0]
    topProducts.value = results[1]
    if (session.user?.role !== 'cashier') cashiers.value = results[2] || []
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

async function loadZReports() {
  try {
    const wq = selectedWarehouseId.value ? `&warehouse_id=${selectedWarehouseId.value}` : ''
    zReports.value = await api.get(`/api/reports/z-reports?limit=20${wq}`)
  } catch (e) { }
}

const hourlyChartData = computed(() => {
  const hours = daily.value?.by_hour || []
  return {
    labels: hours.map(h => `${String(h.hour).padStart(2, '0')}:00`),
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

const methodLabel = (m) => {
  const map = { cash: 'Наличные', card: 'Карта', uzcard: 'Uzcard', humo: 'Humo', mixed: 'Смешанный' }
  return map[m] || m
}
const methodColor = (m) => {
  const map = { cash: '#00d4aa', card: '#7b68ee', uzcard: '#5b8cf5', humo: '#ff8c42', mixed: '#ffb02e' }
  return map[m] || '#9898bb'
}

const methodChartData = computed(() => {
  const methods = daily.value?.by_method || []
  return {
    labels: methods.map(m => methodLabel(m.payment_method)),
    datasets: [{
      data: methods.map(m => parseFloat(m.total)),
      backgroundColor: methods.map(m => methodColor(m.payment_method))
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

function formatAmount(n) {
  const [int, dec] = parseFloat(n || 0).toFixed(2).split('.')
  return int.replace(/\B(?=(\d{3})+(?!\d))/g, '\u00A0') + '.' + dec
}
function formatTime(dt) {
  return dt ? new Date(dt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) : '—'
}
function formatDateTime(dt) {
  if (!dt) return '—'
  const d = new Date(dt)
  return `${d.toLocaleDateString('ru')} ${d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })}`
}

function exportCSV() {
  const rows = topProducts.value.map(p => [p.name, p.total_qty, p.total_revenue, p.gross_profit].join(','))
  const csv = ['Product,Qty,Revenue,Profit', ...rows].join('\n')
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
  flex-direction: column;
  align-items: flex-end;
  gap: 8px;
}

.actions-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 12px;
  margin-bottom: 15px;
}

.stat-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 16px 20px;
}

.stat-label {
  font-size: 12px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 24px;
  font-weight: 700;
}

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

.method-breakdown {
  margin-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.method-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px;
  border-radius: 8px;
  background: var(--bg-base);
}

.method-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.method-name {
  flex: 1;
  font-size: 13px;
  color: var(--text-secondary);
}

.method-amount {
  font-size: 14px;
  color: var(--text-primary);
}

.z-report-expansion {
  display: flex;
  gap: 20px;
  padding: 12px 16px;
  background: var(--bg-base);
}

.expansion-section {
  flex: 1;
}

.expansion-title {
  font-size: 12px;
  font-weight: 700;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 8px;
}
</style>
