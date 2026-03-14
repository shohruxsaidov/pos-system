<template>
  <Dialog
    v-model:visible="visible"
    modal
    header="X-Отчёт — Текущий период"
    :style="{ width: '780px' }"
    :breakpoints="{ '960px': '95vw' }"
  >
    <div v-if="loading" class="loading-state">
      <ProgressSpinner style="width:48px;height:48px" />
      <span class="text-secondary">Загрузка отчёта...</span>
    </div>

    <div v-else-if="reportData">
      <ReportTemplate :data="reportData" report-type="X" />
    </div>

    <template #footer>
      <Button label="Закрыть" class="p-button-secondary touch-lg" @click="visible = false" />
      <Button
        v-if="reportData"
        label="Печать"
        icon="pi pi-print"
        class="touch-lg"
        @click="printReport"
      />
    </template>
  </Dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'
import ProgressSpinner from 'primevue/progressspinner'
import ReportTemplate from './ReportTemplate.vue'

const props = defineProps({
  modelValue: Boolean,
  warehouseId: { type: Number, default: null }
})
const emit = defineEmits(['update:modelValue'])

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

const api = useApi()
const toast = useToast()
const loading = ref(false)
const reportData = ref(null)

watch(visible, v => {
  if (v) loadReport()
  else reportData.value = null
})

async function loadReport() {
  loading.value = true
  reportData.value = null
  try {
    const wq = props.warehouseId ? `?warehouse_id=${props.warehouseId}` : ''
    reportData.value = await api.get(`/api/reports/x-report${wq}`)
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
    visible.value = false
  } finally {
    loading.value = false
  }
}

function printReport() {
  const el = document.getElementById('print-area')
  if (!el) return

  const win = window.open('', '_blank', 'width=820,height=700')
  win.document.write(`<!DOCTYPE html><html><head><meta charset="utf-8">
<title>X-Отчёт</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Plus Jakarta Sans', sans-serif; background: #fff; color: #111; padding: 24px; font-size: 13px; }
  #print-area { display: flex; flex-direction: column; gap: 16px; }
  .report-header { display: flex; align-items: flex-start; gap: 16px; padding: 16px; border: 1px solid #ddd; border-radius: 8px; }
  .report-type-badge { padding: 6px 16px; border-radius: 8px; font-size: 18px; font-weight: 800; border: 1px solid #ccc; }
  .report-meta { display: flex; flex-direction: column; gap: 4px; }
  .report-period, .report-detail { display: flex; gap: 8px; align-items: center; font-size: 13px; }
  .meta-label { color: #666; min-width: 120px; }
  .summary-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
  .summary-item { border: 1px solid #ddd; border-radius: 8px; padding: 12px; }
  .summary-label { font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 4px; }
  .summary-value { font-size: 18px; font-weight: 700; }
  .section-title { font-size: 12px; font-weight: 700; color: #555; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 8px; }
  .refund-section { padding: 12px; border: 1px solid #f5c6c6; border-radius: 8px; background: #fff5f5; }
  .refund-row { display: flex; align-items: center; gap: 10px; font-size: 13px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 6px 8px; text-align: left; }
  th { background: #f5f5f5; font-weight: 600; }
  .font-mono { font-family: 'JetBrains Mono', monospace; }
  .gradient-text { color: #4e54c8; }
  .text-secondary { color: #666; }
  .text-accent { color: #7b68ee; }
  @media print { body { padding: 8px; } }
</style></head><body>${el.innerHTML}</body></html>`)
  win.document.close()
  win.addEventListener('load', () => {
    win.print()
    win.close()
  })
}
</script>

<style scoped>
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  padding: 48px;
  color: var(--text-secondary);
}
</style>
