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
  window.print()
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
