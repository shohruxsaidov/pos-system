<template>
  <Teleport to="body">
    <Transition name="sheet-slide">
      <div v-if="visible" class="sheet-overlay" @click.self="$emit('update:visible', false)">
        <div class="cart-sheet">
          <div class="sheet-handle" />

          <div class="sheet-header">
            <h3 class="sheet-title">Корзина</h3>
            <span v-if="items.length > 0" class="item-count">{{ items.length }} поз.</span>
            <button class="sheet-close" @click="$emit('update:visible', false)">
              <i class="pi pi-times" />
            </button>
          </div>

          <div v-if="items.length === 0" class="cart-empty">
            <i class="pi pi-shopping-cart" style="font-size: 48px; color: var(--text-muted)" />
            <p>Корзина пуста</p>
            <p class="empty-hint">Нажмите на товар чтобы добавить</p>
          </div>

          <div v-else class="cart-items">
            <div v-for="(item, idx) in items" :key="item.product_id" class="cart-row">
              <div class="cart-row-main">
                <span class="cart-row-name">{{ item.name }}</span>
                <span class="cart-row-unit-price">{{ item.unit_price.toFixed(2) }}/шт</span>
              </div>
              <div class="cart-row-controls">
                <div class="qty-controls">
                  <button class="qty-btn minus" @click="$emit('change-qty', idx, -1)">−</button>
                  <button class="qty-num qty-num-btn font-mono" @click="openQtyEdit(idx)">{{ Number(item.qty).toFixed(2) }}</button>
                  <button class="qty-btn plus" @click="$emit('change-qty', idx, 1)">+</button>
                </div>
                <button class="cart-row-subtotal font-mono subtotal-btn" @click="openAmountEdit(idx)">{{ (item.unit_price * item.qty).toFixed(2) }}</button>
                <button class="remove-btn" @click="$emit('remove', idx)">
                  <i class="pi pi-trash" />
                </button>
              </div>
            </div>
          </div>

          <div class="cart-footer">
            <div class="total-row">
              <span class="total-label">Итого</span>
              <span class="total-value font-mono">{{ total.toFixed(2) }}</span>
            </div>
            <button
              class="checkout-btn"
              :disabled="items.length === 0"
              @click="$emit('checkout')"
            >
              <i class="pi pi-credit-card" />
              Оформить заказ
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Direct Qty NumPad -->
    <BottomNumPad
      v-model="qtyValue"
      :visible="qtyVisible"
      :label="qtyEditingIdx !== null && items[qtyEditingIdx] ? `${items[qtyEditingIdx].name} · количество` : 'Количество'"
      @close="qtyVisible = false"
      @confirm="confirmQty"
    />

    <!-- Amount → Qty NumPad -->
    <BottomNumPad
      v-model="amountValue"
      :visible="amountVisible"
      :label="amountLabel"
      @close="amountVisible = false"
      @confirm="confirmAmount"
    />
  </Teleport>
</template>

<script setup>
import { ref, computed } from 'vue'
import BottomNumPad from './BottomNumPad.vue'

const props = defineProps({
  visible: Boolean,
  items: { type: Array, default: () => [] }
})

const emit = defineEmits(['update:visible', 'change-qty', 'remove', 'checkout', 'set-qty'])

const total = computed(() => props.items.reduce((sum, i) => sum + i.unit_price * i.qty, 0))

// Direct qty edit
const qtyVisible = ref(false)
const qtyValue = ref('0')
const qtyEditingIdx = ref(null)

function openQtyEdit(idx) {
  qtyEditingIdx.value = idx
  qtyValue.value = Number(props.items[idx]?.qty || 0).toFixed(2)
  qtyVisible.value = true
}

function confirmQty(val) {
  const qty = Math.round(parseFloat(val || 0) * 100) / 100
  if (qty <= 0) {
    emit('remove', qtyEditingIdx.value)
  } else {
    emit('set-qty', qtyEditingIdx.value, qty)
  }
  qtyVisible.value = false
}

// Amount → qty edit
const amountVisible = ref(false)
const amountValue = ref('0')
const editingIdx = ref(null)

const editingItem = computed(() => editingIdx.value !== null ? props.items[editingIdx.value] : null)

const computedQtyFromAmount = computed(() => {
  const amount = parseFloat(amountValue.value) || 0
  const price = editingItem.value?.unit_price || 1
  if (price <= 0 || amount <= 0) return '0.00'
  return (Math.round((amount / price) * 100) / 100).toFixed(2)
})

