<template>
  <Dialog
    v-model:visible="visible"
    modal
    header="Payment"
    :style="{ width: '520px' }"
    :closable="!processing"
  >
    <div class="payment-content">
      <!-- Order Summary -->
      <div class="payment-summary">
        <div class="summary-row">
          <span class="text-secondary">Subtotal</span>
          <span class="font-mono">₱{{ formatAmount(cart.subtotal) }}</span>
        </div>
        <div class="summary-row" v-if="cart.discount > 0">
          <span class="text-secondary">Discount</span>
          <span class="font-mono text-danger">-₱{{ formatAmount(cart.discount) }}</span>
        </div>
        <div class="summary-row total-row">
          <span class="text-primary" style="font-weight:700">Total</span>
          <span class="font-mono gradient-text" style="font-size:28px;font-weight:700">
            ₱{{ formatAmount(cart.total) }}
          </span>
        </div>
      </div>

      <!-- Payment Method -->
      <div class="field-group">
        <label class="field-label">Payment Method</label>
        <SelectButton
          v-model="method"
          :options="methods"
          option-label="label"
          option-value="value"
          class="method-selector"
        />
      </div>

      <!-- Tendered Amount (Cash only) -->
      <div v-if="method === 'cash'" class="field-group">
        <label class="field-label">Tendered Amount</label>
        <div class="tendered-input">
          <span class="tendered-prefix">₱</span>
          <input
            v-model="tendered"
            type="text"
            inputmode="none"
            class="tendered-field font-mono"
            placeholder="0.00"
            @focus="showNumpad = true"
          />
        </div>
        <div v-if="parseFloat(tendered) >= cart.total" class="change-display">
          <span class="text-secondary">Change</span>
          <span class="font-mono text-success" style="font-size:20px;font-weight:700">
            ₱{{ formatAmount(change) }}
          </span>
        </div>
        <div v-else-if="tendered && parseFloat(tendered) < cart.total" class="insufficient">
          <i class="pi pi-exclamation-triangle" />
          <span>Insufficient amount</span>
        </div>
        <NumPad
          v-if="showNumpad"
          v-model="tendered"
          :show-display="false"
          style="margin-top:12px"
        />
      </div>

      <!-- Reference (Card/GCash) -->
      <div v-if="method !== 'cash'" class="field-group">
        <label class="field-label">Reference / Auth Code</label>
        <InputText
          v-model="reference"
          placeholder="Optional reference number"
          class="w-full"
        />
      </div>

      <!-- Receipt Toggle -->
      <div class="receipt-toggle">
        <label class="field-label">Print Receipt</label>
        <ToggleSwitch v-model="printReceipt" />
      </div>
    </div>

    <template #footer>
      <Button
        label="Cancel"
        class="p-button-secondary"
        @click="close"
        :disabled="processing"
      />
      <Button
        label="Confirm Payment"
        class="touch-lg"
        :loading="processing"
        :disabled="!canConfirm"
        @click="confirm"
        style="flex:1"
      />
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
import InputText from 'primevue/inputtext'
import ToggleSwitch from 'primevue/toggleswitch'

const props = defineProps({ modelValue: Boolean })
const emit = defineEmits(['update:modelValue', 'paid'])

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

const cart = useCartStore()
const method = ref('cash')
const tendered = ref('')
const reference = ref('')
const printReceipt = ref(true)
const processing = ref(false)
const showNumpad = ref(false)

const methods = [
  { label: '💵 Cash', value: 'cash' },
  { label: '💳 Card', value: 'card' },
  { label: '📱 GCash', value: 'gcash' }
]

watch(visible, (v) => {
  if (v) {
    method.value = 'cash'
    tendered.value = ''
    reference.value = ''
    showNumpad.value = false
    processing.value = false
  }
})

const change = computed(() => {
  const t = parseFloat(tendered.value) || 0
  return Math.max(0, t - cart.total)
})

const canConfirm = computed(() => {
  if (method.value === 'cash') {
    return parseFloat(tendered.value) >= cart.total
  }
  return true
})

function formatAmount(n) {
  return parseFloat(n || 0).toFixed(2)
}

function close() {
  visible.value = false
}

async function confirm() {
  if (!canConfirm.value || processing.value) return
  processing.value = true

  const payload = {
    method: method.value,
    tendered: method.value === 'cash' ? parseFloat(tendered.value) : cart.total,
    change_given: method.value === 'cash' ? change.value : 0,
    reference: reference.value || null,
    printReceipt: printReceipt.value
  }

  emit('paid', payload)
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

.change-display {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: var(--success-bg);
  border: 1px solid var(--success-border);
  border-radius: 10px;
}

.insufficient {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--warning);
  font-size: 13px;
  padding: 8px 12px;
  background: var(--warning-bg);
  border-radius: 8px;
}

.receipt-toggle {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
