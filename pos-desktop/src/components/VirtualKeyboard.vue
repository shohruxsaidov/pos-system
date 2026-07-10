<template>
  <Teleport to="body">
    <div v-if="visible" class="vk-panel" :style="{ left: pos.x + 'px', top: pos.y + 'px' }">
      <div class="vk-handle" @pointerdown.prevent="startDrag">
        <span class="vk-handle-icon">⌨</span>
        <span class="vk-handle-title">Клавиатура</span>
        <button class="vk-close" @pointerdown.prevent="hide">✕</button>
      </div>

      <div class="vk-body">
        <!-- QWERTY section -->
        <div v-if="!numpadOnly" class="vk-qwerty">
          <div class="vk-row">
            <button v-for="k in numberRow" :key="k" class="vk-key" @pointerdown.prevent="pressKey(k)">{{ k }}</button>
            <button class="vk-key vk-bksp vk-wide"
              @pointerdown.prevent="startBackspace"
              @pointerup="stopBackspace" @pointerleave="stopBackspace" @pointercancel="stopBackspace">⌫</button>
          </div>
          <div class="vk-row">
            <button v-for="k in row1" :key="k" class="vk-key"
              @pointerdown.prevent="pressKey(shiftOn ? k.toUpperCase() : k)">{{ shiftOn ? k.toUpperCase() : k }}</button>
          </div>
          <div class="vk-row vk-row-indent">
            <button v-for="k in row2" :key="k" class="vk-key"
              @pointerdown.prevent="pressKey(shiftOn ? k.toUpperCase() : k)">{{ shiftOn ? k.toUpperCase() : k }}</button>
          </div>
          <div class="vk-row">
            <button class="vk-key vk-shift vk-wide" :class="{ 'vk-active': shiftOn }"
              @pointerdown.prevent="toggleShift">⇧</button>
            <button v-for="k in row3" :key="k" class="vk-key"
              @pointerdown.prevent="pressKey(shiftOn ? k.toUpperCase() : k)">{{ shiftOn ? k.toUpperCase() : k }}</button>
            <button class="vk-key vk-shift vk-wide" :class="{ 'vk-active': shiftOn }"
              @pointerdown.prevent="toggleShift">⇧</button>
          </div>
          <div class="vk-row">
            <button class="vk-key vk-space" @pointerdown.prevent="pressKey(' ')">ПРОБЕЛ</button>
          </div>
        </div>

        <div v-if="!numpadOnly" class="vk-sep" />

        <!-- Numpad section -->
        <div class="vk-numpad">
          <button v-for="k in '789456123'.split('')" :key="'np-' + k" class="vk-key vk-np-key"
            @pointerdown.prevent="pressKey(k)">{{ k }}</button>
          <button class="vk-key vk-np-key" @pointerdown.prevent="pressKey('.')">.</button>
          <button class="vk-key vk-np-key" @pointerdown.prevent="pressKey('0')">0</button>
          <button class="vk-key vk-np-key vk-bksp"
            @pointerdown.prevent="startBackspace"
            @pointerup="stopBackspace" @pointerleave="stopBackspace" @pointercancel="stopBackspace">⌫</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, onUnmounted } from 'vue'
import { useVirtualKeyboard } from '../composables/useVirtualKeyboard.js'

const { visible, numpadOnly, hide, pressKey, pressBackspace } = useVirtualKeyboard()

const STORAGE_KEY = 'vk_pos'
const numberRow = '1234567890'.split('')
const row1 = 'qwertyuiop'.split('')
const row2 = 'asdfghjkl'.split('')
const row3 = 'zxcvbnm'.split('')

const shiftOn = ref(false)

function toggleShift() {
  shiftOn.value = !shiftOn.value
}

// Backspace press-and-hold: repeat, accelerating the longer it's held
const BKSP_INITIAL_DELAY = 350  // wait before auto-repeat kicks in
const BKSP_START_INTERVAL = 120 // first repeat speed
const BKSP_MIN_INTERVAL = 30    // fastest speed once fully held
const BKSP_ACCEL = 0.85         // interval multiplier each repeat
let bkspTimer = null
let bkspInterval = BKSP_START_INTERVAL

function scheduleBackspace() {
  bkspTimer = setTimeout(() => {
    pressBackspace()
    bkspInterval = Math.max(BKSP_MIN_INTERVAL, bkspInterval * BKSP_ACCEL)
    scheduleBackspace()
  }, bkspInterval)
}

