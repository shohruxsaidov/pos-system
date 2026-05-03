<template>
  <Dialog v-model:visible="visible" modal header="Payment" :style="{ width: '520px' }" :closable="!processing">
    <div class="payment-content">
      <!-- Order Summary -->
      <div class="payment-summary">
        <div class="summary-row">
          <span class="text-secondary">Subtotal</span>
          <span class="font-mono">{{ formatAmount(cart.subtotal) }}</span>
        </div>
        <div class="summary-row" v-if="cart.discount > 0">
          <span class="text-secondary">Discount</span>
          <span class="font-mono text-danger">{{ formatAmount(cart.discount) }}</span>
        </div>
        <div class="summary-row total-row">
          <span class="text-primary" style="font-weight:700">Всего</span>
          <span class="font-mono gradient-text" style="font-size:28px;font-weight:700">
            {{ formatAmount(cart.total) }}
          </span>
        </div>
      </div>

      <!-- Discount -->
      <div class="field-group">
        <label class="field-label">Скидка</label>
        <div class="tendered-input" @click="toggleField('discount')" style="cursor:pointer">
          <span class="tendered-prefix">−</span>
          <input
            class="tendered-field"
            :value="discountInput || '0'"
            readonly
            inputmode="none"
            style="cursor:pointer"
          />
        </div>
        <NumPad v-if="activeField === 'discount'" v-model="discountInput" :show-display="false" @update:modelValue="applyDiscount" />
      </div>

      <!-- Single payment mode -->
      <div v-if="!isSplit" class="field-group">
        <label class="field-label">Способ оплаты</label>
        <SelectButton v-model="splits[0].method" :options="methods" option-label="label" option-value="value" class="method-selector" />
        <button class="split-trigger" @click="addSplit">
          <i class="pi pi-plus-circle" />
          Разделить оплату
        </button>
      </div>

      <!-- Split payment mode -->
      <div v-else class="field-group">
        <label class="field-label">Разделённая оплата</label>

        <div v-for="(split, idx) in splits" :key="idx" class="split-row">
          <SelectButton
            v-model="split.method"
            :options="methods"
            option-label="label"
            option-value="value"
            class="split-method"
          />
          <div
            class="split-amount-box"
            :class="{
              active: activeField === `split-${idx}`,
              readonly: idx === splits.length - 1
            }"
            @click="idx < splits.length - 1 ? toggleField(`split-${idx}`) : null"
          >
            <span class="font-mono">
              {{ idx === splits.length - 1 ? formatAmount(lastSplitAmount) : (split.amount || '0') }}
            </span>
            <i v-if="idx < splits.length - 1" class="pi pi-pencil edit-icon" />
            <i v-else class="pi pi-lock lock-icon" />
          </div>
          <button class="remove-btn" @click="removeSplit(idx)" title="Удалить">
            <i class="pi pi-times" />
          </button>
        </div>

        <NumPad
          v-if="activeField && activeField.startsWith('split-')"
          v-model="activeSplitAmount"
          :show-display="false"
        />

        <button class="split-trigger" @click="addSplit">
          <i class="pi pi-plus-circle" />
          Ещё способ оплаты
        </button>

        <div class="remaining-row" :class="{ danger: lastSplitAmount < -0.01, ok: Math.abs(lastSplitAmount) < 0.01 }">
          <span>{{ lastSplitAmount < -0.01 ? 'Переплата' : 'Остаток' }}</span>
          <span class="font-mono">{{ formatAmount(Math.abs(lastSplitAmount)) }}</span>
        </div>
      </div>

      <!-- Receipt Toggle -->
      <div class="receipt-toggle">
        <label class="field-label">Печать чека</label>
        <ToggleSwitch v-model="printReceipt" />
      </div>
    </div>

    <template #footer>
      <Button label="Отмена" class="p-button-secondary touch-lg" @click="close" :disabled="processing" />
      <Button label="Подтвердить" class="touch-lg" :loading="processing" :disabled="!canConfirm" @click="confirm"
        style="flex:1" />
    </template>
  </Dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useCartStore } from '../stores/cart.js'
import NumPad from './NumPad.vue'
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'
import SelectButton from 'primevue/selectbutton'
import ToggleSwitch from 'primevue/toggleswitch'

const props = defineProps({ modelValue: Boolean })
const emit = defineEmits(['update:modelValue', 'paid'])

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

const cart = useCartStore()
const splits = ref([{ method: 'cash' }])
const printReceipt = ref(true)
const processing = ref(false)
const discountInput = ref('')
const activeField = ref(null) // 'discount' | 'split-0' | 'split-1' | ...

const methods = [
  { label: 'Наличные', value: 'cash' },
  { label: 'Карта', value: 'card' },
  { label: 'Перевод', value: 'transfer' },
]

const isSplit = computed(() => splits.value.length > 1)

