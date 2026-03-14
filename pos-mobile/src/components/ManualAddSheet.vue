<template>
  <div v-if="visible" class="sheet-overlay" @click.self="$emit('close')">
    <div class="sheet-card">
      <div class="sheet-handle" />

      <div class="sheet-header">
        <h3>Добавить товар вручную</h3>
        <button class="close-btn" @click="$emit('close')">✕</button>
      </div>

      <!-- Search input -->
      <div class="search-wrap">
        <div class="search-field">
          <i class="pi pi-search search-icon" />
          <input
            ref="searchInput"
            v-model="query"
            class="search-input"
            placeholder="Название или штрихкод..."
            @input="onInput"
            autocomplete="off"
            autocorrect="off"
          />
          <button v-if="query" class="clear-btn" @click="query = ''; results = []">
            <i class="pi pi-times" />
          </button>
        </div>
      </div>

      <!-- Results -->
      <div class="results-scroll">
        <!-- Loading -->
        <div v-if="loading" class="state-center">
          <i class="pi pi-spin pi-spinner" style="font-size:28px;color:var(--text-muted)" />
        </div>

        <!-- Empty query hint -->
        <div v-else-if="!query" class="state-center">
          <i class="pi pi-search" style="font-size:36px;color:var(--text-muted)" />
          <p>Введите название или штрихкод товара</p>
        </div>

        <!-- No results -->
        <div v-else-if="results.length === 0 && searched" class="state-center">
          <i class="pi pi-box" style="font-size:36px;color:var(--text-muted)" />
          <p>Товар не найден</p>
          <button class="btn-create-new" @click="createNew">
            <i class="pi pi-plus" /> Создать новый товар
          </button>
        </div>

        <!-- Product list -->
        <div v-else class="result-list">
          <button
            v-for="p in results"
            :key="p.id"
            class="result-item"
            @click="selectProduct(p)"
          >
            <div class="result-info">
              <span class="result-name">{{ p.name }}</span>
              <span class="result-meta font-mono">
                {{ p.barcode || '—' }} · {{ p.unit || 'шт' }}
              </span>
            </div>
            <div class="result-right">
              <span class="result-stock" :class="stockClass(p.stock_qty)">
                {{ p.stock_qty }}
              </span>
              <i class="pi pi-plus result-add" />
            </div>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'
import { useWarehouseStore } from '../stores/warehouse.js'

const props = defineProps({ visible: Boolean })
const emit = defineEmits(['close', 'selected', 'create-new'])

const store = useWarehouseStore()

const query = ref('')
const results = ref([])
const loading = ref(false)
const searched = ref(false)
const searchInput = ref(null)

let debounceTimer = null

watch(() => props.visible, async (v) => {
  if (v) {
    query.value = ''
    results.value = []
    searched.value = false
    await nextTick()
    searchInput.value?.focus()
  }
})

function onInput() {
  clearTimeout(debounceTimer)
  searched.value = false
  if (!query.value.trim()) {
    results.value = []
    loading.value = false
    return
  }
  loading.value = true
  debounceTimer = setTimeout(() => search(), 300)
}

async function search() {
  const q = query.value.trim()
  if (!q) return
  try {
    const res = await store.authFetch(`/api/products?search=${encodeURIComponent(q)}&limit=30`)
    const data = await res.json()
    results.value = Array.isArray(data) ? data : (data.products || [])
  } catch {
    results.value = []
  } finally {
    loading.value = false
    searched.value = true
  }
}

function selectProduct(p) {
  emit('selected', p)
  query.value = ''
  results.value = []
  searched.value = false
}

function createNew() {
  emit('create-new', query.value.trim())
}

function stockClass(qty) {
  if (qty < 0) return 'stock-danger'
  if (qty === 0) return 'stock-danger'
  if (qty <= 5) return 'stock-warn'
  return 'stock-ok'
}
</script>

<style scoped>
.sheet-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.65);
  z-index: 1100;
  display: flex;
  align-items: flex-end;
}

.sheet-card {
  width: 100%;
  background: var(--bg-elevated);
  border-radius: 24px 24px 0 0;
  border-top: 1px solid var(--border-default);
  display: flex;
  flex-direction: column;
  max-height: 85vh;
  overflow: hidden;
  padding-bottom: env(safe-area-inset-bottom);
}

.sheet-handle {
  width: 40px; height: 4px;
  background: var(--border-default);
  border-radius: 2px;
  margin: 12px auto 0;
}

.sheet-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 20px 8px;
}

.sheet-header h3 {
  font-size: 17px;
  font-weight: 700;
  color: var(--text-primary);
}

.close-btn {
  width: 32px; height: 32px;
  background: var(--bg-surface);
  border: none; border-radius: 8px;
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 14px;
}

.search-wrap {
  padding: 8px 16px 12px;
}

.search-field {
  display: flex;
  align-items: center;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 14px;
  padding: 0 14px;
  gap: 10px;
  height: 56px;
}

.search-field:focus-within {
  border-color: var(--border-focus);
}

.search-icon {
  color: var(--text-muted);
  font-size: 16px;
  flex-shrink: 0;
}

.search-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-primary);
  font-size: 16px;
  font-family: var(--font-sans);
}

.search-input::placeholder { color: var(--text-muted); }

.clear-btn {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
}

.results-scroll {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

.state-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 48px 24px;
  color: var(--text-muted);
  font-size: 15px;
  text-align: center;
}

.btn-create-new {
  margin-top: 8px;
  height: 52px;
  padding: 0 24px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-accent);
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
}

.result-list {
  display: flex;
  flex-direction: column;
  padding: 0 16px 16px;
  gap: 8px;
}

.result-item {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 14px 16px;
  cursor: pointer;
  text-align: left;
  gap: 12px;
  transition: border-color 0.15s;
}

.result-item:active {
  border-color: rgba(123,104,238,0.5);
  background: var(--bg-hover);
}

.result-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
  overflow: hidden;
}

.result-name {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.result-meta {
  font-size: 12px;
  color: var(--text-muted);
}

.result-right {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
}

.result-stock {
  font-size: 13px;
  font-weight: 700;
  font-family: var(--font-mono);
  padding: 2px 8px;
  border-radius: 8px;
}

.stock-ok    { color: var(--success); background: var(--success-bg); }
.stock-warn  { color: var(--warning); background: var(--warning-bg); }
.stock-danger{ color: var(--danger);  background: var(--danger-bg);  }

.result-add {
  font-size: 18px;
  color: var(--text-accent);
}
</style>
