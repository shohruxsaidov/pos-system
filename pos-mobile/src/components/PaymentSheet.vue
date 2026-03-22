<template>
  <Teleport to="body">
    <div class="sheet-overlay" @click.self="$emit('close')">
      <div class="payment-sheet">
        <div class="sheet-handle" />

        <div class="sheet-header">
          <h3 class="sheet-title">Оплата</h3>
          <button class="sheet-close" @click="$emit('close')">
            <i class="pi pi-times" />
          </button>
        </div>

        <!-- Total -->
        <div class="payment-total">
          <span class="pt-label">К оплате</span>
          <span class="pt-value font-mono">{{ finalTotal.toFixed(2) }}</span>
        </div>

        <!-- Discount row -->
        <div class="discount-row" @click="showDiscountPad = true">
          <div class="discount-left">
            <i class="pi pi-tag" />
            <span class="discount-label">Скидка</span>
          </div>
          <span class="discount-value font-mono" :class="{ 'has-discount': discountAmount > 0 }">
            {{ discountAmount > 0 ? `− ${discountAmount.toFixed(2)}` : 'Нет' }}
          </span>
        </div>

        <!-- Payment method -->
        <div class="method-label">Способ оплаты</div>
        <div class="method-grid">
          <button
            v-for="m in methods"
            :key="m.value"
            class="method-btn"
            :class="{ active: method === m.value }"
            @click="method = m.value"
          >
            <i :class="m.icon" />
            <span>{{ m.label }}</span>
          </button>
        </div>


        <button
          class="confirm-btn"
          :disabled="processing"
          @click="confirm"
        >
          <i v-if="processing" class="pi pi-spin pi-spinner" />
          <i v-else class="pi pi-check" />
          {{ processing ? 'Обработка...' : 'Подтвердить оплату' }}
        </button>
      </div>
    </div>

    <!-- Discount numpad -->
    <BottomNumPad
      :visible="showDiscountPad"
      v-model="discountInput"
      label="Скидка"
      @close="showDiscountPad = false"
      @confirm="applyDiscount"
    />
  </Teleport>
</template>

<script setup>
import { ref, computed } from 'vue'
import BottomNumPad from './BottomNumPad.vue'

const props = defineProps({
  total: { type: Number, required: true },
  processing: Boolean
})

const emit = defineEmits(['confirm', 'close'])

const method = ref('cash')
const discountAmount = ref(0)
const discountInput = ref('')
const showDiscountPad = ref(false)

const finalTotal = computed(() => Math.max(0, props.total - discountAmount.value))

const methods = [
  { value: 'cash', label: 'Наличные', icon: 'pi pi-wallet' },
  { value: 'card', label: 'Карта', icon: 'pi pi-credit-card' },
  { value: 'transfer', label: 'Перевод', icon: 'pi pi-send' }
]

function applyDiscount() {
  const val = parseFloat(discountInput.value) || 0
  discountAmount.value = Math.min(val, props.total)
  showDiscountPad.value = false
}

function confirm() {
  emit('confirm', {
    method: method.value,
    tendered: finalTotal.value,
    changeGiven: 0,
    discount: discountAmount.value
  })
}
</script>

<style scoped>
.sheet-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.65);
  z-index: 600;
  display: flex;
  align-items: flex-end;
}

.payment-sheet {
  width: 100%;
  background: var(--bg-elevated);
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  padding: 0 20px 24px;
  padding-bottom: calc(24px + env(safe-area-inset-bottom));
}

.sheet-handle {
  width: 40px; height: 4px;
  background: var(--border-default);
  border-radius: 2px;
  margin: 12px auto 0;
}

.sheet-header {
  display: flex;
  align-items: center;
  padding: 16px 0 12px;
  border-bottom: 1px solid var(--border-subtle);
  margin-bottom: 20px;
}

.sheet-title { flex: 1; font-size: 18px; font-weight: 700; color: var(--text-primary); }

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

/* Total display */
.payment-total {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 24px;
}

.pt-label { font-size: 13px; color: var(--text-muted); margin-bottom: 4px; }

.pt-value {
  font-size: 42px;
  font-weight: 800;
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* Discount row */
.discount-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  margin-bottom: 20px;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.discount-left {
  display: flex;
  align-items: center;
  gap: 10px;
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 600;
}

.discount-left i { font-size: 16px; }

.discount-label { color: var(--text-secondary); }

.discount-value {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-muted);
}

.discount-value.has-discount { color: var(--danger); }

/* Method selector */
.method-label {
  font-size: 12px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 10px;
}

.method-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 20px;
}

.method-btn {
  height: 70px;
  background: var(--bg-surface);
  border: 2px solid var(--border-default);
  border-radius: 16px;
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  transition: all 0.15s;
  -webkit-tap-highlight-color: transparent;
}

.method-btn i { font-size: 20px; }

.method-btn.active {
  background: rgba(123,104,238,0.12);
  border-color: var(--accent-1);
  color: var(--accent-1);
}


/* Confirm */
.confirm-btn {
  width: 100%;
  height: 64px;
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
  transition: all 0.15s;
}

.confirm-btn:disabled { opacity: 0.45; cursor: not-allowed; }
</style>
