<template>
  <div class="incoming-card">
    <div class="card-header">
      <div class="product-info">
        <div class="product-name">{{ item.product_name }}</div>
        <div class="product-barcode font-mono">{{ item.barcode || 'No barcode' }}</div>
      </div>
      <button class="remove-btn" @click="$emit('remove')">✕</button>
    </div>

    <div class="card-fields">
      <!-- Qty -->
      <div class="field-group">
        <label class="field-label">Qty</label>
        <button class="field-input" @click="$emit('edit-field', 'qty', item.qty_received)">
          <span class="font-mono">{{ item.qty_received || 0 }}</span>
          <i class="pi pi-pencil edit-icon" />
        </button>
      </div>

      <!-- Cost -->
      <div class="field-group">
        <label class="field-label">Cost/Unit</label>
        <button class="field-input" @click="$emit('edit-field', 'cost', item.cost_per_unit)">
          <span class="font-mono">₱{{ formatAmount(item.cost_per_unit) }}</span>
          <i class="pi pi-pencil edit-icon" />
        </button>
      </div>

      <!-- Expiry -->
      <div class="field-group">
        <label class="field-label">Expiry</label>
        <button class="field-input" @click="$emit('edit-expiry')">
          <span>{{ item.expiry_date || 'None' }}</span>
          <i class="pi pi-calendar edit-icon" />
        </button>
      </div>
    </div>

    <div class="card-subtotal">
      <span class="text-secondary">Subtotal</span>
      <span class="font-mono text-accent" style="font-size:16px;font-weight:700">
        ₱{{ formatAmount((item.qty_received || 0) * (item.cost_per_unit || 0)) }}
      </span>
    </div>
  </div>
</template>

<script setup>
defineProps({ item: Object })
defineEmits(['remove', 'edit-field', 'edit-expiry'])

function formatAmount(n) { return parseFloat(n || 0).toFixed(2) }
</script>

<style scoped>
.incoming-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.product-name {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

.product-barcode {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

.remove-btn {
  width: 32px;
  height: 32px;
  background: var(--danger-bg);
  border: none;
  border-radius: 8px;
  color: var(--danger);
  cursor: pointer;
  font-size: 14px;
  flex-shrink: 0;
}

.card-fields {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

.field-group { display: flex; flex-direction: column; gap: 4px; }
.field-label { font-size: 11px; color: var(--text-muted); font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }

.field-input {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  color: var(--text-primary);
  font-size: 15px;
  cursor: pointer;
  min-height: 48px;
}

.edit-icon { color: var(--text-muted); font-size: 12px; }

.card-subtotal {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 10px;
  border-top: 1px solid var(--border-subtle);
}
</style>
