<template>
  <div class="settings-view">
    <div class="view-header">
      <h1 class="view-title">Настройки</h1>
    </div>

    <Tabs v-model:value="activeTab">
      <TabList>
        <Tab value="general">Общие</Tab>
        <Tab value="users">Пользователи</Tab>
        <Tab value="telegram">Telegram</Tab>
        <Tab value="barcode">Этикетки</Tab>
        <Tab value="audit">Журнал аудита</Tab>
      </TabList>

      <TabPanels>
        <!-- General -->
        <TabPanel value="general">
          <div class="settings-section">
            <div class="field-group">
              <label class="field-label">Название магазина</label>
              <InputText v-model="settings.store_name" class="w-field" />
            </div>

            <div class="field-group">
              <label class="field-label">Подпись чека</label>
              <InputText v-model="settings.receipt_footer" class="w-field" />
            </div>
            <Button label="Сохранить настройки" :loading="saving" @click="saveSettings" style="width:180px" />
          </div>
        </TabPanel>

        <!-- Users -->
        <TabPanel value="users">
          <div class="users-section">
            <div class="section-header">
              <h3>Пользователи системы</h3>
              <Button label="Добавить пользователя" icon="pi pi-plus" @click="openCreateUser" />
            </div>
            <DataTable :value="users" :loading="loadingUsers">
              <Column field="name" header="Имя" />
              <Column field="role" header="Роль" style="width:120px">
                <template #body="{ data }">
                  <Tag :value="data.role" :severity="roleSeverity(data.role)" />
                </template>
              </Column>
              <Column header="Склад" style="width:140px">
                <template #body="{ data }">
                  <span style="font-size:13px;color:var(--text-secondary)">
                    {{warehouses.find(w => w.id === data.warehouse_id)?.name || '—'}}
                  </span>
                </template>
              </Column>
              <Column field="is_active" header="Активен" style="width:80px">
                <template #body="{ data }">
                  <i :class="data.is_active ? 'pi pi-check-circle' : 'pi pi-times-circle'"
                    :style="{ color: data.is_active ? 'var(--success)' : 'var(--danger)' }" />
                </template>
              </Column>
              <Column header="" style="width:80px">
                <template #body="{ data }">
                  <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px"
                    @click="openEditUser(data)" />
                </template>
              </Column>
            </DataTable>
          </div>

          <Dialog v-model:visible="showUserDialog" modal
            :header="editingUser ? 'Редактировать пользователя' : 'Новый пользователь'" :style="{ width: '420px' }">
            <div class="user-form">
              <div class="field-group">
                <label class="field-label">Имя</label>
                <InputText v-model="userForm.name" class="w-full" />
              </div>
              <div class="field-group">
                <label class="field-label">Роль</label>
                <Select v-model="userForm.role" :options="['cashier', 'manager', 'admin', 'warehouse']"
                  class="w-full" />
              </div>
              <div class="field-group" v-if="userForm.role !== 'admin'">
                <label class="field-label">Склад</label>
                <Select v-model="userForm.warehouse_id" :options="warehouses" option-label="name" option-value="id"
                  placeholder="Выбрать склад" class="w-full" />
              </div>
              <div class="field-group">
                <label class="field-label">PIN (4 цифры)</label>
                <InputOtp v-model="userForm.pin" :length="4" mask />
              </div>
              <div class="field-group" v-if="editingUser">
                <label class="field-label">Активен</label>
                <ToggleSwitch v-model="userForm.is_active" />
              </div>
            </div>
            <template #footer>
              <Button label="Отмена" class="p-button-secondary" @click="showUserDialog = false" />
              <Button :label="editingUser ? 'Сохранить' : 'Создать'" :loading="saving" @click="saveUser"
                style="flex:1" />
            </template>
          </Dialog>
        </TabPanel>


        <!-- Telegram -->
        <TabPanel value="telegram">
          <div class="settings-section">
            <div class="field-group">
              <label class="field-label">Включить уведомления Telegram</label>
              <ToggleSwitch v-model="telegramEnabled"
                @change="settings.telegram_enabled = telegramEnabled ? 'true' : 'false'" />
            </div>
            <div class="field-group">
              <label class="field-label">Токен бота</label>
              <InputText v-model="settings.telegram_bot_token" class="w-field" placeholder="123456:ABCdef..." />
            </div>
            <div class="field-group">
              <label class="field-label">ID чата</label>
              <InputText v-model="settings.telegram_chat_id" class="w-field" placeholder="-100123456789" />
            </div>
            <div class="field-group">
              <label class="field-label">Telegram ID владельца (JSON массив)</label>
              <InputText v-model="settings.telegram_owner_ids" class="w-field" placeholder='[123456789]' />
            </div>
            <div class="field-group">
              <label class="field-label">Время итогового отчёта</label>
              <InputText v-model="settings.eod_time" style="width:120px" placeholder="23:00" />
            </div>
            <div class="field-group">
              <label class="field-label">Включить AI анализ дня</label>
              <ToggleSwitch v-model="aiSummaryEnabled"
                @change="settings.ai_summary_enabled = aiSummaryEnabled ? 'true' : 'false'" />
            </div>
            <div class="field-group">
              <label class="field-label">Claude API Key</label>
              <InputText v-model="settings.claude_api_key" class="w-field" type="password" placeholder="sk-ant-..." />
              <span style="font-size:12px;color:var(--text-muted)">
                ℹ️ Использует claude-haiku. Добавляет AI-анализ к ежедневному отчёту.
              </span>
              <div style="margin-top:8px;display:flex;flex-direction:column;gap:6px;">
                <Button label="Тест AI анализа" class="p-button-secondary" icon="pi pi-microchip-ai"
                  :loading="testingAI" :disabled="!aiSummaryEnabled || !settings.claude_api_key" @click="testAISummary"
                  style="align-self:flex-start" />
                <div v-if="aiSummaryStatus" class="status-msg" :class="aiSummaryStatus.type">
                  {{ aiSummaryStatus.msg }}
                </div>
              </div>
            </div>
            <div class="actions-row">
              <Button label="Сохранить настройки" :loading="saving" @click="saveSettings" />
              <Button label="Отправить тест" class="p-button-secondary" :loading="testing" @click="testTelegram" />
            </div>
            <div v-if="telegramStatus" class="status-msg" :class="telegramStatus.type">
              {{ telegramStatus.msg }}
            </div>
          </div>
        </TabPanel>

        <!-- Barcode Labels -->
        <TabPanel value="barcode">
          <div class="barcode-tab-layout">
            <!-- Controls -->
            <div class="settings-section">
              <div class="field-group">
                <label class="field-label">Размер этикетки по умолчанию</label>
                <div class="size-toggle">
                  <button class="size-btn" :class="{ active: settings.label_default_size !== '58mm' }"
                    type="button" @click="settings.label_default_size = '80mm'">80mm</button>
                  <button class="size-btn" :class="{ active: settings.label_default_size === '58mm' }"
                    type="button" @click="settings.label_default_size = '58mm'">58mm</button>
                </div>
              </div>

              <div class="field-group">
                <label class="field-label">Количество копий по умолчанию</label>
                <div class="copies-control">
                  <Button icon="pi pi-minus" class="p-button-secondary" style="height:56px;width:56px"
                    @click="decrementCopies" />
                  <div class="copies-display font-mono">{{ settings.label_default_copies || '1' }}</div>
                  <Button icon="pi pi-plus" class="p-button-secondary" style="height:56px;width:56px"
                    @click="incrementCopies" />
                </div>
              </div>

              <div class="field-group">
                <label class="field-label">Размер шрифта (px)</label>
                <div class="copies-control">
                  <Button icon="pi pi-minus" class="p-button-secondary" style="height:56px;width:56px"
                    @click="decrementFontSize" />
                  <div class="copies-display font-mono">{{ settings.label_font_size || '14' }}</div>
                  <Button icon="pi pi-plus" class="p-button-secondary" style="height:56px;width:56px"
                    @click="incrementFontSize" />
                </div>
              </div>

              <div class="field-group">
                <label class="field-label">Высота штрихкода (px)</label>
                <div class="copies-control">
                  <Button icon="pi pi-minus" class="p-button-secondary" style="height:56px;width:56px"
                    @click="decrementBarcodeHeight" />
                  <div class="copies-display font-mono">{{ settings.label_barcode_height || '48' }}</div>
                  <Button icon="pi pi-plus" class="p-button-secondary" style="height:56px;width:56px"
                    @click="incrementBarcodeHeight" />
                </div>
              </div>

              <div class="field-group">
                <label class="field-label">Показывать название магазина</label>
                <ToggleSwitch v-model="labelShowStore"
                  @change="settings.label_show_store = labelShowStore ? 'true' : 'false'" />
              </div>

              <div class="field-group">
                <label class="field-label">Показывать цену</label>
                <ToggleSwitch v-model="labelShowPrice"
                  @change="settings.label_show_price = labelShowPrice ? 'true' : 'false'" />
              </div>

              <Button label="Сохранить настройки" :loading="saving" @click="saveSettings" style="width:180px" />
            </div>

            <!-- Live preview -->
            <div class="bc-preview-col">
              <div class="field-label" style="margin-bottom:12px">Предпросмотр</div>
              <div class="bc-preview" :class="settings.label_default_size === '58mm' ? 'bc-size-58mm' : 'bc-size-80mm'">
                <div v-if="labelShowStore" class="bc-store">{{ settings.store_name || 'Main Market Store' }}</div>
                <div class="bc-name" :style="{ fontSize: (settings.label_font_size || 14) + 'px' }">Рис 5кг</div>
                <svg ref="svgPreviewRef" class="bc-barcode" />
                <div v-if="labelShowPrice" class="bc-price font-mono">45.00</div>
              </div>
            </div>
          </div>
        </TabPanel>

        <!-- Audit Log -->
        <TabPanel value="audit">
          <div class="audit-section">
            <div class="audit-filters">
              <Select v-model="auditFilter.action" :options="auditActions" placeholder="Действие" style="width:160px" />
              <DatePicker v-model="auditFilter.from" placeholder="От" />
              <DatePicker v-model="auditFilter.to" placeholder="До" />
              <Button label="Фильтр" @click="loadAudit" />
            </div>
            <!-- Skeleton loading -->
            <DataTable v-if="loadingAudit" :value="Array(8).fill({})" scrollable scroll-height="flex">
              <Column header="Время" style="width:150px">
                <template #body>
                  <Skeleton width="110px" height="16px" />
                </template>
              </Column>
              <Column header="Действие" style="width:150px">
                <template #body>
                  <Skeleton width="90px" height="24px" border-radius="12px" />
                </template>
              </Column>
              <Column header="Исполнитель" style="width:130px">
                <template #body>
                  <Skeleton width="80px" height="16px" />
                </template>
              </Column>
              <Column header="Объект">
                <template #body>
                  <Skeleton width="140px" height="16px" />
                </template>
              </Column>
              <Column header="Детали" style="width:50px">
                <template #body>
                  <Skeleton width="32px" height="32px" border-radius="6px" />
                </template>
              </Column>
            </DataTable>

            <!-- Actual data -->
            <DataTable v-else :value="auditLogs" scrollable scroll-height="flex">
              <Column field="created_at" header="Время" style="width:150px">
                <template #body="{ data }">
                  <span class="font-mono" style="font-size:12px">{{ formatDateTime(data.created_at) }}</span>
                </template>
              </Column>
              <Column field="action" header="Действие" style="width:150px">
                <template #body="{ data }">
                  <Tag :value="data.action" :severity="actionSeverity(data.action)" />
                </template>
              </Column>
              <Column field="actor_name" header="Исполнитель" style="width:130px" />
              <Column field="target_name" header="Объект" />
              <Column header="Детали" style="width:50px">
                <template #body="{ data }">
                  <Button v-if="data.details" icon="pi pi-eye" class="p-button-secondary" style="height:32px;width:32px"
                    @click="viewDetails(data)" />
                </template>
              </Column>
            </DataTable>
          </div>

          <Dialog v-model:visible="showDetails" modal header="Детали аудита" :style="{ width: '500px' }">
            <pre class="details-json">{{ JSON.stringify(selectedLog?.details, null, 2) }}</pre>
          </Dialog>
        </TabPanel>
      </TabPanels>
    </Tabs>

    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick } from 'vue'
