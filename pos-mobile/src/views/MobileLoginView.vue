<template>
  <div class="mobile-login">
    <div class="login-card">

      <!-- STEP 1: User Selection -->
      <template v-if="!selectedUser">
        <div class="login-logo">
          <div class="logo-icon"><i class="pi pi-users" /></div>
          <h1 class="logo-title">Вход</h1>
          <p class="logo-subtitle">Выберите пользователя</p>
        </div>

        <div v-if="loadingUsers" class="loading-users">
          <i class="pi pi-spin pi-spinner" style="font-size: 28px; color: var(--text-muted)" />
        </div>

        <div v-else class="user-list">
          <button
            v-for="u in users"
            :key="u.id"
            class="user-item"
            @click="selectUser(u)"
          >
            <div class="user-avatar">{{ u.name[0] }}</div>
            <div class="user-info">
              <span class="user-name">{{ u.name }}</span>
              <span class="user-role-badge" :class="u.role">{{ roleLabel(u.role) }}</span>
            </div>
            <i class="pi pi-chevron-right user-arrow" />
          </button>
        </div>

        <div v-if="error" class="error-msg">
          <i class="pi pi-exclamation-circle" /> {{ error }}
        </div>
      </template>

      <!-- STEP 2: PIN Entry -->
      <template v-else>
        <button class="back-link" @click="selectedUser = null; error = ''; pin = ''">
          <i class="pi pi-arrow-left" /> Назад
        </button>

        <div class="login-logo">
          <div class="logo-icon user-initial">{{ selectedUser.name[0] }}</div>
          <h1 class="logo-title">{{ selectedUser.name }}</h1>
          <p class="logo-subtitle">Введите 4-значный PIN</p>
        </div>

        <div class="pin-dots">
          <div v-for="i in 4" :key="i" class="pin-dot" :class="{ filled: pin.length >= i }" />
        </div>

        <div class="pin-grid">
          <button
            v-for="key in pinKeys"
            :key="key"
            class="pin-key"
            :class="{ 'key-del': key === 'del', 'key-empty': key === '' }"
            @click="handleKey(key)"
          >
            <span v-if="key === 'del'">⌫</span>
            <span v-else>{{ key }}</span>
          </button>
        </div>

        <div v-if="error" class="error-msg">
          <i class="pi pi-exclamation-circle" /> {{ error }}
        </div>
        <div v-else style="min-height: 44px;" />

        <button
          class="login-btn"
          :disabled="pin.length < 4 || logging"
          @click="handleLogin"
        >
          <span v-if="logging"><i class="pi pi-spin pi-spinner" /> Вход...</span>
          <span v-else>Войти</span>
        </button>
      </template>

    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useWarehouseStore } from '../stores/warehouse.js'

const router = useRouter()
const store = useWarehouseStore()

const users = ref([])
const loadingUsers = ref(true)
const selectedUser = ref(null)
const pin = ref('')
const error = ref('')
const logging = ref(false)
const pinKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del']

const roleLabels = {
  cashier: 'Кассир',
  warehouse: 'Склад',
  manager: 'Менеджер',
  admin: 'Администратор'
}
function roleLabel(r) { return roleLabels[r] || r }

onMounted(async () => {
  try {
    const res = await fetch('/api/auth/users')
    const data = await res.json()
    users.value = Array.isArray(data) ? data : []
  } catch {
    error.value = 'Не удалось загрузить пользователей'
  } finally {
    loadingUsers.value = false
  }
})

function selectUser(u) {
  selectedUser.value = u
  pin.value = ''
  error.value = ''
}

function handleKey(key) {
  if (key === 'del') {
    pin.value = pin.value.slice(0, -1)
  } else if (key !== '' && pin.value.length < 4) {
    pin.value += key
    if (pin.value.length === 4) handleLogin()
  }
}

