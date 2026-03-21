<template>
  <div class="printer-settings-view">
    <div class="view-header">
      <h1 class="view-title">Принтеры</h1>
    </div>

    <div class="printers-grid">
      <!-- Receipt Printer -->
      <div class="printer-card">
        <div class="printer-card-header">
          <div class="printer-card-icon">
            <i class="pi pi-receipt" />
          </div>
          <div>
            <div class="printer-card-title">Принтер чеков</div>
            <div class="printer-card-desc">Используется при продаже</div>
          </div>
        </div>

        <div class="settings-form">
          <div class="field-group">
            <label class="field-label">Тип принтера</label>
            <Select v-model="settings.printer_type" :options="['EPSON', 'STAR']" style="width:160px" />
          </div>
          <div class="field-group">
            <label class="field-label">Ширина бумаги</label>
            <Select v-model="settings.printer_paper_width" :options="['58mm', '80mm']" style="width:160px" />
          </div>
          <div class="field-group">
            <label class="field-label">Адрес / интерфейс</label>
            <div class="input-row">
              <InputText v-model="settings.printer_address" class="address-input"
                placeholder="tcp://192.168.1.100:9100 или /dev/usb/lp0" />
              <Button label="Авто-определить" icon="pi pi-search" class="p-button-secondary"
                :loading="detecting" @click="detectPrinterAuto" style="white-space:nowrap;flex-shrink:0" />
            </div>
            <span v-if="printerDetectStatus"
              :style="{ fontSize:'13px', color: printerDetectStatus.ok ? 'var(--success)' : 'var(--danger)' }">
              {{ printerDetectStatus.msg }}
            </span>
            <span v-else style="font-size:12px;color:var(--text-muted)">
              Нажмите «Авто-определить» — система сама найдёт принтер
            </span>
          </div>
          <div class="actions-row">
            <Button label="Сохранить" :loading="saving" @click="saveSettings" style="width:140px" />
            <Button label="Тест печати" icon="pi pi-print" class="p-button-secondary"
              :loading="testingPrinter" @click="testPrint" style="width:140px" />
          </div>
          <div v-if="printerTestStatus" class="status-msg" :class="printerTestStatus.type">
            {{ printerTestStatus.msg }}
          </div>
        </div>
      </div>

    </div>

    <!-- Printer picker dialog (when multiple found) -->
    <Dialog v-model:visible="pickerVisible" modal header="Выберите принтер"
      :style="{ width: '420px' }" :closable="true">
      <div class="picker-list">
        <div v-for="p in foundPrinters" :key="p.address"
          class="picker-item" @click="selectPrinter(p)">
          <i class="pi pi-print picker-icon" />
          <div>
            <div class="picker-name">{{ p.label }}</div>
            <div class="picker-addr">{{ p.address }}</div>
          </div>
        </div>
      </div>
    </Dialog>

    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Dialog from 'primevue/dialog'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const settings = ref({})
const saving = ref(false)

const detecting = ref(false)
const testingPrinter = ref(false)
const printerDetectStatus = ref(null)
const printerTestStatus = ref(null)

const pickerVisible = ref(false)
const foundPrinters = ref([])

onMounted(async () => {
  try {
    settings.value = await api.get('/api/settings')
  } catch (e) { }
})

async function saveSettings() {
  saving.value = true
  try {
    await api.put('/api/settings', settings.value)
    toast.add({ severity: 'success', summary: 'Настройки сохранены', life: 2000 })
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function detectPrinterAuto() {
  detecting.value = true
  printerDetectStatus.value = null
  try {
    const res = await api.post('/api/settings/printer-detect', {})
    if (res.printers.length === 1) {
      settings.value.printer_address = res.printers[0].address
      printerDetectStatus.value = { ok: true, msg: `Принтер найден: ${res.printers[0].address}` }
    } else {
      foundPrinters.value = res.printers
      pickerVisible.value = true
      printerDetectStatus.value = { ok: true, msg: `Найдено ${res.printers.length} принтера — выберите нужный` }
    }
  } catch {
    printerDetectStatus.value = { ok: false, msg: 'Принтер не найден. Проверьте подключение USB.' }
  } finally {
    detecting.value = false
  }
}

function selectPrinter(printer) {
  settings.value.printer_address = printer.address
  pickerVisible.value = false
  printerDetectStatus.value = { ok: true, msg: `Выбран: ${printer.address}` }
}

async function testPrint() {
  testingPrinter.value = true
  printerTestStatus.value = null
  try {
    await api.post('/api/settings/printer-test', {})
    printerTestStatus.value = { type: 'success-msg', msg: 'Тестовая страница отправлена на принтер!' }
  } catch (e) {
    printerTestStatus.value = { type: 'error-msg', msg: e.message }
  } finally {
    testingPrinter.value = false
  }
}
</script>

<style scoped>
.printer-settings-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 20px;
  overflow: auto;
}

.view-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
}

.printers-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
  gap: 20px;
  align-items: start;
}

.printer-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.printer-card-header {
  display: flex;
  align-items: center;
  gap: 14px;
}

.printer-card-icon {
  width: 48px;
  height: 48px;
  background: var(--gradient-hero);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 20px;
  flex-shrink: 0;
  box-shadow: var(--shadow-accent);
}

.printer-card-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

.printer-card-desc {
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 2px;
}

.settings-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
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

.input-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.address-input {
  flex: 1;
}

.actions-row {
  display: flex;
  gap: 10px;
}

.success-msg {
  color: var(--success);
  padding: 10px;
  background: var(--success-bg);
  border-radius: 8px;
  font-size: 13px;
}

.error-msg {
  color: var(--danger);
  padding: 10px;
  background: var(--danger-bg);
  border-radius: 8px;
  font-size: 13px;
}

/* Picker dialog */
.picker-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.picker-item {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  border-radius: 12px;
  border: 1px solid var(--border-default);
  background: var(--bg-input);
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
}

.picker-item:hover {
  border-color: rgba(123, 104, 238, 0.5);
  background: var(--bg-hover);
}

.picker-icon {
  font-size: 20px;
  color: var(--text-accent);
  flex-shrink: 0;
}

.picker-name {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

.picker-addr {
  font-size: 12px;
  color: var(--text-muted);
  font-family: var(--font-mono);
  margin-top: 2px;
}
</style>
