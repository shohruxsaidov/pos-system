<template>
  <div id="print-area">
    <!-- Header -->
    <div class="report-header section">
      <div class="report-type-badge" :class="reportType === 'X' ? 'badge-x' : 'badge-z'">
        {{ reportType === 'X' ? 'X-Отчёт' : 'Z-Отчёт' }}
      </div>
      <div class="report-meta">
        <div class="report-period">
          <span class="meta-label">Период:</span>
          <span class="font-mono">{{ formatDate(data.opened_at) }} → {{ formatDate(data.closed_at) }}</span>
        </div>
        <div v-if="reportType === 'Z' && data.report_no" class="report-detail">
          <span class="meta-label">Номер отчёта:</span>
          <span class="font-mono text-accent">{{ data.report_no }}</span>
        </div>
        <div v-if="reportType === 'Z' && data.closed_by_name" class="report-detail">
          <span class="meta-label">Закрыто:</span>
          <span>{{ data.closed_by_name }}</span>
        </div>
      </div>
    </div>

    <!-- Summary Grid -->
    <div class="summary-grid section">
      <div class="summary-item">
        <div class="summary-label">Транзакции</div>
        <div class="summary-value font-mono gradient-text">{{ data.transaction_count || 0 }}</div>
      </div>
      <div class="summary-item">
        <div class="summary-label">Валовые продажи</div>
        <div class="summary-value font-mono gradient-text">{{ formatAmount(data.gross_sales) }}</div>
      </div>
      <div class="summary-item">
        <div class="summary-label">Скидки</div>
        <div class="summary-value font-mono" style="color: var(--warning)">{{ formatAmount(data.total_discount) }}</div>
      </div>
      <div class="summary-item">
        <div class="summary-label">Чистые продажи</div>
        <div class="summary-value font-mono gradient-text">{{ formatAmount(data.net_sales) }}</div>
      </div>
    </div>

    <!-- Refunds Section -->
    <div class="section refund-section" v-if="(data.refund_count || 0) > 0">
      <div class="section-title">Возвраты</div>
      <div class="refund-row">
        <span class="text-secondary">Количество возвратов:</span>
        <span class="font-mono" style="color: var(--warning)">{{ data.refund_count }}</span>
        <span class="text-secondary" style="margin-left:24px">Сумма возвратов:</span>
        <span class="font-mono" style="color: var(--danger)">{{ formatAmount(data.refund_amount) }}</span>
      </div>
    </div>

    <!-- Payment Methods -->
    <div class="section" v-if="data.payment_methods?.length">
      <div class="section-title">Способы оплаты</div>
      <DataTable :value="data.payment_methods" class="report-table">
        <Column field="method" header="Способ" />
        <Column field="count" header="Кол-во" style="width:100px" />
        <Column field="amount" header="Сумма" style="width:130px">
          <template #body="{ data: row }">
            <span class="font-mono">{{ formatAmount(row.amount) }}</span>
          </template>
        </Column>
      </DataTable>
    </div>

    <!-- Top Products -->
    <div class="section" v-if="data.top_products?.length">
      <div class="section-title">Топ товаров</div>
      <DataTable :value="data.top_products" class="report-table">
        <Column field="name" header="Товар" />
        <Column field="total_qty" header="Кол-во" style="width:100px">
          <template #body="{ data: row }">
            <span class="font-mono">{{ row.total_qty }}</span>
          </template>
        </Column>
        <Column field="total_amount" header="Сумма" style="width:130px">
          <template #body="{ data: row }">
            <span class="font-mono">{{ formatAmount(row.total_amount) }}</span>
          </template>
        </Column>
      </DataTable>
    </div>

    <!-- Cashier Summary -->
    <div class="section" v-if="data.cashier_summary?.length">
      <div class="section-title">По кассирам</div>
      <DataTable :value="data.cashier_summary" class="report-table">
        <Column field="name" header="Кассир" />
        <Column field="transaction_count" header="Транзакции" style="width:120px">
          <template #body="{ data: row }">
            <span class="font-mono">{{ row.transaction_count }}</span>
          </template>
        </Column>
        <Column field="total_sales" header="Продажи" style="width:130px">
          <template #body="{ data: row }">
            <span class="font-mono">{{ formatAmount(row.total_sales) }}</span>
          </template>
        </Column>
      </DataTable>
    </div>
  </div>
</template>

<script setup>
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'

const props = defineProps({
  data: { type: Object, required: true },
  reportType: { type: String, default: 'X' }
})

function formatAmount(n) {
  return parseFloat(n || 0).toFixed(2)
}

function formatDate(dt) {
  if (!dt) return '—'
  return new Date(dt).toLocaleString('ru-RU', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}
</script>

<style scoped>
#print-area {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.report-header {
  display: flex;
  align-items: flex-start;
  gap: 20px;
  padding: 20px;
  background: var(--bg-surface);
  border-radius: 16px;
  border: 1px solid var(--border-subtle);
}

.report-type-badge {
  padding: 8px 20px;
  border-radius: 10px;
  font-size: 20px;
  font-weight: 800;
  letter-spacing: 0.05em;
  flex-shrink: 0;
}

.badge-x {
  background: rgba(79, 140, 255, 0.15);
  color: #4f8cff;
  border: 1px solid rgba(79, 140, 255, 0.3);
}

.badge-z {
  background: var(--danger-bg);
  color: var(--danger);
  border: 1px solid var(--danger-border);
}

.report-meta {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.report-period,
.report-detail {
  display: flex;
  gap: 8px;
  align-items: center;
  font-size: 14px;
}

.meta-label {
  color: var(--text-muted);
  font-size: 13px;
  min-width: 120px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

.summary-item {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  padding: 14px 16px;
}

.summary-label {
  font-size: 12px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 6px;
}

.summary-value {
  font-size: 22px;
  font-weight: 700;
}

.section-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: 10px;
}

.refund-section {
  padding: 14px 16px;
  background: var(--danger-bg);
  border-radius: 12px;
  border: 1px solid var(--danger-border);
}

.refund-row {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 14px;
}

.report-table {
  border-radius: 12px;
  overflow: hidden;
}
</style>
