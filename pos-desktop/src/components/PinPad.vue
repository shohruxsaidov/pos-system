<template>
  <div class="pinpad">
    <div class="pinpad-dots">
      <div v-for="i in 4" :key="i" class="pinpad-dot" :class="{ filled: pin.length >= i }" />
    </div>
    <div class="pinpad-grid">
      <button v-for="key in keys" :key="key" class="pinpad-key" :class="{ 'key-delete': key === 'del' }"
        @click="handleKey(key)">
        <span v-if="key === 'del'">⌫</span>
        <span v-else>{{ key }}</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  modelValue: { type: String, default: '' }
})
const emit = defineEmits(['update:modelValue', 'complete'])

const pin = ref(props.modelValue || '')
const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del']

watch(() => props.modelValue, v => { pin.value = v || '' })

function handleKey(key) {
  if (key === 'del') {
    pin.value = pin.value.slice(0, -1)
  } else if (key !== '' && pin.value.length < 4) {
    pin.value += key
    if (pin.value.length === 4) {
      emit('complete', pin.value)
    }
  }
  emit('update:modelValue', pin.value)
}
</script>

<style scoped>
.pinpad {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
}

.pinpad-dots {
  display: flex;
  gap: 16px;
}

.pinpad-dot {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  border: 2px solid var(--border-default);
  background: transparent;
  transition: all 0.15s;
}

.pinpad-dot.filled {
  background: var(--gradient-hero);
  border-color: transparent;
  box-shadow: 0 0 12px var(--accent-glow);
  border: none
}

.pinpad-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.pinpad-key {
  width: 80px;
  height: 80px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 50%;
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

.pinpad-key:hover {
  background: var(--bg-hover);
  border-color: var(--border-focus);
}

.pinpad-key:active {
  transform: scale(0.93);
  background: var(--accent-glow);
}

.pinpad-key.key-delete {
  background: var(--danger-bg);
  border-color: var(--danger-border);
  color: var(--danger);
  font-size: 18px;
}

.pinpad-key:empty,
.pinpad-key:disabled {
  visibility: hidden;
  cursor: default;
}
</style>