async function handleLogin() {
  if (pin.value.length < 4 || logging.value) return
  logging.value = true
  error.value = ''

  try {
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: selectedUser.value.id, pin: pin.value })
    })

    const data = await res.json()
    if (!res.ok) {
      error.value = data.error || 'Неверный PIN'
      pin.value = ''
      return
    }

    store.login(data.user, data.token)
    const role = data.user.role
    if (role === 'warehouse') {
      router.push('/incoming')
    } else {
      router.push('/sales')
    }
  } catch {
    error.value = 'Ошибка подключения'
  } finally {
    logging.value = false
    pin.value = ''
  }
}
</script>

<style scoped>
.mobile-login {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-base);
  background-image: var(--gradient-mesh);
  overflow-y: auto;
  padding: 24px 0;
}

.login-card {
  border-radius: 24px;
  padding: 28px 20px;
  width: 100%;
  max-width: 360px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.login-logo { text-align: center; }

.logo-icon {
  width: 64px; height: 64px;
  background: var(--gradient-hero);
  border-radius: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  color: #fff;
  margin: 0 auto 12px;
  box-shadow: 0 4px 20px rgba(123,104,238,0.35);
}

.logo-icon.user-initial {
  font-size: 26px;
  font-weight: 800;
}

.logo-title {
  font-size: 24px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.logo-subtitle { font-size: 13px; color: var(--text-muted); margin-top: 4px; }

/* User list */
.loading-users { padding: 32px; }

.user-list {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 60vh;
  overflow-y: auto;
}

.user-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 16px;
  cursor: pointer;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
  transition: all 0.15s;
}

.user-item:active { background: var(--bg-hover); border-color: var(--accent-1); }

.user-avatar {
  width: 44px; height: 44px;
  background: var(--gradient-accent);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  font-weight: 700;
  color: #fff;
  flex-shrink: 0;
}

.user-info { flex: 1; display: flex; flex-direction: column; gap: 3px; }

.user-name { font-size: 16px; font-weight: 600; color: var(--text-primary); }

.user-role-badge {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 6px;
  width: fit-content;
}

.user-role-badge.cashier { background: var(--success-bg); color: var(--success); }
.user-role-badge.warehouse { background: var(--warning-bg); color: var(--warning); }
.user-role-badge.manager { background: rgba(123,104,238,0.15); color: var(--accent-1); }
.user-role-badge.admin { background: var(--danger-bg); color: var(--danger); }

.user-arrow { color: var(--text-muted); font-size: 12px; }

/* Back link */
.back-link {
  align-self: flex-start;
  display: flex;
  align-items: center;
  gap: 6px;
  background: none;
  border: none;
  color: var(--text-secondary);
  font-size: 14px;
  cursor: pointer;
  padding: 4px 0;
}

/* PIN dots */
.pin-dots { display: flex; gap: 16px; }
.pin-dot {
  width: 18px; height: 18px;
  border-radius: 50%;
  border: 2px solid var(--border-default);
  background: transparent;
  transition: all 0.15s;
}
.pin-dot.filled {
  background: var(--gradient-hero);
  border-color: transparent;
  box-shadow: 0 0 12px var(--accent-glow);
}

/* PIN grid */
.pin-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  width: 100%;
  justify-items: center;
}

.pin-key {
  height: 60px; width: 60px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 50%;
  color: var(--text-primary);
  font-size: 22px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  -webkit-tap-highlight-color: transparent;
  transition: all 0.12s;
}

.pin-key.key-empty { visibility: hidden; }
.pin-key:active { transform: scale(0.93); background: var(--accent-glow); }
.pin-key.key-del { color: var(--danger); background: var(--danger-bg); border-color: rgba(255,92,92,0.2); }

/* Error */
.error-msg {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background: var(--danger-bg);
  border: 1px solid rgba(255,92,92,0.2);
  border-radius: 12px;
  color: var(--danger);
  font-size: 14px;
  width: 100%;
}

/* Login button */
.login-btn {
  width: 100%;
  height: 64px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 16px;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 4px 20px rgba(123,104,238,0.35);
  transition: all 0.15s;
}

.login-btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
