<template>
  <div class="history-view">
    <div class="view-header">
      <div>
        <h1 class="view-title">История приёмки</h1>
        <p class="view-subtitle">{{ total }} накладных</p>
      </div>
      <div class="header-actions">
        <Button label="Новый приём" icon="pi pi-plus" @click="$router.push('/incoming')" />
      </div>
    </div>

    <div class="card" style="flex:1;overflow:hidden;display:flex;flex-direction:column">
      <DataTable
        :value="receipts"
        :loading="loading"
        scrollable
        scroll-height="flex"
        lazy
        :rows="pageSize"
        :total-records="total"
        paginator
        :rows-per-page-options="[25, 50, 100]"
        v-model:first="firstRow"
        :expanded-rows="expandedRows"
        @page="onPage"
        @row-expand="onRowExpand"
        dataKey="id"
      >
        <Column expander style="width:44px" />
        <Column field="ref_no" header="Номер" style="width:180px">
          <template #body="{ data }">
            <span class="font-mono ref-no">{{ data.ref_no }}</span>
          </template>
        </Column>
        <Column field="supplier" header="Поставщик">
          <template #body="{ data }">{{ data.supplier || '—' }}</template>
        </Column>
        <Column field="received_by_name" header="Принял" style="width:160px" />
        <Column header="Сумма" style="width:140px;text-align:right">
          <template #body="{ data }">
            <span class="font-mono amount-text">{{ formatPrice(data.total_cost) }}</span>
          </template>
        </Column>
        <Column header="Дата" style="width:160px">
          <template #body="{ data }">{{ formatDate(data.created_at) }}</template>
        </Column>

        <template #expansion="{ data }">
          <div class="expansion-wrap">
            <div v-if="!data.items" class="expansion-loading">
              <i class="pi pi-spin pi-spinner" /> Загрузка...
            </div>
            <DataTable v-else :value="data.items" size="small" class="expansion-table">
              <Column field="product_name" header="Товар" />
              <Column field="qty_received" header="Кол-во" style="width:80px;text-align:right">
                <template #body="{ data: i }">
                  <span class="font-mono">{{ i.qty_received }} {{ i.unit || 'шт' }}</span>
                </template>
              </Column>
              <Column header="Себест." style="width:120px;text-align:right">
                <template #body="{ data: i }">
                  <span class="font-mono">{{ formatPrice(i.cost_per_unit) }}</span>
                </template>
              </Column>
              <Column header="Сумма" style="width:120px;text-align:right">
                <template #body="{ data: i }">
                  <span class="font-mono">{{ formatPrice(i.subtotal) }}</span>
                </template>
              </Column>
              <Column header="Годен до" style="width:110px">
                <template #body="{ data: i }">{{ i.expiry_date || '—' }}</template>
              </Column>
            </DataTable>
          </div>
        </template>

        <template #empty>
          <div class="empty-state">
            <i class="pi pi-inbox" style="font-size:36px;color:var(--text-muted)" />
            <p>Накладных нет</p>
          </div>
        </template>
      </DataTable>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const receipts = ref([])
const total = ref(0)
const loading = ref(false)
const pageSize = ref(25)
const firstRow = ref(0)
const expandedRows = ref([])

onMounted(() => load(1))

async function load(page = 1) {
  loading.value = true
  try {
    const res = await api.get(`/api/incoming?page=${page}&limit=${pageSize.value}`)
    receipts.value = res.data
    total.value = res.total
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

function onPage(e) {
  pageSize.value = e.rows
  firstRow.value = e.first
  load(e.page + 1)
}

async function onRowExpand(event) {
  const receipt = event.data
  if (receipt.items) return
  try {
    const detail = await api.get(`/api/incoming/${receipt.id}`)
    const idx = receipts.value.findIndex(r => r.id === receipt.id)
    if (idx !== -1) receipts.value[idx] = { ...receipts.value[idx], items: detail.items }
  } catch (e) { }
}

function formatPrice(n) {
  const [int, dec] = parseFloat(n || 0).toFixed(2).split('.')
  return int.replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + '.' + dec
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}
</script>

<style scoped>
.history-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: hidden;
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-shrink: 0;
}

.view-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
  margin: 0;
}

.view-subtitle {
  font-size: 13px;
  color: var(--text-secondary);
  margin: 2px 0 0;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 0;
  overflow: hidden;
}

.ref-no {
  font-size: 12px;
  color: var(--text-secondary);
}

.amount-text {
  font-weight: 700;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.expansion-wrap {
  padding: 8px 0 8px 44px;
  background: var(--bg-elevated);
}

.expansion-loading {
  padding: 12px 16px;
  font-size: 13px;
  color: var(--text-secondary);
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 60px 20px;
  color: var(--text-muted);
}
</style>
