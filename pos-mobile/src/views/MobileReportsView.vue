<template>
  <div class="reports-view">
    <!-- Header -->
    <div class="view-header">
      <div class="header-row">
        <h2 class="header-title">Отчёты</h2>
        <button class="refresh-btn" :class="{ spinning: loading }" @click="loadAll">
          <i class="pi pi-refresh" />
        </button>
      </div>
      <input type="date" class="date-input" v-model="selectedDate" @change="loadAll" />
    </div>

    <!-- Scrollable content -->
    <div class="reports-scroll">

      <!-- Loading -->
      <div v-if="loading" class="loading-state">
        <i class="pi pi-spin pi-spinner" style="font-size:32px;color:var(--accent-1)" />
      </div>

      <template v-else>

        <!-- Summary Cards -->
        <div class="section-title">Итоги дня</div>
        <div class="stats-grid">
          <div class="stat-card">
            <div class="stat-label">Продажи</div>
            <div class="stat-value accent">{{ daily.summary?.transaction_count ?? 0 }}</div>
            <div class="stat-sub">транзакций</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Выручка</div>
            <div class="stat-value accent">{{ fmt(daily.summary?.net_sales) }}</div>
            <div class="stat-sub">нетто</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Средний чек</div>
            <div class="stat-value">{{ fmt(daily.summary?.avg_transaction) }}</div>
            <div class="stat-sub">на транзакцию</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Скидки</div>
            <div class="stat-value danger">{{ fmt(daily.summary?.total_discount) }}</div>
            <div class="stat-sub">итого скидок</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Возвраты</div>
            <div class="stat-value danger">{{ daily.refunds?.count ?? 0 }}</div>
            <div class="stat-sub">{{ fmt(daily.refunds?.total) }}</div>
          </div>
        </div>

        <!-- Payment Methods -->
        <div class="section-title">Способы оплаты</div>
        <div class="card-block">
          <div v-if="!daily.by_method?.length" class="empty-inline">Нет данных</div>
          <div v-for="m in daily.by_method" :key="m.payment_method" class="method-row">
            <div class="method-info">
              <i :class="methodIcon(m.payment_method)" class="method-icon" />
              <span class="method-name">{{ methodLabel(m.payment_method) }}</span>
              <span class="method-count">× {{ m.count }}</span>
            </div>
            <div class="method-amount font-mono">{{ fmt(m.total) }}</div>
          </div>
        </div>

        <!-- Top Products -->
        <div class="section-title">Топ товаров</div>
        <div class="card-block">
          <div v-if="!topProducts.length" class="empty-inline">Нет данных</div>
          <div v-for="(p, i) in topProducts" :key="p.id" class="product-row">
            <div class="rank">{{ i + 1 }}</div>
            <div class="product-info">
              <div class="product-name">{{ p.name }}</div>
              <div class="product-sub">{{ p.total_qty }} шт.</div>
            </div>
            <div class="product-amount font-mono">{{ fmt(p.total_revenue) }}</div>
          </div>
        </div>

        <!-- Cashiers -->
        <div class="section-title">Кассиры</div>
        <div class="card-block" style="margin-bottom: 24px">
          <div v-if="!cashiers.length" class="empty-inline">Нет данных</div>
          <div v-for="c in cashiers" :key="c.id" class="cashier-row">
            <div class="cashier-avatar">{{ c.name[0] }}</div>
            <div class="cashier-info">
              <div class="cashier-name">{{ c.name }}</div>
              <div class="cashier-sub">{{ c.transaction_count }} чеков · ср. {{ fmt(c.avg_transaction) }}</div>
            </div>
            <div class="cashier-total font-mono">{{ fmt(c.total_sales) }}</div>
          </div>
        </div>

      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useWarehouseStore } from '../stores/warehouse.js'
import { useToast } from 'primevue/usetoast'

const store = useWarehouseStore()
const toast = useToast()

const today = new Date().toISOString().split('T')[0]
const selectedDate = ref(today)
const loading = ref(false)

const daily = ref({})
const topProducts = ref([])
const cashiers = ref([])

onMounted(loadAll)