import { useApi } from '../composables/useApi.js'
import { renderBarcode } from '../composables/useBarcode.js'
import { useToast } from 'primevue/usetoast'
import Tabs from 'primevue/tabs'
import TabList from 'primevue/tablist'
import Tab from 'primevue/tab'
import TabPanels from 'primevue/tabpanels'
import TabPanel from 'primevue/tabpanel'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import InputOtp from 'primevue/inputotp'
import Select from 'primevue/select'
import ToggleSwitch from 'primevue/toggleswitch'
import Dialog from 'primevue/dialog'
import DatePicker from 'primevue/datepicker'
import Tag from 'primevue/tag'
import Toast from 'primevue/toast'
import Skeleton from 'primevue/skeleton'

const api = useApi()
const toast = useToast()

const activeTab = ref('general')
const settings = ref({})
const saving = ref(false)
const testing = ref(false)
const testingAI = ref(false)
const telegramEnabled = ref(false)
const aiSummaryEnabled = ref(false)
const telegramStatus = ref(null)
const labelShowStore = ref(true)
const labelShowPrice = ref(true)
const aiSummaryStatus = ref(null)
const svgPreviewRef = ref(null)
const PREVIEW_BARCODE = '2000001234560'

function renderPreview() {
  nextTick(() => {
    if (svgPreviewRef.value) {
      renderBarcode(svgPreviewRef.value, PREVIEW_BARCODE, {
        displayValue: true,
        height: parseInt(settings.value.label_barcode_height) || 48,
        lineColor: '#000',
      })
    }
  })
}

