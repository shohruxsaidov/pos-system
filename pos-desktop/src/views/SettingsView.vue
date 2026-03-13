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
        <Tab value="warehouse">Склад</Tab>
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
              <label class="field-label">Символ валюты</label>
              <InputText v-model="settings.currency_symbol" class="w-field" style="width:100px" />
            </div>
            <div class="field-group">
              <label class="field-label">Порог низкого запаса</label>
              <InputText v-model="settings.low_stock_threshold" type="number" style="width:120px" />
            </div>
            <div class="field-group">
              <label class="field-label">Ставка налога (%)</label>
              <InputText v-model="settings.tax_rate" type="number" style="width:120px" />
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
              <Column field="is_active" header="Активен" style="width:80px">
                <template #body="{ data }">
                  <i :class="data.is_active ? 'pi pi-check-circle' : 'pi pi-times-circle'"
                     :style="{ color: data.is_active ? 'var(--success)' : 'var(--danger)' }" />
                </template>
              </Column>
              <Column header="" style="width:80px">
                <template #body="{ data }">
                  <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px" @click="openEditUser(data)" />
                </template>
              </Column>
            </DataTable>
          </div>

          <Dialog v-model:visible="showUserDialog" modal :header="editingUser ? 'Редактировать пользователя' : 'Новый пользователь'" :style="{ width: '420px' }">
            <div class="user-form">
              <div class="field-group">
                <label class="field-label">Имя</label>
                <InputText v-model="userForm.name" class="w-full" />
              </div>
              <div class="field-group">
                <label class="field-label">Роль</label>
                <Select v-model="userForm.role" :options="['cashier','manager','admin','warehouse']" class="w-full" />
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
              <Button :label="editingUser ? 'Сохранить' : 'Создать'" :loading="saving" @click="saveUser" style="flex:1" />
            </template>
          </Dialog>
        </TabPanel>

        <!-- Telegram -->
        <TabPanel value="telegram">
          <div class="settings-section">
            <div class="field-group">
              <label class="field-label">Включить уведомления Telegram</label>
              <ToggleSwitch v-model="telegramEnabled" @change="settings.telegram_enabled = telegramEnabled ? 'true' : 'false'" />
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
            <div class="actions-row">
              <Button label="Сохранить настройки" :loading="saving" @click="saveSettings" />
              <Button label="Отправить тест" class="p-button-secondary" :loading="testing" @click="testTelegram" />
            </div>
            <div v-if="telegramStatus" class="status-msg" :class="telegramStatus.type">
              {{ telegramStatus.msg }}
            </div>
          </div>
        </TabPanel>

        <!-- Warehouse QR -->
        <TabPanel value="warehouse">
          <div class="warehouse-section">
            <h3 class="section-title">Мобильный доступ склада</h3>
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
            <DataTable :value="auditLogs" :loading="loadingAudit" scrollable scroll-height="flex">
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
                  <Button
                    v-if="data.details"
                    icon="pi pi-eye"
                    class="p-button-secondary"
                    style="height:32px;width:32px"
                    @click="viewDetails(data)"
                  />
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
import { ref, onMounted, watch } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import QRCode from 'qrcode'
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

const api = useApi()
const toast = useToast()

const activeTab = ref('general')
const settings = ref({})
const saving = ref(false)
const testing = ref(false)
const telegramEnabled = ref(false)
const telegramStatus = ref(null)

const users = ref([])
const loadingUsers = ref(false)
const showUserDialog = ref(false)
const editingUser = ref(null)
const userForm = ref({ name: '', role: 'cashier', pin: '', is_active: true })

const mobileUrl = ref('')
const qrCanvas = ref(null)

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
  await loadMobileUrl()
})

watch(activeTab, async (tab) => {
  if (tab === 'audit' && !auditLogs.value.length) await loadAudit()
})

async function loadSettings() {
  try {
    settings.value = await api.get('/api/settings')
    telegramEnabled.value = settings.value.telegram_enabled === 'true'
  } catch (e) {}
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

async function loadUsers() {
  loadingUsers.value = true
  try {
    users.value = await api.get('/api/settings/users')
  } catch (e) {} finally {
    loadingUsers.value = false
  }
}

function openCreateUser() {
  editingUser.value = null
  userForm.value = { name: '', role: 'cashier', pin: '', is_active: true }
  showUserDialog.value = true
}

function openEditUser(user) {
  editingUser.value = user
  userForm.value = { ...user, pin: '' }
  showUserDialog.value = true
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
  } catch (e) {}
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

async function loadAudit() {
  loadingAudit.value = true
  try {
    const params = new URLSearchParams()
    if (auditFilter.value.action) params.set('action', auditFilter.value.action)
    if (auditFilter.value.from) params.set('from', auditFilter.value.from.toISOString())
    if (auditFilter.value.to) params.set('to', auditFilter.value.to.toISOString())
    const data = await api.get(`/api/audit?${params}&limit=100`)
    auditLogs.value = data.data || data
  } catch (e) {} finally {
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
  overflow: hidden;
}

.view-title { font-size: 24px; font-weight: 800; color: var(--text-primary); }

.settings-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px 0;
  max-width: 560px;
}

.users-section { display: flex; flex-direction: column; gap: 12px; padding: 16px 0; }
.section-header { display: flex; justify-content: space-between; align-items: center; }
.section-header h3 { font-size: 16px; font-weight: 700; color: var(--text-primary); }

.field-group { display: flex; flex-direction: column; gap: 6px; }
.field-label { font-size: 12px; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
.w-field { width: 380px; }
.w-full { width: 100%; }

.actions-row { display: flex; gap: 10px; }
.success-msg { color: var(--success); padding: 10px; background: var(--success-bg); border-radius: 8px; }
.error-msg { color: var(--danger); padding: 10px; background: var(--danger-bg); border-radius: 8px; }

.warehouse-section { padding: 16px 0; max-width: 400px; }
.section-title { font-size: 18px; font-weight: 700; color: var(--text-primary); margin-bottom: 6px; }
.section-desc { font-size: 13px; color: var(--text-secondary); margin-bottom: 20px; }

.qr-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 16px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.qr-canvas { border-radius: 8px; }
.qr-url { font-size: 12px; color: var(--text-secondary); }
.qr-actions { display: flex; gap: 10px; }

.audit-section { display: flex; flex-direction: column; gap: 12px; height: 100%; }
.audit-filters { display: flex; gap: 10px; align-items: center; padding: 8px 0; }

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

.user-form { display: flex; flex-direction: column; gap: 16px; }
</style>
