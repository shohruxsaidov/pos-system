<template>
  <div class="numpad">
    <div class="numpad-display" v-if="showDisplay">
      <span class="numpad-value font-mono">{{ formatDisplay(displayValue) }}</span>
    </div>
    <div class="numpad-grid">
      <button
        v-for="key in keys"
        :key="key.value"
        class="numpad-key"
        :class="key.class"
        @click="handleKey(key.value)"
      >
        <i v-if="key.icon" :class="key.icon" />
        <span v-else>{{ key.label }}</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  showDisplay: { type: Boolean, default: true },
  integer: { type: Boolean, default: false },
  max: { type: Number, default: null }
})

const emit = defineEmits(['update:modelValue', 'confirm'])

const displayValue = ref(String(props.modelValue || ''))

watch(() => props.modelValue, (v) => {
  displayValue.value = String(v || '')
})

const keys = computed(() => [
  { label: '7', value: '7' },
  { label: '8', value: '8' },
  { label: '9', value: '9' },
  { label: '4', value: '4' },
  { label: '5', value: '5' },
  { label: '6', value: '6' },
  { label: '1', value: '1' },
  { label: '2', value: '2' },
  { label: '3', value: '3' },
  { label: props.integer ? '00' : '.', value: props.integer ? '00' : '.' },
  { label: '0', value: '0' },
  { label: '⌫', value: 'del', class: 'key-delete', icon: '' },
  { label: 'C', value: 'clear', class: 'key-clear' }
])

function formatDisplay(val) {
  if (!val || val === '0') return '0'
  const hasDot = val.includes('.')
  const [intPart, decPart] = val.split('.')
  const formattedInt = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, '\u00A0')
  return hasDot ? formattedInt + '.' + (decPart ?? '') : formattedInt
}

function handleKey(val) {
  let current = displayValue.value

  if (val === 'clear') {
    displayValue.value = '0'
  } else if (val === 'del') {
    displayValue.value = current.length > 1 ? current.slice(0, -1) : '0'
  } else if (val === '.') {
    if (!props.integer && !current.includes('.')) {
      displayValue.value = current === '0' || !current ? '0.' : current + '.'
    }
  } else if (val === '00') {
    if (current === '0' || !current) return
    displayValue.value = current + '00'
  } else {
    if (current === '0' && val !== '.') {
      displayValue.value = val
    } else {
      displayValue.value = current + val
    }
  }

  // Apply max limit
  if (props.max !== null && parseFloat(displayValue.value) > props.max) {
    displayValue.value = String(props.max)
  }

  emit('update:modelValue', displayValue.value)
}
</script>

<style scoped>
.numpad {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
}

.numpad-display {
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  padding: 12px 16px;
  text-align: right;
  min-height: 56px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.numpad-value {
  font-size: 28px;
  color: var(--text-primary);
}

.numpad-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

.numpad-key {
  height: 88px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  color: var(--text-primary);
  font-size: 22px;
  font-family: var(--font-sans);
  font-weight: 600;
  cursor: pointer;
  transition: all 0.12s;
  display: flex;
  align-items: center;
  justify-content: center;
  user-select: none;
}

.numpad-key:hover {
  background: var(--bg-hover);
  border-color: var(--border-focus);
}

.numpad-key:active {
  transform: scale(0.96);
  background: var(--accent-glow);
}

.numpad-key.key-delete {
  background: var(--danger-bg);
  border-color: var(--danger-border);
  color: var(--danger);
  font-size: 18px;
}

.numpad-key.key-clear {
  grid-column: 1 / -1;
  height: 64px;
  background: var(--bg-input);
  border-color: var(--border-default);
  color: var(--text-secondary);
  font-size: 16px;
  letter-spacing: 0.05em;
}
</style>
