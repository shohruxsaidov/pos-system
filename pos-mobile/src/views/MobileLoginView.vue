<template>
  <div class="mobile-login">
    <div class="login-card">
      <div class="login-logo">
        <div class="logo-icon">
          <i class="pi pi-box" />
        </div>
        <h1 class="logo-title">Warehouse</h1>
        <p class="logo-subtitle">Enter your 4-digit PIN</p>
      </div>

      <!-- PIN Dots -->
      <div class="pin-dots">
        <div v-for="i in 4" :key="i" class="pin-dot" :class="{ filled: pin.length >= i }" />
      </div>

      <!-- PIN Pad -->
      <div class="pin-grid">
        <button
          v-for="key in pinKeys"
          :key="key"
          class="pin-key"
          :class="{ 'key-del': key === 'del' }"
          @click="handleKey(key)"
        >
          <span v-if="key === 'del'">⌫</span>
          <span v-else>{{ key }}</span>
        </button>
      </div>

      <div v-if="error" class="error-msg">
        <i class="pi pi-exclamation-circle" />
        {{ error }}
      </div>

      <div v-else style="min-height: 44px;">
      </div>

      <button
        class="login-btn"
        :disabled="pin.length < 4 || logging"
        @click="handleLogin"
      >
        <span v-if="logging"><i class="pi pi-spin pi-spinner" /> Logging in...</span>
        <span v-else>Login</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useWarehouseStore } from '../stores/warehouse.js'

const router = useRouter()
const store = useWarehouseStore()

const pin = ref('')
const error = ref('')
const logging = ref(false)
const pinKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del']

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
    const res = await fetch('/api/incoming/auth', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ pin: pin.value })
    })

    const data = await res.json()
    if (!res.ok) {
      error.value = data.error || 'Invalid PIN'
      pin.value = ''
      return
    }

    store.login(data.user, data.token)
    router.push('/incoming')
  } catch (e) {
    error.value = 'Connection error'
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
}

.login-card {
  background: var(--bg-elevated);
  border-radius: 24px;
  padding: 32px 24px;
  width: 100%;
  max-width: 360px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24px;
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

.logo-title {
  font-size: 26px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.logo-subtitle { font-size: 13px; color: var(--text-muted); margin-top: 4px; }

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

.pin-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  width: 100%;
  justify-items: center;
}

.pin-key {
  height: 70px;
  width: 70px;
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

.pin-key:empty { visibility: hidden; }
.pin-key:active { transform: scale(0.93); background: var(--accent-glow); }
.pin-key.key-del { color: var(--danger); background: var(--danger-bg); border-color: var(--danger-border); }

.error-msg {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background: var(--danger-bg);
  border: 1px solid var(--danger-border);
  border-radius: 12px;
  color: var(--danger);
  font-size: 14px;
  width: 100%;
}

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
