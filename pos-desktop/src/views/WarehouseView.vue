<template>
  <div class="warehouse-view">
    <div class="view-header">
      <h1 class="view-title">Склады</h1>
    </div>

    <div class="warehouse-layout">
      <!-- Warehouses list -->
      <div class="card">
        <div class="section-header">
          <h3>Склады</h3>
          <Button label="Добавить склад" icon="pi pi-plus" @click="openCreateWarehouse" />
        </div>
        <DataTable :value="warehouses" :loading="loadingWarehouses">
          <Column field="id" header="ID" style="width:60px" />
          <Column field="name" header="Название" />
          <Column field="is_active" header="Активен" style="width:90px">
            <template #body="{ data }">
              <i :class="data.is_active ? 'pi pi-check-circle' : 'pi pi-times-circle'"
                :style="{ color: data.is_active ? 'var(--success)' : 'var(--danger)' }" />
            </template>
          </Column>
          <Column header="" style="width:80px">
            <template #body="{ data }">
              <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px"
                @click="openEditWarehouse(data)" />
            </template>
          </Column>
        </DataTable>
      </div>

      <!-- QR Access -->
      <div class="card qr-card-container">
        <h3 class="section-title">Мобильный доступ</h3>
        <p class="section-desc">Отсканируйте QR-код телефоном сотрудника склада для доступа к мобильной системе.</p>

        <div class="qr-card">
          <canvas ref="qrCanvas" class="qr-canvas" />
          <div class="qr-url font-mono">{{ mobileUrl }}</div>
        </div>

        <div class="qr-actions">
          <Button label="Обновить URL" icon="pi pi-refresh" class="p-button-secondary" @click="refreshMobileUrl" />
          <Button label="Печать QR" icon="pi pi-print" class="p-button-secondary" @click="printQR" />
        </div>
      </div>
    </div>

    <!-- Warehouse Dialog -->
    <Dialog v-model:visible="showWarehouseDialog" modal
      :header="editingWarehouse ? 'Редактировать склад' : 'Новый склад'" :style="{ width: '380px' }">
      <div class="dialog-form">
        <div class="field-group">
          <label class="field-label">Название</label>
          <InputText v-model="warehouseForm.name" class="w-full" />
        </div>
        <div class="field-group" v-if="editingWarehouse">
          <label class="field-label">Активен</label>
          <ToggleSwitch v-model="warehouseForm.is_active" />
        </div>
      </div>
      <template #footer>
        <Button label="Отмена" class="p-button-secondary" @click="showWarehouseDialog = false" />
        <Button :label="editingWarehouse ? 'Сохранить' : 'Создать'" :loading="saving" @click="saveWarehouse"
          style="flex:1" />
      </template>
    </Dialog>

    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import QRCode from 'qrcode'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import ToggleSwitch from 'primevue/toggleswitch'
import Dialog from 'primevue/dialog'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const warehouses = ref([])
const loadingWarehouses = ref(false)
const showWarehouseDialog = ref(false)
const editingWarehouse = ref(null)
const warehouseForm = ref({ name: '', is_active: true })
const saving = ref(false)

const mobileUrl = ref('')
const qrCanvas = ref(null)

onMounted(async () => {
  await loadWarehouses()
  await loadMobileUrl()
})

async function loadWarehouses() {
  loadingWarehouses.value = true
  try {
    warehouses.value = await api.get('/api/warehouses')
  } catch (e) { } finally {
    loadingWarehouses.value = false
  }
}

function openCreateWarehouse() {
  editingWarehouse.value = null
  warehouseForm.value = { name: '', is_active: true }
  showWarehouseDialog.value = true
}

function openEditWarehouse(wh) {
  editingWarehouse.value = wh
  warehouseForm.value = { ...wh }
  showWarehouseDialog.value = true
}

async function saveWarehouse() {
  saving.value = true
  try {
    if (editingWarehouse.value) {
      await api.put(`/api/warehouses/${editingWarehouse.value.id}`, warehouseForm.value)
    } else {
      await api.post('/api/warehouses', warehouseForm.value)
    }
    toast.add({ severity: 'success', summary: 'Склад сохранён', life: 2000 })
    showWarehouseDialog.value = false
    await loadWarehouses()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function loadMobileUrl() {
  try {
    const data = await api.get('/api/settings/mobile-url')
    mobileUrl.value = data.url
    if (qrCanvas.value) {
      await QRCode.toCanvas(qrCanvas.value, data.url, {
        width: 220, margin: 2,
        color: { dark: '#e2e2f5', light: '#22223a' }
      })
    }
  } catch (e) { }
}

async function refreshMobileUrl() {
  await loadMobileUrl()
  toast.add({ severity: 'info', summary: 'URL обновлён', life: 2000 })
}

function printQR() {
  const w = window.open()
  w.document.write(`<img src="${qrCanvas.value.toDataURL()}" style="width:220px"><br><code>${mobileUrl.value}</code>`)
  w.print()
  w.close()
}
</script>

<style scoped>
.warehouse-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: auto;
}

.view-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
}

.warehouse-layout {
  display: flex;
  gap: 20px;
  align-items: flex-start;
}

.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 20px;
}

.card:first-child {
  flex: 1;
}

.qr-card-container {
  width: 300px;
  flex-shrink: 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.section-header h3 {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

.section-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: 6px;
}

.section-desc {
  font-size: 13px;
  color: var(--text-secondary);
  margin-bottom: 20px;
  line-height: 1.5;
}

.qr-card {
  background: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.qr-canvas {
  border-radius: 8px;
}

.qr-url {
  font-size: 11px;
  color: var(--text-secondary);
  word-break: break-all;
  text-align: center;
}

.qr-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.field-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.w-full {
  width: 100%;
}

.dialog-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
</style>
