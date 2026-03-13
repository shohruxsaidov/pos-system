<template>
  <div class="product-card" :id="`product-${product.id}`">
    <div class="card-main">
      <div class="product-info">
        <div class="product-name">{{ product.name }}</div>
        <div class="product-barcode font-mono">{{ product.barcode || '—' }}</div>
        <div class="product-category text-muted">{{ product.category_name || 'Uncategorized' }}</div>
      </div>
      <div class="card-right">
        <div class="product-price font-mono">{{ formatPrice(product.price) }}</div>
        <div :class="['stock-badge', stockClass]">{{ stockLabel }}</div>
      </div>
    </div>

    <div class="card-actions">
      <button class="action-btn adjust-btn" @click="$emit('adjust')">
        <i class="pi pi-chart-line" />
        <span>Adjust</span>
      </button>
      <button class="action-btn print-btn" @click="$emit('print')">
        <i class="pi pi-print" />
        <span>Print</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({ product: Object })
defineEmits(['adjust', 'print'])

const stockLabel = computed(() => {
  const q = props.product.stock_qty
  if (q < 0) return `Oversold (${q})`
  if (q === 0) return 'Out of Stock'
  if (q <= 5) return `Low (${q})`
  return `${q} in stock`
})

const stockClass = computed(() => {
  const q = props.product.stock_qty
  if (q < 0) return 'danger'
  if (q === 0) return 'danger'
  if (q <= 5) return 'warning'
  return 'success'
})

function formatPrice(n) { return parseFloat(n || 0).toFixed(2) }
</script>

<style scoped>
.product-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 14px 16px;
  transition: border-color 0.2s;
}

.product-card.highlight {
  border-color: var(--accent-1);
  animation: highlight-pulse 2s ease-in-out;
}

@keyframes highlight-pulse {
  0%, 100% { border-color: var(--accent-1); }
  50% { border-color: var(--accent-3); box-shadow: 0 0 20px var(--accent-glow); }
}

.card-main { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; }

.product-name { font-size: 15px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px; }
.product-barcode { font-size: 12px; color: var(--text-muted); margin-bottom: 2px; }
.product-category { font-size: 12px; }

.card-right { display: flex; flex-direction: column; align-items: flex-end; gap: 6px; }
.product-price { font-size: 16px; font-weight: 700; color: var(--text-accent); }

.card-actions { display: flex; gap: 8px; }

.action-btn {
  flex: 1;
  height: 44px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  border: 1px solid var(--border-default);
  -webkit-tap-highlight-color: transparent;
  transition: all 0.12s;
}

.action-btn:active { transform: scale(0.97); }

.adjust-btn { background: var(--bg-input); color: var(--text-secondary); }
.adjust-btn:hover { color: var(--text-accent); border-color: var(--accent-1); }

.print-btn { background: var(--bg-input); color: var(--text-secondary); }
.print-btn:hover { color: var(--text-accent); border-color: var(--accent-1); }

.stock-badge { display: inline-flex; padding: 4px 10px; border-radius: 8px; font-size: 12px; font-weight: 600; font-family: var(--font-mono); }
.stock-badge.success { background: var(--success-bg); color: var(--success); }
.stock-badge.warning { background: var(--warning-bg); color: var(--warning); }
.stock-badge.danger { background: var(--danger-bg); color: var(--danger); }
</style>
