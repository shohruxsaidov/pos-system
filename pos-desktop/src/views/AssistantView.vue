<template>
  <div class="assistant-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Ассистент</h1>
        <p class="view-subtitle">Вопросы о продажах, остатках и кассирах</p>
      </div>
      <Button v-if="messages.length" label="Новый чат" icon="pi pi-refresh" class="p-button-secondary"
        @click="clearChat" />
    </div>

    <!-- API key missing -->
    <Message v-if="statusLoaded && !aiEnabled" severity="warn" :closable="false">
      Claude API ключ не настроен. Добавьте его в Настройках → Уведомления.
    </Message>

    <!-- Conversation -->
    <div ref="scrollEl" class="chat-scroll">
      <div v-if="!messages.length" class="chat-empty">
        <i class="pi pi-sparkles empty-icon" />
        <p class="empty-text">Задайте вопрос о работе магазина</p>
        <div class="suggestions">
          <button v-for="s in suggestions" :key="s" class="suggestion" :disabled="!canSend" @click="send(s)">
            <span>{{ s }}</span>
            <i class="pi pi-arrow-up-right" />
          </button>
        </div>
      </div>

      <div v-for="(msg, i) in messages" :key="i" class="bubble-row" :class="{ 'bubble-row--user': msg.role === 'user' }">
        <div class="bubble" :class="{
          'bubble--user': msg.role === 'user',
          'bubble--error': msg.isError
        }">
          <span class="bubble-text">{{ msg.content }}</span>
          <button v-if="msg.isError && i === messages.length - 1" class="retry-btn" @click="retryLast">
            <i class="pi pi-refresh" /> Повторить
          </button>
        </div>
      </div>

      <div v-if="sending" class="bubble-row">
        <div class="bubble bubble--typing">
          <ProgressSpinner style="width:16px;height:16px" strokeWidth="6" />
          <span>Смотрю данные...</span>
        </div>
      </div>
    </div>

    <!-- Composer -->
    <div class="composer">
      <Textarea v-model="draft" class="composer-input" rows="1" auto-resize
        placeholder="Спросите что-нибудь..." :disabled="!canSend" @keydown.enter.exact.prevent="send()" />
      <Button icon="pi pi-arrow-up" class="composer-send" :disabled="!canSend || !draft.trim()" @click="send()" />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import Button from 'primevue/button'
import Textarea from 'primevue/textarea'
import Message from 'primevue/message'
import ProgressSpinner from 'primevue/progressspinner'

const api = useApi()

const messages = ref([])
const draft = ref('')
const sending = ref(false)
const aiEnabled = ref(false)
const statusLoaded = ref(false)
const scrollEl = ref(null)

const suggestions = [
  'Сколько продали сегодня?',
  'Какие товары в минусе?',
  'Топ товаров за неделю',
  'Как сработали кассиры сегодня?',
  'Возвраты за сегодня'
]

const canSend = computed(() => aiEnabled.value && !sending.value)

onMounted(async () => {
  try {
    const status = await api.get('/api/ai/status')
    aiEnabled.value = !!status.enabled
  } catch {
    aiEnabled.value = false
  } finally {
    statusLoaded.value = true
  }
})

async function scrollToEnd() {
  await nextTick()
  if (scrollEl.value) scrollEl.value.scrollTop = scrollEl.value.scrollHeight
}

function clearChat() {
  messages.value = []
  draft.value = ''
}

async function send(preset) {
  const text = (preset ?? draft.value).trim()
  if (!text || !canSend.value) return

  draft.value = ''
  messages.value.push({ role: 'user', content: text })
  sending.value = true
  scrollToEnd()

  // Only clean turns go back to the model — failed sends are local-only.
  const history = messages.value
    .filter(m => !m.isError)
    .map(m => ({ role: m.role, content: m.content }))

  try {
    const res = await api.post('/api/ai/chat', { messages: history })
    messages.value.push({
      role: 'assistant',
      content: (res.reply || '').trim() || 'Пустой ответ от ассистента.'
    })
  } catch (e) {
    messages.value.push({ role: 'assistant', content: e.message, isError: true })
  } finally {
    sending.value = false
    scrollToEnd()
  }
}

async function retryLast() {
  if (!messages.value.length || !messages.value.at(-1).isError) return
  messages.value.pop()
  const lastUser = messages.value.at(-1)?.role === 'user' ? messages.value.pop() : null
  if (lastUser) await send(lastUser.content)
}
</script>

<style scoped>
.assistant-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 24px;
  gap: 16px;
  overflow: hidden;
}

.chat-scroll {
  flex: 1;
  overflow-y: auto;
  padding-right: 8px;
}

/* Empty state */
.chat-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 48px 16px;
}

.empty-icon {
  font-size: 40px;
  color: var(--text-muted);
}

.empty-text {
  margin: 12px 0 20px;
  color: var(--text-muted);
  font-size: 15px;
}

.suggestions {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  max-width: 520px;
}

.suggestion {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  height: 56px;
  padding: 0 16px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  color: var(--text-secondary);
  font-size: 14px;
  font-family: inherit;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}

.suggestion:hover:not(:disabled) {
  background: var(--bg-hover);
  border-color: var(--border-focus);
}

.suggestion:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.suggestion i {
  color: var(--text-muted);
  font-size: 12px;
}

/* Bubbles */
.bubble-row {
  display: flex;
  margin-bottom: 10px;
}

.bubble-row--user {
  justify-content: flex-end;
}

.bubble {
  max-width: 76%;
  padding: 12px 16px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px 16px 16px 4px;
  color: var(--text-primary);
  font-size: 15px;
  line-height: 1.5;
}

.bubble-text {
  white-space: pre-wrap;
}

.bubble--user {
  background: var(--gradient-hero);
  border: none;
  border-radius: 16px 16px 4px 16px;
  color: #fff;
}

.bubble--error {
  background: var(--danger-bg);
  border-color: rgba(255, 92, 92, 0.4);
  color: var(--danger);
}

.bubble--typing {
  display: flex;
  align-items: center;
  gap: 10px;
  color: var(--text-muted);
  font-size: 14px;
}

.retry-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
  padding: 0;
  background: none;
  border: none;
  color: var(--danger);
  font-size: 13px;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
}

/* Composer */
.composer {
  display: flex;
  align-items: flex-end;
  gap: 12px;
}

.composer-input {
  flex: 1;
  min-height: 56px;
  max-height: 160px;
  font-size: 16px;
  border-radius: 14px;
  resize: none;
}

.composer-send {
  width: 56px;
  height: 56px;
  flex-shrink: 0;
}
</style>
