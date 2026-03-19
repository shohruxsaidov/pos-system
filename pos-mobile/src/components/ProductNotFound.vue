<template>
  <div v-if="visible" class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-card">
      <div class="modal-header">
        <h3>Товар не найден</h3>
        <button class="close-btn" @click="$emit('close')">✕</button>
      </div>

      <div class="modal-body">
        <p class="text-secondary">Штрихкод не найден в системе. Создайте новый товар:</p>

        <div class="fields">
          <div class="field-group">
            <label class="field-label">Название *</label>
            <input v-model="form.name" class="text-input" placeholder="Название товара" />
          </div>

          <div class="field-group">
            <label class="field-label">Штрихкод</label>
            <div class="barcode-row">
              <input
                v-model="form.barcode"
                class="text-input barcode-input font-mono"
                placeholder="Штрихкод"
                @input="renderPreview"
              />
              <button class="gen-btn" @click="generateBarcode" title="Сгенерировать">
                <i class="pi pi-refresh" />
              </button>
            </div>
            <!-- Live barcode preview -->
            <div v-if="form.barcode" class="barcode-preview">
              <svg ref="barcodeSvg" />
            </div>
          </div>

          <div class="field-row">
            <div class="field-group">
              <label class="field-label">Цена</label>
              <input v-model="form.price" type="number" class="text-input" placeholder="0.00" />
            </div>
            <div class="field-group">
              <label class="field-label">Единица</label>
              <div class="unit-chips">
                <button
                  v-for="u in units"
                  :key="u"
                  class="unit-chip"
                  :class="{ active: form.unit === u }"
                  @click="form.unit = u"
                >{{ u }}</button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <p v-if="error" class="error-msg">{{ error }}</p>

      <div class="modal-footer">
        <button class="btn-skip" :disabled="saving" @click="$emit('skip')">Пропустить</button>
        <button class="btn-create" :disabled="!form.name || saving" @click="create">
          <i v-if="saving" class="pi pi-spin pi-spinner" style="margin-right:6px" />
          {{ saving ? 'Создание...' : 'Создать' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'
import JsBarcode from 'jsbarcode'
import { useWarehouseStore } from '../stores/warehouse.js'

const props = defineProps({ visible: Boolean, barcode: String, prefillName: String })
const emit = defineEmits(['close', 'skip', 'created'])

const store = useWarehouseStore()
const barcodeSvg = ref(null)
const saving = ref(false)
const error = ref('')
const form = ref({ name: '', barcode: '', price: 0, unit: 'шт' })
const units = ['шт', 'кг', 'л', 'уп', 'м']

watch(() => props.visible, async (v) => {
  if (v) {
    const hasRealBarcode = !!props.barcode
    form.value = {
      name: props.prefillName || '',
      barcode: props.barcode || '',
      price: 0,
      unit: 'шт'
    }
    error.value = ''
    if (!hasRealBarcode) generateBarcode()
    else await nextTick(() => renderPreview())
  }
})

function generateBarcode() {
  const base = String(Math.floor(Math.random() * 1_000_000_000_000)).padStart(12, '0')
  let sum = 0
  base.split('').forEach((d, i) => { sum += parseInt(d) * (i % 2 === 0 ? 1 : 3) })
  form.value.barcode = base + ((10 - (sum % 10)) % 10)
  nextTick(() => renderPreview())
}

function renderPreview() {
  nextTick(() => {
    if (!barcodeSvg.value || !form.value.barcode) return
    try {
      JsBarcode(barcodeSvg.value, form.value.barcode, {
        format: 'CODE128', width: 2, height: 40,
        displayValue: true, fontSize: 11,
        lineColor: '#e2e2f5', background: 'transparent'
      })
    } catch { /* invalid barcode string — ignore */ }
  })
}

async function create() {
  saving.value = true
  error.value = ''
  try {
    const res = await store.authFetch('/api/products', {
      method: 'POST',
      body: JSON.stringify({
        name: form.value.name,
        price: parseFloat(form.value.price) || 0,
        unit: form.value.unit || 'шт',
        barcode: form.value.barcode || null
      })
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data.error || 'Ошибка создания товара')
    emit('created', data)
  } catch (e) {
    error.value = e.message
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.7);
  z-index: 1100;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.modal-card {
  background: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: 20px;
  width: 100%;
  max-width: 400px;
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 18px 20px;
  border-bottom: 1px solid var(--border-subtle);
}

.modal-header h3 {
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
}

.modal-body { padding: 16px 20px; }

.fields {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 12px;
}

.field-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.field-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.text-input {
  height: 52px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-primary);
  font-size: 15px;
  padding: 0 14px;
  font-family: var(--font-sans);
  width: 100%;
  box-sizing: border-box;
}

.text-input:focus {
  outline: none;
  border-color: var(--border-focus);
}

.barcode-input { font-family: var(--font-mono); font-size: 13px; }

.barcode-row {
  display: flex;
  gap: 8px;
  align-items: center;
}

.barcode-row .text-input { flex: 1; }

.gen-btn {
  flex-shrink: 0;
  width: 52px; height: 52px;
  background: var(--bg-input);
  border: 1px solid rgba(123,104,238,0.4);
  border-radius: 12px;
  color: var(--text-accent);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
}

.gen-btn:active { background: var(--bg-hover); }

.barcode-preview {
  background: var(--bg-surface);
  border-radius: 10px;
  padding: 8px;
  display: flex;
  justify-content: center;
}

.unit-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding-top: 2px;
}

.unit-chip {
  padding: 6px 12px;
  border-radius: 8px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}

.unit-chip.active {
  background: var(--accent-glow);
  border-color: var(--accent-1);
  color: var(--text-accent);
}

.error-msg {
  padding: 0 20px 8px;
  color: var(--danger);
  font-size: 13px;
}

.modal-footer {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding: 16px 20px;
  border-top: 1px solid var(--border-subtle);
}

.btn-skip {
  height: 56px;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-secondary);
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
}

.btn-create {
  height: 56px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 12px;
  color: #fff;
  font-size: 15px;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-create:disabled, .btn-skip:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
