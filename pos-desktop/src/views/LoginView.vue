<template>
  <div class="login-page">
    <div class="login-card">
      <!-- Logo -->
      <div class="login-logo">
        <div class="logo-icon">
          <i class="pi pi-shopping-bag" />
        </div>
        <h1 class="logo-title">Market POS</h1>
        <p class="logo-subtitle">Система кассового обслуживания</p>
      </div>

      <!-- Cashier Select -->
      <div class="field-group">
        <label class="field-label">Выбрать кассира</label>
        <Select
          v-model="selectedUser"
          :options="users"
          option-label="name"
          option-value="id"
          placeholder="Выберите кассира..."
          class="w-full"
          :loading="loadingUsers"
        >
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
        <PinPad
          v-model="pin"
          @complete="handleLogin"
        />
      </div>

      <div v-if="error" class="error-message">
        <i class="pi pi-exclamation-circle" />
        {{ error }}
      </div>

      <Button
        label="Войти"
        :loading="logging"
        :disabled="!selectedUser || pin.length < 4"
        class="touch-lg w-full"
        @click="handleLogin"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session.js'
import PinPad from '../components/PinPad.vue'
import Select from 'primevue/select'
import Button from 'primevue/button'

const router = useRouter()
const session = useSessionStore()

const users = ref([])
const selectedUser = ref(null)
const pin = ref('')
const error = ref('')
const logging = ref(false)
const loadingUsers = ref(false)

onMounted(async () => {
  loadingUsers.value = true
  try {
    const res = await fetch('http://localhost:3000/api/auth/users')
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
    const res = await fetch('http://localhost:3000/api/auth/login', {
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
    router.push('/pos')
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
  min-height: calc(100vh - 30px);
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-base);
  background-image: var(--gradient-mesh);
}

.login-card {
  background: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: 24px;
  padding: 5px 36px 40px;
  width: 380px;
  display: flex;
  flex-direction: column;
  gap: 24px;
  box-shadow: 0 24px 80px rgba(0,0,0,0.4);
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

.w-full { width: 100%; }
</style>
