<template>
  <div v-if="visible" class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-card">
      <div class="modal-header">
        <h3>Product Not Found</h3>
        <button class="close-btn" @click="$emit('close')">✕</button>
      </div>

      <div class="modal-body">
        <p class="text-secondary">Barcode <span class="font-mono text-accent">{{ barcode }}</span> not found in the system.</p>
        <p class="text-secondary" style="margin-top:8px">Add it manually or skip:</p>

        <div class="fields">
          <div class="field-group">
            <label class="field-label">Product Name *</label>
            <input v-model="form.name" class="text-input" placeholder="Product name" />
          </div>
          <div class="field-group">
            <label class="field-label">Price</label>
            <input v-model="form.price" type="number" class="text-input" placeholder="0.00" />
          </div>
          <div class="field-group">
            <label class="field-label">Unit</label>
            <input v-model="form.unit" class="text-input" placeholder="pcs" />
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-skip" @click="$emit('skip')">Skip This Item</button>
        <button class="btn-create" :disabled="!form.name" @click="create">Create & Add</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({ visible: Boolean, barcode: String })
const emit = defineEmits(['close', 'skip', 'created'])

const form = ref({ name: '', price: 0, unit: 'pcs' })

watch(() => props.visible, v => {
  if (v) form.value = { name: '', price: 0, unit: 'pcs' }
})

function create() {
  emit('created', { ...form.value, barcode: props.barcode })
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.7);
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

.modal-header h3 { font-size: 17px; font-weight: 700; color: var(--text-primary); }

.close-btn {
  width: 32px; height: 32px;
  background: var(--bg-surface);
  border: none; border-radius: 8px;
  color: var(--text-secondary);
  cursor: pointer;
}

.modal-body { padding: 16px 20px; }

.fields { display: flex; flex-direction: column; gap: 12px; margin-top: 16px; }
.field-group { display: flex; flex-direction: column; gap: 6px; }
.field-label { font-size: 12px; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }

.text-input {
  height: 56px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-primary);
  font-size: 16px;
  padding: 0 16px;
  font-family: var(--font-sans);
  width: 100%;
}

.text-input:focus { outline: none; border-color: var(--border-focus); }

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
}

.btn-create:disabled { opacity: 0.5; }
</style>
