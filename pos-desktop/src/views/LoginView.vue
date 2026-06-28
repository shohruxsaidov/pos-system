<template>
  <div class="login-page">
    <!-- Server settings -->
    <Button icon="pi pi-cog" text rounded aria-label="Настройки сервера" class="server-config-btn"
      @click="openServerDialog" />

    <div class="login-card">
      <!-- Logo -->
      <div class="login-logo">
        <div class="logo-icon">
          <i class="pi pi-shopping-bag" />
        </div>
        <h1 class="logo-title">Market POS</h1>
      </div>

      <!-- Cashier Select -->
      <div class="field-group">
        <label class="field-label">Выбрать кассира</label>
        <Select v-model="selectedUser" :options="users" option-label="name" option-value="id"
          placeholder="Выберите кассира..." class="w-full" :loading="loadingUsers">
          <template #option="{ option }">
            <div class="user-option">
              <div class="user-avatar-sm">{{ option.name[0] }}</div>
              <div>
                <div>{{ option.name }}</div>
                <div class="user-role-tag">{{ option.role }}</div>
              </div>
            </div>
          </template>
        </Select>
      </div>

      <!-- PIN Input -->
      <div class="field-group">
        <label class="field-label">Введите PIN</label>
        <PinPad v-model="pin" @complete="handleLogin" />
      </div>

      <div v-if="error" class="error-message">
        <i class="pi pi-exclamation-circle" />
        {{ error }}
      </div>

      <Button label="Войти" :loading="logging" :disabled="!selectedUser || pin.length < 4" class="touch-lg w-full"
        @click="handleLogin" />
    </div>

    <!-- Server URL config dialog -->
    <Dialog v-model:visible="showServerDialog" modal header="Адрес сервера" :style="{ width: '420px' }">
      <div class="field-group">
        <label class="field-label">URL сервера</label>
        <InputText v-model="serverUrl" class="w-full" placeholder="http://192.168.1.100:3000"
          @keyup.enter="saveServerUrl" />
        <small class="server-hint">По умолчанию: {{ getDefaultApiBaseUrl() }}</small>
      </div>
      <template #footer>
        <Button label="Сбросить" text severity="secondary" @click="resetServerUrl" />
        <Button label="Отмена" text @click="showServerDialog = false" />
        <Button label="Сохранить" :disabled="!serverUrl.trim()" @click="saveServerUrl" />
      </template>
    </Dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session.js'
import { getApiBaseUrl, setApiBaseUrl, resetApiBaseUrl, getDefaultApiBaseUrl } from '../config/apiConfig.js'
import PinPad from '../components/PinPad.vue'
import Select from 'primevue/select'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'

const router = useRouter()
const session = useSessionStore()

const users = ref([])
const selectedUser = ref(null)
const pin = ref('')
const error = ref('')
const logging = ref(false)
const loadingUsers = ref(false)

// Server URL config dialog
const showServerDialog = ref(false)
const serverUrl = ref('')

function openServerDialog() {
  serverUrl.value = getApiBaseUrl()
  showServerDialog.value = true
}

function saveServerUrl() {
  if (!serverUrl.value.trim()) return
  setApiBaseUrl(serverUrl.value)
  window.location.reload()
}

function resetServerUrl() {
  resetApiBaseUrl()
  window.location.reload()
}

onMounted(async () => {
  loadingUsers.value = true
  try {
    const res = await fetch(`${getApiBaseUrl()}/api/auth/users`)
    users.value = await res.json()
  } catch (e) {
    error.value = 'Нет соединения с сервером'
  } finally {
    loadingUsers.value = false
  }
})

async function handleLogin() {
  if (!selectedUser.value || pin.value.length < 4 || logging.value) return
  logging.value = true
  error.value = ''

  try {
    const res = await fetch(`${getApiBaseUrl()}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: selectedUser.value, pin: pin.value })
    })

    const data = await res.json()

    if (!res.ok) {
      error.value = data.error || 'Ошибка входа'
      pin.value = ''
      return
    }

    session.login(data.user, data.token)
    router.push('/home')
  } catch (e) {
    error.value = 'Ошибка соединения. Сервер запущен?'
  } finally {
    logging.value = false
    pin.value = ''
  }
}
</script>

<style scoped>
.login-page {
  position: relative;
  min-height: calc(100vh - 30px);
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-base);
  background-image: var(--gradient-mesh);
}

.login-card {
  padding: 5px 36px 40px;
  width: 380px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.login-logo {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.logo-icon {
  width: 64px;
  height: 64px;
  background: var(--gradient-hero);
  border-radius: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  color: #fff;
  box-shadow: var(--shadow-accent);
  margin-bottom: 4px;
}

.logo-title {
  font-size: 26px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.logo-subtitle {
  font-size: 13px;
  color: var(--text-muted);
}

.field-group {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.field-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.user-option {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-avatar-sm {
  width: 32px;
  height: 32px;
  background: var(--gradient-accent);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 13px;
  color: #fff;
  flex-shrink: 0;
}

.user-role-tag {
  font-size: 11px;
  color: var(--text-muted);
  text-transform: uppercase;
}

.error-message {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background: var(--danger-bg);
  border: 1px solid var(--danger-border);
  border-radius: 10px;
  color: var(--danger);
  font-size: 14px;
}

.w-full {
  width: 100%;
}

.server-config-btn {
  position: absolute;
  top: 16px;
  right: 16px;
  color: var(--text-muted);
}

.server-hint {
  font-size: 12px;
  color: var(--text-muted);
}
</style>