function startBackspace() {
  stopBackspace()
  pressBackspace()
  bkspInterval = BKSP_START_INTERVAL
  bkspTimer = setTimeout(() => {
    pressBackspace()
    scheduleBackspace()
  }, BKSP_INITIAL_DELAY)
}

function stopBackspace() {
  if (bkspTimer) {
    clearTimeout(bkspTimer)
    bkspTimer = null
  }
}

// Position management
const pos = ref(loadPos())

function loadPos() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved) return JSON.parse(saved)
  } catch { }
  return {
    x: Math.max(0, Math.floor((window.innerWidth - 820) / 2)),
    y: Math.max(0, window.innerHeight - 380)
  }
}

function savePos() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(pos.value))
}

// Drag logic
let dragging = false
let dragStart = { x: 0, y: 0 }
let panelStart = { x: 0, y: 0 }

function startDrag(e) {
  dragging = true
  dragStart = { x: e.clientX, y: e.clientY }
  panelStart = { ...pos.value }
  document.addEventListener('pointermove', onDragMove)
  document.addEventListener('pointerup', onDragEnd)
}

function onDragMove(e) {
  if (!dragging) return
  pos.value = {
    x: Math.max(0, Math.min(window.innerWidth - 100, panelStart.x + e.clientX - dragStart.x)),
    y: Math.max(0, Math.min(window.innerHeight - 50, panelStart.y + e.clientY - dragStart.y))
  }
}

function onDragEnd() {
  dragging = false
  savePos()
  document.removeEventListener('pointermove', onDragMove)
  document.removeEventListener('pointerup', onDragEnd)
}

onUnmounted(() => {
  stopBackspace()
  document.removeEventListener('pointermove', onDragMove)
  document.removeEventListener('pointerup', onDragEnd)
})
</script>

<style scoped>
.vk-panel {
  position: fixed;
  z-index: 9999;
  background: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6), 0 0 0 1px var(--border-subtle);
  user-select: none;
}

.vk-handle {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 14px;
  cursor: grab;
  border-bottom: 1px solid var(--border-subtle);
  border-radius: 16px 16px 0 0;
}

.vk-handle:active {
  cursor: grabbing;
}

.vk-handle-icon {
  font-size: 15px;
  opacity: 0.6;
}

.vk-handle-title {
  flex: 1;
  font-size: 12px;
  font-weight: 500;
  color: var(--text-muted);
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.vk-close {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 13px;
  width: 24px;
  height: 24px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.1s;
}

.vk-close:hover {
  background: var(--danger-bg);
  color: var(--danger);
}

.vk-body {
  display: flex;
  gap: 10px;
  padding: 12px;
}

.vk-qwerty {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
  flex: 1;
}

.vk-row {
  display: flex;
  gap: 5px;
}

.vk-row-indent {
  padding-left: 28px;
}

.vk-key {
  height: 52px;
  min-width: 52px;
  flex: 1;
  padding: 0 6px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  color: var(--text-primary);
  font-size: 16px;
  font-family: var(--font-sans);
  font-weight: 500;
  cursor: pointer;
  transition: background 0.08s, border-color 0.08s, transform 0.08s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.vk-key:hover {
  background: var(--bg-hover);
  border-color: var(--border-focus);
}

.vk-key:active {
  transform: scale(0.92);
  background: var(--accent-glow);
}

.vk-wide {
  flex: 1.8;
}

.vk-bksp {
  background: var(--danger-bg);
  color: var(--danger);
  border-color: transparent;
  font-size: 18px;
}

.vk-bksp:hover {
  border-color: var(--danger);
}

.vk-shift {
  font-size: 18px;
  color: var(--text-secondary);
}

.vk-active {
  background: var(--accent-glow) !important;
  border-color: var(--accent-1) !important;
  color: var(--text-accent) !important;
}

.vk-space {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: var(--text-muted);
}

.vk-sep {
  width: 1px;
  background: var(--border-subtle);
  flex-shrink: 0;
  margin: 2px 0;
}

.vk-numpad {
  display: grid;
  grid-template-columns: repeat(3, 60px);
  gap: 5px;
  align-content: start;
  flex-shrink: 0;
}

.vk-np-key {
  flex: none !important;
  width: 60px;
  font-size: 18px;
  font-weight: 600;
  font-family: var(--font-mono);
}
</style>
