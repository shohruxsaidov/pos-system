<template>
  <Transition name="slide-up">
    <div v-if="visible" class="bottom-numpad-overlay" @click.self="$emit('close')">
      <div class="bottom-numpad">
        <div class="numpad-handle" />
        <div class="numpad-display">
          <span class="numpad-label">{{ label }}</span>
          <span class="numpad-value font-mono">{{ displayValue || '0' }}</span>
        </div>
        <div class="numpad-grid">
          <button v-for="key in keys" :key="key.val" class="numpad-key" :class="key.cls" @click="handleKey(key.val)">
            <i v-if="key.icon" :class="key.icon" />
            <span v-else>{{ key.label }}</span>
          </button>
        </div>
        <div class="numpad-actions">
          <button class="numpad-cancel" @click="$emit('close')">Отмена</button>
          <button class="numpad-confirm" @click="confirm">Готово</button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  visible: Boolean,
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: 'Введите значение' },
  integer: Boolean
})

const emit = defineEmits(['update:modelValue', 'close', 'confirm'])

const displayValue = ref(String(props.modelValue || ''))

watch(() => props.modelValue, v => { displayValue.value = String(v || '') })
watch(() => props.visible, v => {
  if (v) displayValue.value = String(props.modelValue || '')
})

const keys = [
  { val: '7', label: '7' }, { val: '8', label: '8' }, { val: '9', label: '9' },
  { val: '4', label: '4' }, { val: '5', label: '5' }, { val: '6', label: '6' },
  { val: '1', label: '1' }, { val: '2', label: '2' }, { val: '3', label: '3' },
  { val: props.integer ? '00' : '.', label: props.integer ? '00' : '.' },
  { val: '0', label: '0' },
  { val: 'del', label: '⌫', cls: 'key-del' }
]

function handleKey(val) {
  let cur = displayValue.value
  if (val === 'del') {
    displayValue.value = cur.length > 1 ? cur.slice(0, -1) : '0'
  } else if (val === '.') {
    if (!props.integer && !cur.includes('.')) {
      displayValue.value = cur === '0' || !cur ? '0.' : cur + '.'
    }
  } else if (val === '00') {
    if (cur !== '0' && cur) displayValue.value = cur + '00'
  } else {
    displayValue.value = cur === '0' ? val : cur + val
  }
  emit('update:modelValue', displayValue.value)
}

function confirm() {
  emit('confirm', displayValue.value)
  emit('close')
}
</script>

<style scoped>
.bottom-numpad-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
}

.bottom-numpad {
  width: 100%;
  background: var(--bg-elevated);
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  padding: 0 16px 24px;
  padding-bottom: calc(24px + env(safe-area-inset-bottom));
}

.numpad-handle {
  width: 40px;
  height: 4px;
  background: var(--border-default);
  border-radius: 2px;
  margin: 12px auto 16px;
}

.numpad-display {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 16px;
}

.numpad-label { font-size: 12px; color: var(--text-muted); margin-bottom: 4px; }
.numpad-value { font-size: 36px; font-weight: 700; color: var(--text-primary); }

.numpad-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 12px;
}

.numpad-key {
  height: 72px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  color: var(--text-primary);
  font-size: 22px;
  font-weight: 600;
  font-family: var(--font-sans);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  user-select: none;
  -webkit-tap-highlight-color: transparent;
}

.numpad-key:active { background: var(--accent-glow); transform: scale(0.96); }
.numpad-key.key-del { color: var(--danger); background: var(--danger-bg); }

.numpad-actions { display: grid; grid-template-columns: 1fr 2fr; gap: 10px; }

.numpad-cancel {
  height: 60px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  color: var(--text-secondary);
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
}

.numpad-confirm {
  height: 60px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 14px;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 4px 20px rgba(123,104,238,0.35);
}

/* Transition */
.slide-up-enter-from, .slide-up-leave-to { transform: translateY(100%); opacity: 0; }
.slide-up-enter-active, .slide-up-leave-active { transition: all 0.3s cubic-bezier(0.4,0,0.2,1); }
</style>
