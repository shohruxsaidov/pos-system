<template>
  <div class="product-detail-view">
    <!-- Header -->
    <div class="view-header">
      <button class="back-btn" @click="router.back()">
        <i class="pi pi-arrow-left" />
      </button>
      <div class="header-info">
        <h1 class="view-title">{{ product?.name || '...' }}</h1>
        <div class="header-meta">
          <span class="font-mono text-muted" v-if="product?.barcode">{{ product.barcode }}</span>
          <span class="meta-sep" v-if="product?.barcode">·</span>
          <span class="text-muted">{{ product?.category_name || 'Без категории' }}</span>
          <span class="meta-sep">·</span>
          <span :class="['stock-badge', stockBadgeClass(product?.stock_qty)]">
            {{ stockLabel(product?.stock_qty) }}
          </span>
        </div>
      </div>
      <div class="header-actions">
        <div class="range-selector">
          <button v-for="d in DAYS_OPTIONS" :key="d.value"
            :class="['range-btn', { active: selectedDays === d.value }]"
            @click="selectedDays = d.value; load()">
            {{ d.label }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading-state">
      <i class="pi pi-spin pi-spinner" style="font-size:2.5rem;color:var(--accent-1)" />
    </div>

    <template v-else-if="product">
      <!-- Summary Cards -->
      <div class="summary-row">
        <div class="summary-card">
          <div class="summary-icon" style="background:var(--success-bg)">
            <i class="pi pi-shopping-cart" style="color:var(--success)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ summary.total_sold }}</div>
            <div class="summary-label">Продано (всего)</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:rgba(123,104,238,0.12)">
            <i class="pi pi-wallet" style="color:var(--accent-1)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ formatPrice(summary.total_revenue) }}</div>
            <div class="summary-label">Выручка (всего)</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:rgba(255,176,46,0.12)">
            <i class="pi pi-truck" style="color:var(--warning)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ summary.total_incoming }}</div>
            <div class="summary-label">Принято (период)</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:rgba(255,92,92,0.10)">
            <i class="pi pi-sliders-h" style="color:var(--danger)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ summary.total_adjustments }}</div>
            <div class="summary-label">Корректировок (период)</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:rgba(157,78,221,0.12)">
            <i class="pi pi-replay" style="color:var(--accent-2)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ summary.total_refunded_qty }}</div>
            <div class="summary-label">Возврат (кол-во)</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:rgba(255,92,92,0.10)">
            <i class="pi pi-arrow-circle-left" style="color:var(--danger)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ formatPrice(summary.total_refund_amount) }}</div>
            <div class="summary-label">Сумма возвратов</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:var(--success-bg)">
            <i class="pi pi-tag" style="color:var(--success)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ formatPrice(product.price) }}</div>
            <div class="summary-label">Цена продажи</div>
          </div>
        </div>
        <div class="summary-card">
          <div class="summary-icon" style="background:rgba(123,104,238,0.08)">
            <i class="pi pi-box" style="color:var(--text-secondary)" />
          </div>
          <div class="summary-body">
            <div class="summary-value font-mono">{{ formatPrice(product.cost) }}</div>
            <div class="summary-label">Себестоимость</div>
          </div>
        </div>
      </div>

      <!-- Sales Chart -->
      <div class="card chart-card">
        <div class="card-header">
          <h3>Продажи по дням</h3>
          <span class="text-muted" style="font-size:13px">последние {{ selectedDays }} дней</span>
        </div>
        <div v-if="salesByDay.length === 0" class="empty-chart">
          <i class="pi pi-chart-bar" />
          <span>Нет продаж за период</span>
        </div>
        <Chart v-else type="bar" :data="chartData" :options="chartOptions" style="height:220px" />
      </div>

      <!-- History Tables (2 columns) -->
      <div class="history-row">
        <!-- Stock Adjustments -->
        <div class="card history-card">
          <div class="card-header">
            <h3>Корректировки склада</h3>
            <span class="badge-count">{{ adjustments.length }}</span>
          </div>
          <div v-if="adjustments.length === 0" class="empty-table">
            <i class="pi pi-check-circle" style="color:var(--success)" />
            <span>Корректировок нет</span>
          </div>
          <div v-else class="history-list">
            <div v-for="(adj, i) in adjustments" :key="i" class="history-item">
              <div class="adj-delta" :class="adj.delta >= 0 ? 'delta-pos' : 'delta-neg'">
                {{ adj.delta >= 0 ? '+' : '' }}{{ adj.delta }}
              </div>
              <div class="history-body">
                <div class="history-reason">{{ adj.reason || '—' }}</div>
                <div class="history-meta">
                  {{ adj.adjusted_by_name || '—' }} · {{ formatDate(adj.created_at) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Incoming -->
        <div class="card history-card">
          <div class="card-header">
            <h3>Приёмка товара</h3>
            <span class="badge-count">{{ incoming.length }}</span>
          </div>
          <div v-if="incoming.length === 0" class="empty-table">
            <i class="pi pi-inbox" style="color:var(--text-muted)" />
            <span>Приёмок нет</span>
          </div>
          <div v-else class="history-list">
            <div v-for="(inc, i) in incoming" :key="i" class="history-item">
              <div class="adj-delta delta-pos">+{{ inc.qty_received }}</div>
              <div class="history-body">
                <div class="history-reason">
                  {{ inc.supplier || 'Поставщик не указан' }}
                  <span class="font-mono text-muted" style="font-size:11px"> · {{ inc.ref_no }}</span>
                </div>
                <div class="history-meta">
                  Цена: {{ formatPrice(inc.cost_per_unit) }}
                  <span v-if="inc.expiry_date"> · Годен до: {{ inc.expiry_date }}</span>
                  · {{ inc.received_by_name || '—' }}
                  · {{ formatDate(inc.created_at) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Refunds -->
        <div class="card history-card">
          <div class="card-header">
            <h3>Возвраты</h3>
            <span class="badge-count refund-count" :class="{ 'refund-count-active': refunds.length > 0 }">{{ refunds.length }}</span>
          </div>
          <div v-if="refunds.length === 0" class="empty-table">
            <i class="pi pi-check-circle" style="color:var(--success)" />
            <span>Возвратов нет</span>
          </div>
          <div v-else class="history-list">
            <div v-for="(ref, i) in refunds" :key="i" class="history-item">
              <div class="adj-delta delta-neg">-{{ ref.qty_returned }}</div>
              <div class="history-body">
                <div class="history-reason">
                  {{ ref.reason || '—' }}
                  <span class="font-mono text-muted" style="font-size:11px"> · {{ ref.ref_no }}</span>
                </div>
                <div class="history-meta">
                  Сумма: {{ formatPrice(ref.subtotal) }}
                  · {{ ref.processed_by_name || '—' }}
                  · {{ formatDate(ref.created_at) }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Sales Transactions Table -->
      <div class="card">
        <div class="card-header">
          <h3>Продажи по дням (таблица)</h3>
        </div>
        <div v-if="salesByDay.length === 0" class="empty-table">
          <i class="pi pi-shopping-cart" style="color:var(--text-muted)" />
          <span>Продаж за период нет</span>
        </div>
        <DataTable v-else :value="salesByDay" size="small">
          <Column field="date" header="Дата" style="width:140px">
            <template #body="{ data }">
              <span class="font-mono">{{ data.date }}</span>
            </template>
          </Column>
          <Column field="qty" header="Кол-во" style="width:100px">
            <template #body="{ data }">
              <span class="font-mono" style="color:var(--success)">{{ data.qty }}</span>
            </template>
          </Column>
          <Column field="txn_count" header="Транзакций" style="width:110px">
            <template #body="{ data }">
              <span class="font-mono">{{ data.txn_count }}</span>
            </template>
          </Column>
          <Column field="revenue" header="Выручка">
            <template #body="{ data }">
              <span class="font-mono" style="color:var(--accent-3)">{{ formatPrice(data.revenue) }}</span>
            </template>
          </Column>
        </DataTable>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useApi } from '../composables/useApi.js'
import Chart from 'primevue/chart'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'

const api = useApi()
const route = useRoute()
const router = useRouter()

const loading = ref(false)
const product = ref(null)
const salesByDay = ref([])
const adjustments = ref([])
const incoming = ref([])
const refunds = ref([])
const summary = ref({ total_sold: 0, total_revenue: 0, total_txns: 0, total_incoming: 0, total_adjustments: 0, total_refunded_qty: 0, total_refund_amount: 0 })

const DAYS_OPTIONS = [
  { label: '7 дней', value: 7 },
  { label: '30 дней', value: 30 },
  { label: '90 дней', value: 90 },
]
const selectedDays = ref(30)

function formatPrice(n) {
  const [int, dec] = parseFloat(n || 0).toFixed(2).split('.')
  return int.replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + '.' + dec
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function stockBadgeClass(qty) {
  if (qty < 0) return 'badge-danger'
  if (qty === 0) return 'badge-danger'
  if (qty <= 5) return 'badge-warn'
  return 'badge-success'
}

function stockLabel(qty) {
  if (qty == null) return '...'
  if (qty < 0) return `Дефицит (${qty})`
  if (qty === 0) return 'Нет в наличии'
  if (qty <= 5) return `Мало (${qty})`
  return `${qty} на складе`
}

const chartData = computed(() => {
  const labels = salesByDay.value.map(r => r.date.slice(5))
  return {
    labels,
    datasets: [
      {
        label: 'Кол-во',
        data: salesByDay.value.map(r => r.qty),
        backgroundColor: 'rgba(123,104,238,0.55)',
        borderColor: '#7b68ee',
        borderWidth: 1,
        borderRadius: 4,
        yAxisID: 'y',
      },
      {
        label: 'Выручка',
        data: salesByDay.value.map(r => r.revenue),
        backgroundColor: 'rgba(0,212,170,0.25)',
        borderColor: '#00d4aa',
        borderWidth: 2,
        type: 'line',
        tension: 0.35,
        fill: true,
        pointRadius: 3,
        yAxisID: 'y2',
      },
    ],
  }
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  plugins: {
    legend: { labels: { color: '#9898bb', font: { size: 12 } } },
    tooltip: { callbacks: { label: (ctx) => ctx.dataset.label + ': ' + ctx.parsed.y } },
  },
  scales: {
    x: { ticks: { color: '#9898bb', font: { size: 11 } }, grid: { color: 'rgba(255,255,255,0.04)' } },
    y: {
      position: 'left',
      ticks: { color: '#9898bb', font: { size: 11 } },
      grid: { color: 'rgba(255,255,255,0.04)' },
      title: { display: true, text: 'Кол-во', color: '#9898bb', font: { size: 11 } },
    },
    y2: {
      position: 'right',
      ticks: { color: '#9898bb', font: { size: 11 } },
      grid: { drawOnChartArea: false },
      title: { display: true, text: 'Выручка', color: '#9898bb', font: { size: 11 } },
    },
  },
}

async function load() {
  loading.value = true
  try {
    const data = await api.get(`/api/reports/product/${route.params.id}?days=${selectedDays.value}`)
    product.value = data.product
    salesByDay.value = data.sales_by_day
    adjustments.value = data.adjustments
    incoming.value = data.incoming
    refunds.value = data.refunds || []
    summary.value = data.summary
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.product-detail-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: auto;
}

.view-header {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
}

.back-btn {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  border: 1px solid var(--border-default);
  background: var(--bg-surface);
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
  transition: all 0.15s;
}
.back-btn:hover { background: var(--bg-hover); color: var(--text-primary); }

.header-info { flex: 1; }

.view-title {
  font-size: 22px;
  font-weight: 800;
  color: var(--text-primary);
  line-height: 1.2;
}

.header-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
  font-size: 13px;
}
.meta-sep { color: var(--text-muted); }

.range-selector {
  display: flex;
  gap: 4px;
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
  border-radius: 10px;
  padding: 4px;
}
.range-btn {
  padding: 6px 14px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s;
}
.range-btn.active { background: var(--accent-1); color: #fff; }
.range-btn:hover:not(.active) { color: var(--text-primary); background: var(--bg-hover); }

/* Summary */
.summary-row {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 12px;
}

.summary-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 16px;
  display: flex;
  align-items: center;
  gap: 14px;
}

.summary-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}

.summary-value {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary);
}

.summary-label {
  font-size: 11px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-top: 2px;
}

/* Cards */
.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 16px 20px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}

.card-header h3 {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-primary);
}

.badge-count {
  background: var(--bg-elevated);
  border: 1px solid var(--border-default);
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 20px;
}

.chart-card { }

.empty-chart {
  height: 120px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: var(--text-muted);
  font-size: 14px;
}

.empty-chart i { font-size: 32px; }

/* History */
.history-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16px;
}

@media (max-width: 1100px) {
  .history-row { grid-template-columns: 1fr 1fr; }
}

@media (max-width: 700px) {
  .history-row { grid-template-columns: 1fr; }
}

.refund-count-active {
  background: rgba(255,92,92,0.15);
  border-color: rgba(255,92,92,0.35);
  color: var(--danger);
}

.history-card { }

.history-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  max-height: 320px;
  overflow-y: auto;
}

.history-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 10px 8px;
  border-radius: 8px;
  transition: background 0.1s;
}
.history-item:hover { background: var(--bg-hover); }

.adj-delta {
  font-size: 15px;
  font-weight: 700;
  font-family: var(--font-mono);
  min-width: 52px;
  text-align: center;
  padding: 4px 8px;
  border-radius: 8px;
  flex-shrink: 0;
}
.delta-pos { color: var(--success); background: var(--success-bg); }
.delta-neg { color: var(--danger); background: rgba(255,92,92,0.10); }

.history-body { flex: 1; min-width: 0; }
.history-reason { font-size: 13px; color: var(--text-primary); font-weight: 500; }
.history-meta { font-size: 11px; color: var(--text-muted); margin-top: 2px; }

.empty-table {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 32px 0;
  color: var(--text-muted);
  font-size: 13px;
}
.empty-table i { font-size: 28px; }

.loading-state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Stock badges */
.stock-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 10px;
  border-radius: 20px;
  letter-spacing: 0.02em;
}
.badge-success { background: var(--success-bg); color: var(--success); }
.badge-warn { background: rgba(255,176,46,0.12); color: var(--warning); }
.badge-danger { background: rgba(255,92,92,0.12); color: var(--danger); }

.font-mono { font-family: var(--font-mono, 'JetBrains Mono', monospace); }
.text-muted { color: var(--text-muted); }
</style>