const users = ref([])
const loadingUsers = ref(false)
const showUserDialog = ref(false)
const editingUser = ref(null)
const userForm = ref({ name: '', role: 'cashier', pin: '', is_active: true, warehouse_id: null })

const warehouses = ref([])

const auditLogs = ref([])
const loadingAudit = ref(false)
const auditFilter = ref({ action: null, from: null, to: null })
const showDetails = ref(false)
const selectedLog = ref(null)

const auditActions = [null, 'login', 'logout', 'sale', 'void', 'refund', 'stock_adjust',
  'stock_incoming', 'product_create', 'product_edit', 'product_delete', 'settings_change', 'user_create', 'user_edit']

onMounted(async () => {
  await loadSettings()
  await loadUsers()
  await loadWarehouses()
})

watch(activeTab, async (tab) => {
  if (tab === 'audit' && !auditLogs.value.length) await loadAudit()
  if (tab === 'barcode') renderPreview()
})

watch(() => settings.value.label_barcode_height, renderPreview)

async function loadSettings() {
  try {
    settings.value = await api.get('/api/settings')
    telegramEnabled.value = settings.value.telegram_enabled === 'true'
    aiSummaryEnabled.value = settings.value.ai_summary_enabled === 'true'
    labelShowStore.value = settings.value.label_show_store !== 'false'
    labelShowPrice.value = settings.value.label_show_price !== 'false'
  } catch (e) { }
}

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