async function loadAll() {
  loading.value = true
  try {
    const d = selectedDate.value
    const [dailyRes, productsRes, cashiersRes] = await Promise.all([
      store.authFetch(`/api/reports/daily?date=${d}`),
      store.authFetch(`/api/reports/products?from=${d}&to=${d}&limit=10`),
      store.authFetch(`/api/reports/cashiers?date=${d}`)
    ])
    if (!dailyRes.ok || !productsRes.ok || !cashiersRes.ok) throw new Error('Ошибка загрузки')
    daily.value = await dailyRes.json()
    topProducts.value = await productsRes.json()
    cashiers.value = (await cashiersRes.json()).filter(c => c.transaction_count > 0)
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

function fmt(val) {
  if (val == null) return '0'
  return Number(val).toLocaleString('ru-RU', { maximumFractionDigits: 2 })
}

function methodLabel(method) {
  if (method === 'cash') return 'Наличные'
  if (method === 'card') return 'Карта'
  if (method === 'transfer') return 'Перевод'
  return method
}

function methodIcon(method) {
  if (method === 'cash') return 'pi pi-wallet'
  if (method === 'card') return 'pi pi-credit-card'
  if (method === 'transfer') return 'pi pi-send'
  return 'pi pi-money-bill'
}
</script>

<style scoped>
.reports-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.view-header {
  padding: 12px 16px 10px;
  flex-shrink: 0;
}

.header-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.header-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0;
}

.refresh-btn {
  width: 40px; height: 40px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
}

.refresh-btn.spinning i {
  animation: spin 0.8s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

.date-input {
  width: 100%;
  height: 48px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-primary);
  font-size: 15px;
  font-family: var(--font-sans);
  padding: 0 14px;
  box-sizing: border-box;
  outline: none;
  -webkit-appearance: none;
}

.date-input:focus {
  border-color: var(--border-focus);
}

.reports-scroll {
  flex: 1;
  overflow-y: auto;
  padding: 8px 16px 16px;
  -webkit-overflow-scrolling: touch;
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 80px 20px;
}

.section-title {
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.8px;
  color: var(--text-muted);
  margin: 16px 0 8px;
}

/* Stats grid */
.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.stat-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 14px;
}

.stat-label {
  font-size: 12px;
  color: var(--text-muted);
  margin-bottom: 4px;
}

.stat-value {
  font-size: 22px;
  font-weight: 700;
  color: var(--text-primary);
  font-family: var(--font-mono);
  line-height: 1.1;
}

.stat-value.accent { color: var(--text-accent); }
.stat-value.danger { color: var(--danger); }

.stat-sub {
  font-size: 11px;
  color: var(--text-muted);
  margin-top: 2px;
}

/* Generic card block */
.card-block {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  overflow: hidden;
}

.empty-inline {
  padding: 20px;
  text-align: center;
  color: var(--text-muted);
  font-size: 14px;
}

/* Payment methods */
.method-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  border-bottom: 1px solid var(--border-subtle);
}

.method-row:last-child { border-bottom: none; }

.method-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.method-icon {
  color: var(--text-accent);
  font-size: 16px;
  width: 20px;
}

.method-name {
  font-size: 15px;
  color: var(--text-primary);
}

.method-count {
  font-size: 12px;
  color: var(--text-muted);
}

.method-amount {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

/* Top products */
.product-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-subtle);
}

.product-row:last-child { border-bottom: none; }

.rank {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  background: var(--bg-input);
  color: var(--text-muted);
  font-size: 12px;
  font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}

.product-row:first-child .rank { background: var(--accent-glow); color: var(--text-accent); }

.product-info { flex: 1; min-width: 0; }

.product-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.product-sub {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

.product-amount {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  flex-shrink: 0;
}

/* Cashiers */
.cashier-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-subtle);
}

.cashier-row:last-child { border-bottom: none; }

.cashier-avatar {
  width: 36px; height: 36px;
  border-radius: 50%;
  background: var(--accent-glow);
  color: var(--text-accent);
  font-size: 16px;
  font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}

.cashier-info { flex: 1; min-width: 0; }

.cashier-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
}

.cashier-sub {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

.cashier-total {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-primary);
  flex-shrink: 0;
}
</style>
