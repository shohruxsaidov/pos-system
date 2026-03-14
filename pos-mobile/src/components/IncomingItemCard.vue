<template>
  <div class="incoming-card">
    <div class="card-header">
      <div class="product-info">
        <div class="product-name">{{ item.product_name }}</div>
        <div class="product-barcode font-mono">{{ item.barcode || 'Без штрихкода' }}</div>
      </div>
      <button class="remove-btn" @click="$emit('remove')">✕</button>
    </div>

    <div class="card-fields">
      <!-- Qty -->
      <div class="field-group">
        <label class="field-label">Кол-во</label>
        <button class="field-input" @click="$emit('edit-field', 'qty', item.qty_received)">
          <span class="font-mono">{{ item.qty_received || 0 }}</span>
          <i class="pi pi-pencil edit-icon" />
        </button>
      </div>

      <!-- Cost -->
      <div class="field-group">
        <label class="field-label">Цена/ед.</label>
        <button class="field-input" @click="$emit('edit-field', 'cost', item.cost_per_unit)">
          <span class="font-mono">{{ formatAmount(item.cost_per_unit) }}</span>
          <i class="pi pi-pencil edit-icon" />
        </button>
      </div>

      <!-- Expiry -->
      <div class="field-group">
        <label class="field-label">Срок годн.</label>
        <button class="field-input" @click="$emit('edit-expiry')">
          <span>{{ item.expiry_date || 'Нет' }}</span>
          <i class="pi pi-calendar edit-icon" />
        </button>
      </div>
    </div>

    <!-- Unit selector -->
    <div class="unit-row">
      <span class="field-label">Единица</span>
      <div class="unit-chips">
        <button v-for="u in UNITS" :key="u" class="unit-chip" :class="{ active: item.unit === u }"
          @click="$emit('edit-unit', u)">{{ u }}</button>
      </div>
    </div>

    <button class="card-subtotal"
      @click="$emit('edit-field', 'total', (item.qty_received || 0) * (item.cost_per_unit || 0))">
      <span class="text-secondary">Сумма</span>
      <span class="font-mono text-accent"
        style="font-size:16px;font-weight:700;display:flex;align-items:center;gap:6px">
        {{ formatAmount((item.qty_received || 0) * (item.cost_per_unit || 0)) }}
        <i class="pi pi-pencil edit-icon" />
      </span>
    </button>
  </div>
</template>

<script setup>
defineProps({ item: Object })
defineEmits(['remove', 'edit-field', 'edit-expiry', 'edit-unit'])

const UNITS = ['шт', 'кг', 'г', 'л', 'упак', 'коробка']

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

.field-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.field-label {
  font-size: 11px;
  color: var(--text-muted);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

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

.edit-icon {
  color: var(--text-muted);
  font-size: 12px;
}

.unit-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.unit-row .field-label {
  flex-shrink: 0;
  font-size: 11px;
  color: var(--text-muted);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.unit-chips {
  display: flex;
  gap: 6px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 2px;
}

.unit-chip {
  min-height: 40px;
  padding: 0 14px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 20px;
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  flex-shrink: 0;
  transition: border-color 0.15s, background 0.15s, color 0.15s;
}

.unit-chip.active {
  border-color: var(--accent-1);
  background: rgba(123, 104, 238, 0.15);
  color: var(--text-accent);
}

.card-subtotal {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 10px;
  border-top: 1px solid var(--border-subtle);
  background: none;
  border-left: none;
  border-right: none;
  border-bottom: none;
  border-radius: 0;
  width: 100%;
  cursor: pointer;
}
</style>