async function testTelegram() {
  testing.value = true
  telegramStatus.value = null
  try {
    await api.post('/api/notifications/test-telegram', {})
    telegramStatus.value = { type: 'success-msg', msg: 'Тест-сообщение успешно отправлено!' }
  } catch (e) {
    telegramStatus.value = { type: 'error-msg', msg: e.message }
  } finally {
    testing.value = false
  }
}

async function testAISummary() {
  testingAI.value = true
  aiSummaryStatus.value = null
  try {
    const res = await api.post('/api/notifications/test-ai-summary', {})
    aiSummaryStatus.value = { type: 'success-msg', msg: 'AI анализ отправлен в Telegram!' }
  } catch (e) {
    aiSummaryStatus.value = { type: 'error-msg', msg: e.message }
  } finally {
    testingAI.value = false
  }
}

function decrementCopies() {
  const cur = parseInt(settings.value.label_default_copies || 1)
  settings.value.label_default_copies = String(Math.max(1, cur - 1))
}

function incrementCopies() {
  const cur = parseInt(settings.value.label_default_copies || 1)
  settings.value.label_default_copies = String(Math.min(50, cur + 1))
}

function decrementFontSize() {
  const cur = parseInt(settings.value.label_font_size || 14)
  settings.value.label_font_size = String(Math.max(8, cur - 1))
}

function incrementFontSize() {
  const cur = parseInt(settings.value.label_font_size || 14)
  settings.value.label_font_size = String(Math.min(40, cur + 1))
}

function decrementBarcodeHeight() {
  const cur = parseInt(settings.value.label_barcode_height || 48)
  settings.value.label_barcode_height = String(Math.max(20, cur - 4))
}

function incrementBarcodeHeight() {
  const cur = parseInt(settings.value.label_barcode_height || 48)
  settings.value.label_barcode_height = String(Math.min(120, cur + 4))
}

