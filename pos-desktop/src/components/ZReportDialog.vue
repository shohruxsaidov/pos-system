<template>
  <Dialog
    v-model:visible="visible"
    modal
    :header="step === 'report' ? `Z-Отчёт ${reportData?.report_no || ''}` : 'Z-Отчёт — Закрытие периода'"
    :style="{ width: '780px' }"
    :breakpoints="{ '960px': '95vw' }"
    :closable="step !== 'loading'"
  >
    <!-- Step: PIN -->
    <div v-if="step === 'pin'" class="pin-step">
      <div class="warning-banner">
        <i class="pi pi-exclamation-triangle" style="font-size:20px" />
        <div>
          <div class="warning-title">Закрытие периода!</div>
          <div class="warning-text">Это действие необратимо. Z-Отчёт зафиксирует все продажи текущего периода и начнёт новый.</div>
        </div>
      </div>

      <div class="pin-field">
        <label class="field-label">PIN менеджера или администратора</label>
        <InputOtp v-model="managerPin" :length="4" mask />
        <p class="hint-text">Введите PIN для авторизации закрытия</p>
      </div>

      <div v-if="errorMsg" class="error-msg">
        <i class="pi pi-times-circle" />
        {{ errorMsg }}
      </div>
    </div>

    <!-- Step: Loading -->
    <div v-else-if="step === 'loading'" class="loading-state">
      <ProgressSpinner style="width:48px;height:48px" />
      <span class="text-secondary">Формирование Z-Отчёта...</span>
    </div>

    <!-- Step: Report -->
    <div v-else-if="step === 'report' && reportData">
      <ReportTemplate :data="reportData" report-type="Z" />
    </div>

    <template #footer>
      <template v-if="step === 'pin'">
        <Button label="Отмена" class="p-button-secondary touch-lg" @click="visible = false" />
        <Button
          label="Закрыть период"
          icon="pi pi-lock"
          severity="danger"
          class="touch-lg"
          :disabled="!managerPin || managerPin.length < 4"
          @click="submitZReport"
          style="flex:1"
        />
      </template>

      <template v-else-if="step === 'report'">
        <Button label="Закрыть" class="p-button-secondary touch-lg" @click="visible = false" />
        <Button
          label="Печать"
          icon="pi pi-print"
          class="touch-lg"
          @click="printReport"
        />
      </template>
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
import InputOtp from 'primevue/inputotp'
import ReportTemplate from './ReportTemplate.vue'

const props = defineProps({
  modelValue: Boolean,
  warehouseId: { type: Number, default: null }
})
const emit = defineEmits(['update:modelValue', 'closed'])

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

const api = useApi()
const toast = useToast()
const step = ref('pin')
const managerPin = ref('')
const reportData = ref(null)
const errorMsg = ref('')

watch(visible, v => {
  if (!v) {
    // Reset when closed
    setTimeout(() => {
      step.value = 'pin'
      managerPin.value = ''
      reportData.value = null
      errorMsg.value = ''
    }, 300)
  }
})

async function submitZReport() {
  if (!managerPin.value || managerPin.value.length < 4) return
  step.value = 'loading'
  errorMsg.value = ''

  try {
    const body = { manager_pin: managerPin.value }
    if (props.warehouseId) body.warehouse_id = props.warehouseId

    reportData.value = await api.post('/api/reports/z-report', body)
    step.value = 'report'
    emit('closed')
  } catch (e) {
    step.value = 'pin'
    errorMsg.value = e.message
    if (e.message.includes('Invalid manager PIN')) {
      errorMsg.value = 'Неверный PIN менеджера'
    }
    managerPin.value = ''
  }
}

function printReport() {
  const el = document.getElementById('print-area')
  if (!el) return

  const win = window.open('', '_blank', 'width=820,height=700')
  win.document.write(`<!DOCTYPE html><html><head><meta charset="utf-8">
<title>Z-Отчёт ${reportData.value?.report_no || ''}</title>
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
.pin-step {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 4px 0;
}

.warning-banner {
  display: flex;
  gap: 14px;
  align-items: flex-start;
  padding: 16px;
  background: var(--danger-bg);
  border: 1px solid var(--danger-border);
  border-radius: 12px;
  color: var(--danger);
}

.warning-title {
  font-weight: 700;
  font-size: 15px;
  margin-bottom: 4px;
}

.warning-text {
  font-size: 13px;
  color: var(--text-secondary);
}

.pin-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.field-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.hint-text {
  font-size: 12px;
  color: var(--text-muted);
}

.error-msg {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: var(--danger-bg);
  border: 1px solid var(--danger-border);
  border-radius: 10px;
  color: var(--danger);
  font-size: 14px;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  padding: 48px;
  color: var(--text-secondary);
}
</style>
