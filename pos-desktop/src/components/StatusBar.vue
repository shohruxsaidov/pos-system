<template>
  <div class="status-bar">
    <div class="status-pills">
      <div class="status-pill" :class="serverClass">
        <span class="status-dot" />
        <span>Сервер</span>
      </div>
      <div class="status-pill" :class="dbClass">
        <span class="status-dot" />
        <span>База данных</span>
      </div>
      <div class="status-pill" :class="printerClass">
        <span class="status-dot" />
        <span>Принтер</span>
      </div>
      <div class="status-pill" :class="syncClass">
        <span class="status-dot" />
        <span v-if="status.syncQueue > 0">Синхр.: {{ status.syncQueue }} ожидает</span>
        <span v-else>Синхронизировано</span>
      </div>
    </div>
    <div class="status-info">
      <span class="status-time font-mono">{{ currentTime }}</span>
      <span v-if="status.mobileUrl" class="status-url">{{ status.mobileUrl }}</span>
    </div>

    <!-- Offline Overlay -->
    <Teleport to="body">
      <div v-if="status.isOffline" class="offline-overlay">
        <div class="offline-card">
          <div class="offline-icon">
            <i class="pi pi-wifi" style="font-size:48px;color:var(--danger)" />
          </div>
          <h2>Сервер недоступен</h2>
          <p>Нет подключения к серверу. Проверьте, запущен ли сервер.</p>
          <div class="offline-status">
            <div class="offline-row">
              <span>Сервер:</span>
              <span :class="status.server === 'ok' ? 'text-success' : 'text-danger'">
                {{ status.server === 'ok' ? 'В сети' : 'Не в сети' }}
              </span>
            </div>
            <div class="offline-row">
              <span>База данных:</span>
              <span :class="status.db === 'ok' ? 'text-success' : 'text-danger'">
                {{ status.db === 'ok' ? 'Подключена' : 'Ошибка' }}
              </span>
            </div>
          </div>
          <p class="offline-hint">Автоматическое переподключение...</p>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useStatusStore } from '../stores/status.js'

const status = useStatusStore()
const currentTime = ref('')

let timer = null

onMounted(() => {
  updateTime()
  timer = setInterval(updateTime, 1000)
  status.connect()
})

onUnmounted(() => {
  clearInterval(timer)
})

function updateTime() {
  currentTime.value = new Date().toLocaleTimeString('en-US', {
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
  })
}

const serverClass = computed(() => {
  if (status.server === 'ok') return 'pill-success'
  if (status.server === 'connecting') return 'pill-warn'
  return 'pill-danger'
})

const dbClass = computed(() => {
  if (status.db === 'ok') return 'pill-success'
  if (status.db === 'unknown') return 'pill-warn'
  return 'pill-danger'
})

const printerClass = computed(() => {
  if (status.printer === 'ok') return 'pill-success'
  if (status.printer === 'disconnected') return 'pill-danger'
  return 'pill-warn'
})

const syncClass = computed(() => {
  if (status.syncQueue > 0) return 'pill-warn'
  return 'pill-success'
})
</script>

<style scoped>
.status-bar {
  height: 44px;
  background: var(--bg-sidebar);
  border-top: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  gap: 12px;
  flex-shrink: 0;
}

.status-pills {
  display: flex;
  gap: 8px;
  align-items: center;
}

.status-pill {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  border: 1px solid transparent;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.pill-success {
  background: var(--success-bg);
  color: var(--success);
  border-color: var(--success-border);
}

.pill-success .status-dot {
  background: var(--success);
}

.pill-warn {
  background: var(--warning-bg);
  color: var(--warning);
  border-color: var(--warning-border);
  animation: pulse-warn 2s ease-in-out infinite;
}

.pill-warn .status-dot {
  background: var(--warning);
}

.pill-danger {
  background: var(--danger-bg);
  color: var(--danger);
  border-color: var(--danger-border);
  animation: pulse-danger 1.5s ease-in-out infinite;
}

.pill-danger .status-dot {
  background: var(--danger);
}

.status-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.status-time {
  color: var(--text-secondary);
  font-size: 13px;
}

.status-url {
  color: var(--text-muted);
  font-size: 11px;
  font-family: var(--font-mono);
}

/* Offline overlay */
.offline-overlay {
  position: fixed;
  inset: 0;
  background: rgba(10,10,20,0.92);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(8px);
}

.offline-card {
  background: var(--bg-elevated);
  border: 1px solid var(--danger-border);
  border-radius: 20px;
  padding: 40px;
  text-align: center;
  max-width: 380px;
  width: 90%;
}

.offline-icon { margin-bottom: 16px; }

.offline-card h2 {
  font-size: 24px;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: 8px;
}

.offline-card p {
  color: var(--text-secondary);
  font-size: 14px;
  margin-bottom: 20px;
}

.offline-status {
  background: var(--bg-surface);
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 16px;
}

.offline-row {
  display: flex;
  justify-content: space-between;
  padding: 6px 0;
  font-size: 14px;
  color: var(--text-secondary);
}

.offline-hint {
  color: var(--text-muted) !important;
  font-size: 12px !important;
  margin-bottom: 0 !important;
}

@keyframes pulse-warn {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

@keyframes pulse-danger {
  0%, 100% { box-shadow: 0 0 0 0 rgba(255,92,92,0); }
  50% { box-shadow: 0 0 0 4px rgba(255,92,92,0.15); }
}
</style>