// Last split amount is auto-computed as remainder — user can't type it directly
const lastSplitAmount = computed(() => {
  if (!isSplit.value) return cart.total
  const editableTotal = splits.value.slice(0, -1).reduce((s, p) => s + (parseFloat(p.amount) || 0), 0)
  return cart.total - editableTotal
})

const canConfirm = computed(() => {
  if (!isSplit.value) return true
  return lastSplitAmount.value >= -0.01 // no overpayment in editable splits
})

const activeSplitIdx = computed(() => {
  if (!activeField.value?.startsWith('split-')) return null
  return parseInt(activeField.value.replace('split-', ''))
})

const activeSplitAmount = computed({
  get: () => activeSplitIdx.value !== null ? (splits.value[activeSplitIdx.value]?.amount || '') : '',
  set: (v) => {
    if (activeSplitIdx.value !== null) splits.value[activeSplitIdx.value].amount = v
  }
})

watch(visible, (v) => {
  if (v) {
    splits.value = [{ method: 'cash' }]
    printReceipt.value = true
    processing.value = false
    discountInput.value = ''
    activeField.value = null
    cart.setDiscount(0)
  }
})

function applyDiscount(val) {
  const amount = parseFloat(val) || 0
  cart.setDiscount(Math.min(amount, cart.subtotal))
}

function toggleField(field) {
  activeField.value = activeField.value === field ? null : field
}

function addSplit() {
  splits.value.push({ method: 'cash', amount: '' })
  // Activate the new second-to-last split so user can type into it
  activeField.value = `split-${splits.value.length - 2}`
}

function removeSplit(idx) {
  splits.value.splice(idx, 1)
  if (splits.value.length === 1) {
    activeField.value = null
  } else if (activeField.value === `split-${idx}`) {
    activeField.value = null
  }
}

function formatAmount(n) {
  return parseFloat(n || 0).toFixed(2)
}

function close() {
  visible.value = false
}

async function confirm() {
  if (!canConfirm.value || processing.value) return
  processing.value = true

  let payments
  if (isSplit.value) {
    payments = [
      ...splits.value.slice(0, -1).map(s => ({
        method: s.method,
        amount: parseFloat(s.amount) || 0,
      })),
      {
        method: splits.value[splits.value.length - 1].method,
        amount: parseFloat(lastSplitAmount.value.toFixed(2)),
      }
    ]
  } else {
    payments = [{ method: splits.value[0].method, amount: cart.total }]
  }

  emit('paid', { payments, printReceipt: printReceipt.value })
  processing.value = false
  visible.value = false
}
</script>

<style scoped>
.payment-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.payment-summary {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 16px 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.summary-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 15px;
}

.total-row {
  padding-top: 12px;
  border-top: 1px solid var(--border-subtle);
  margin-top: 4px;
}

.field-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.field-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.method-selector {
  display: flex;
  gap: 8px;
}

.tendered-input {
  display: flex;
  align-items: center;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  overflow: hidden;
}

.tendered-prefix {
  padding: 0 14px;
  color: var(--text-secondary);
  font-size: 18px;
  font-family: var(--font-mono);
}

.tendered-field {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-primary);
  font-family: var(--font-mono);
  font-size: 22px;
  font-weight: 600;
  padding: 12px 14px 12px 0;
}

/* Split payment */
.split-trigger {
  display: flex;
  align-items: center;
  gap: 6px;
  background: none;
  border: 1px dashed var(--border-default);
  border-radius: 10px;
  color: var(--text-accent);
  font-size: 14px;
  font-weight: 500;
  padding: 10px 16px;
  cursor: pointer;
  width: 100%;
  justify-content: center;
  transition: border-color 0.15s, background 0.15s;
}

.split-trigger:hover {
  border-color: var(--accent-1);
  background: var(--accent-glow);
}

.split-row {
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  padding: 10px 12px;
}

.split-method {
  flex: 1;
}

.split-amount-box {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  padding: 8px 14px;
  min-width: 110px;
  cursor: pointer;
  transition: border-color 0.15s;
}

.split-amount-box.active {
  border-color: var(--border-focus);
  box-shadow: 0 0 0 2px var(--accent-glow);
}

.split-amount-box.readonly {
  cursor: default;
  opacity: 0.7;
}

.split-amount-box .font-mono {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  flex: 1;
}

.edit-icon {
  font-size: 11px;
  color: var(--text-muted);
}

.lock-icon {
  font-size: 11px;
  color: var(--text-muted);
}

.remove-btn {
  background: none;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 6px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  transition: color 0.15s, background 0.15s;
}

.remove-btn:hover {
  color: var(--danger);
  background: var(--danger-bg);
}

.remaining-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  border-radius: 10px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  font-size: 14px;
  color: var(--text-secondary);
}

.remaining-row.ok {
  background: var(--success-bg);
  border-color: transparent;
  color: var(--success);
}

.remaining-row.danger {
  background: var(--danger-bg);
  border-color: transparent;
  color: var(--danger);
}

.receipt-toggle {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