async function loadUsers() {
  loadingUsers.value = true
  try {
    users.value = await api.get('/api/settings/users')
  } catch (e) { } finally {
    loadingUsers.value = false
  }
}

function openCreateUser() {
  editingUser.value = null
  userForm.value = { name: '', role: 'cashier', pin: '', is_active: true, warehouse_id: null }
  showUserDialog.value = true
}

function openEditUser(user) {
  editingUser.value = user
  userForm.value = { ...user, pin: '' }
  showUserDialog.value = true
}

async function loadWarehouses() {
  try {
    warehouses.value = await api.get('/api/warehouses')
  } catch (e) { }
}

async function saveUser() {
  saving.value = true
  try {
    if (editingUser.value) {
      await api.put(`/api/settings/users/${editingUser.value.id}`, userForm.value)
    } else {
      await api.post('/api/settings/users', userForm.value)
    }
    toast.add({ severity: 'success', summary: 'Пользователь сохранён', life: 2000 })
    showUserDialog.value = false
    await loadUsers()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function loadAudit() {
  loadingAudit.value = true
  try {
    const params = new URLSearchParams()
    if (auditFilter.value.action) params.set('action', auditFilter.value.action)
    if (auditFilter.value.from) params.set('from', auditFilter.value.from.toISOString())
    if (auditFilter.value.to) params.set('to', auditFilter.value.to.toISOString())
    const data = await api.get(`/api/audit?${params}&limit=100`)
    auditLogs.value = data.data || data
  } catch (e) { } finally {
    loadingAudit.value = false
  }
}

function viewDetails(log) {
  selectedLog.value = log
  showDetails.value = true
}

function formatDateTime(d) {
  return d ? new Date(d).toLocaleString('en-US', { month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'
}

function roleSeverity(role) {
  const map = { admin: 'danger', manager: 'warn', cashier: 'success', warehouse: 'secondary' }
  return map[role] || 'secondary'
}

function actionSeverity(action) {
  if (['sale', 'stock_incoming'].includes(action)) return 'success'
  if (['refund', 'void', 'price_override'].includes(action)) return 'warn'
  if (['product_delete', 'user_delete'].includes(action)) return 'danger'
  return 'secondary'
}
</script>

<style scoped>
.settings-view {
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

.settings-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px 0;
  max-width: 560px;
}

.users-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.section-header h3 {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
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

.w-field {
  width: 380px;
}

.w-full {
  width: 100%;
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
}

.error-msg {
  color: var(--danger);
  padding: 10px;
  background: var(--danger-bg);
  border-radius: 8px;
}


.audit-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
  height: 100%;
}

.audit-filters {
  display: flex;
  gap: 10px;
  align-items: center;
  padding: 8px 0;
}

.details-json {
  font-family: var(--font-mono);
  font-size: 13px;
  color: var(--text-primary);
  background: var(--bg-surface);
  border-radius: 10px;
  padding: 16px;
  overflow: auto;
  max-height: 400px;
}

.user-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.size-toggle {
  display: flex;
  gap: 8px;
}

.size-btn {
  padding: 0 20px;
  height: 56px;
  border-radius: 12px;
  border: 1px solid var(--border-default);
  background: var(--bg-input);
  color: var(--text-secondary);
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.12s;
}

.size-btn.active {
  border-color: var(--accent-1);
  background: var(--accent-glow);
  color: var(--text-accent);
}

.copies-control {
  display: flex;
  align-items: center;
  gap: 12px;
}

.copies-display {
  width: 80px;
  text-align: center;
  font-size: 28px;
  font-weight: 700;
  color: var(--text-primary);
}

.barcode-tab-layout {
  display: flex;
  gap: 40px;
  padding: 16px 0;
  align-items: flex-start;
}

.bc-preview-col {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  flex-shrink: 0;
}

.bc-preview {
  background: #fff;
  border-radius: 12px;
  padding: 16px 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.25);
}

.bc-size-80mm { width: 302px; }
.bc-size-58mm { width: 220px; }

.bc-store {
  font-size: 10px;
  color: #666;
  font-family: var(--font-sans);
  align-self: flex-start;
}

.bc-name {
  font-weight: 700;
  color: #111;
  text-align: center;
  line-height: 1.2;
  width: 100%;
}

.bc-barcode {
  width: 100%;
}

.bc-price {
  font-size: 28px;
  font-weight: 700;
  color: #111;
  font-family: monospace;
}
</style>