const amountLabel = computed(() => {
  if (!editingItem.value) return 'Введите сумму'
  return `${editingItem.value.name} · ${editingItem.value.unit_price.toFixed(2)}/шт → ${computedQtyFromAmount.value} шт`
})

function openAmountEdit(idx) {
  editingIdx.value = idx
  amountValue.value = '0'
  amountVisible.value = true
}

function confirmAmount(val) {
  const qty = parseFloat((Math.round((parseFloat(val || 0) / (editingItem.value?.unit_price || 1)) * 100) / 100).toFixed(2)) || 0
  if (qty <= 0) {
    emit('remove', editingIdx.value)
  } else {
    emit('set-qty', editingIdx.value, qty)
  }
  amountVisible.value = false
}
</script>

<style scoped>
.sheet-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 500;
  display: flex;
  align-items: flex-end;
}

.cart-sheet {
  width: 100%;
  background: var(--bg-elevated);
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  max-height: 85vh;
  display: flex;
  flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom);
}

.sheet-handle {
  width: 40px; height: 4px;
  background: var(--border-default);
  border-radius: 2px;
  margin: 12px auto 0;
  flex-shrink: 0;
}

.sheet-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 16px 20px 12px;
  border-bottom: 1px solid var(--border-subtle);
  flex-shrink: 0;
}

.sheet-title { font-size: 18px; font-weight: 700; color: var(--text-primary); flex: 1; }
.item-count { font-size: 13px; color: var(--text-muted); }

.sheet-close {
  width: 36px; height: 36px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 10px;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Empty state */
.cart-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 48px 20px;
  color: var(--text-muted);
}
.empty-hint { font-size: 13px; }

/* Items */
.cart-items {
  flex: 1;
  overflow-y: auto;
  padding: 8px 16px;
}

.cart-row {
  padding: 12px 0;
  border-bottom: 1px solid var(--border-subtle);
}

.cart-row:last-child { border-bottom: none; }

.cart-row-main {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
}

.cart-row-name {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
  flex: 1;
}

.cart-row-unit-price { font-size: 12px; color: var(--text-muted); white-space: nowrap; }

.cart-row-controls {
  display: flex;
  align-items: center;
  gap: 12px;
}

.qty-controls {
  display: flex;
  align-items: center;
  gap: 0;
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  overflow: hidden;
}

.qty-btn {
  width: 44px; height: 44px;
  background: transparent;
  border: none;
  color: var(--text-primary);
  font-size: 20px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  -webkit-tap-highlight-color: transparent;
}

.qty-btn.minus { color: var(--danger); }
.qty-btn.plus { color: var(--success); }
.qty-btn:active { background: var(--bg-hover); }

.qty-num {
  min-width: 36px;
  text-align: center;
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

.qty-num-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 8px;
  cursor: pointer;
  padding: 4px 2px;
  -webkit-tap-highlight-color: transparent;
  transition: all 0.15s;
}

.qty-num-btn:active {
  border-color: var(--accent-1);
  background: var(--accent-glow);
  color: var(--text-accent);
}

.cart-row-subtotal {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-accent);
  flex: 1;
  text-align: right;
}

.subtotal-btn {
  background: none;
  border: 1px solid transparent;
  border-radius: 8px;
  cursor: pointer;
  padding: 4px 8px;
  -webkit-tap-highlight-color: transparent;
  transition: all 0.15s;
}

.subtotal-btn:active {
  border-color: var(--accent-1);
  background: var(--accent-glow);
}

.remove-btn {
  width: 36px; height: 36px;
  background: var(--danger-bg);
  border: 1px solid rgba(255,92,92,0.2);
  border-radius: 10px;
  color: var(--danger);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

/* Footer */
.cart-footer {
  padding: 16px 20px;
  border-top: 1px solid var(--border-subtle);
  flex-shrink: 0;
}

.total-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
}

.total-label { font-size: 16px; color: var(--text-secondary); }

.total-value {
  font-size: 28px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.checkout-btn {
  width: 100%;
  height: 60px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 16px;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  box-shadow: 0 4px 20px rgba(123,104,238,0.35);
}

.checkout-btn:disabled { opacity: 0.4; cursor: not-allowed; }

/* Transition */
.sheet-slide-enter-from,
.sheet-slide-leave-to { transform: translateY(100%); }
.sheet-slide-enter-active,
.sheet-slide-leave-active { transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1); }
</style>
