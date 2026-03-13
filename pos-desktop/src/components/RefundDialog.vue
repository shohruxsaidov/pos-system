<template>
  <Dialog
    v-model:visible="visible"
    modal
    header="Process Refund"
    :style="{ width: '680px' }"
  >
    <div class="refund-content" v-if="transactionData">
      <div class="refund-info">
        <span class="text-secondary">Transaction:</span>
        <span class="font-mono text-accent">{{ transactionData.transaction?.ref_no }}</span>
        <span class="text-secondary">Total:</span>
        <span class="font-mono">₱{{ formatAmount(transactionData.transaction?.total) }}</span>
      </div>

      <!-- Selectable Items -->
      <div class="items-section">
        <label class="section-label">Select Items to Refund</label>
        <DataTable
          :value="transactionData.items"
          v-model:selection="selectedItems"
          dataKey="product_id"
          :scrollable="true"
          scroll-height="240px"
        >
          <Column selectionMode="multiple" style="width:50px" />
          <Column field="product_name" header="Product" />
          <Column field="unit_price" header="Price">
            <template #body="{ data }">
              <span class="font-mono">₱{{ formatAmount(data.unit_price) }}</span>
            </template>
          </Column>
          <Column field="qty_refundable" header="Max Qty" />
          <Column header="Refund Qty">
            <template #body="{ data }">
              <InputNumber
                v-model="refundQtys[data.product_id]"
                :min="0"
                :max="data.qty_refundable"
                :disabled="!isSelected(data.product_id)"
                style="width:90px"
                inputmode="none"
              />
            </template>
          </Column>
          <Column header="Subtotal">
            <template #body="{ data }">
              <span class="font-mono">
                ₱{{ formatAmount((refundQtys[data.product_id] || 0) * data.unit_price) }}
              </span>
            </template>
          </Column>
        </DataTable>
      </div>

      <div class="refund-total">
        <span class="text-secondary">Total Refund:</span>
        <span class="font-mono gradient-text" style="font-size:22px;font-weight:700">
          ₱{{ formatAmount(refundTotal) }}
        </span>
      </div>

      <!-- Reason -->
      <div class="field-group">
        <label class="field-label">Reason</label>
        <Select
          v-model="reason"
          :options="reasons"
          placeholder="Select reason"
          class="w-full"
        />
      </div>

      <!-- Manager PIN -->
      <div class="field-group">
        <label class="field-label">Manager PIN Authorization</label>
        <InputOtp v-model="managerPin" :length="4" mask />
        <p class="hint-text">Enter manager or admin PIN to authorize</p>
      </div>
    </div>

    <div v-else class="loading-state">
      <i class="pi pi-spin pi-spinner" style="font-size:32px;color:var(--accent-1)" />
      <span>Loading transaction...</span>
    </div>

    <template #footer>
      <Button label="Cancel" class="p-button-secondary" @click="visible = false" />
      <Button
        label="Process Refund"
        icon="pi pi-replay"
        class="touch-lg"
        :disabled="!canRefund"
        :loading="processing"
        @click="processRefund"
        style="flex:1"
      />
    </template>
  </Dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useApi } from '../composables/useApi.js'
import Dialog from 'primevue/dialog'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import Select from 'primevue/select'
import InputNumber from 'primevue/inputnumber'
import InputOtp from 'primevue/inputotp'

const props = defineProps({
  modelValue: Boolean,
  transactionId: Number
})
const emit = defineEmits(['update:modelValue', 'refunded'])

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

const api = useApi()
const transactionData = ref(null)
const selectedItems = ref([])
const refundQtys = ref({})
const reason = ref('')
const managerPin = ref('')
const processing = ref(false)

const reasons = [
  'Wrong item',
  'Damaged product',
  'Customer changed mind',
  'Overcharge',
  'Expired product',
  'Other'
]

watch([visible, () => props.transactionId], async ([vis, id]) => {
  if (vis && id) {
    transactionData.value = null
    selectedItems.value = []
    refundQtys.value = {}
    reason.value = ''
    managerPin.value = ''

    try {
      const data = await api.get(`/api/transactions/${id}/refundable`)
      transactionData.value = data
      // Default qty = max refundable
      for (const item of data.items) {
        refundQtys.value[item.product_id] = item.qty_refundable
      }
    } catch (e) {
      console.error('Failed to load refundable items:', e)
    }
  }
})

function isSelected(productId) {
  return selectedItems.value.some(i => i.product_id === productId)
}

const refundTotal = computed(() => {
  return selectedItems.value.reduce((sum, item) => {
    const qty = refundQtys.value[item.product_id] || 0
    return sum + qty * parseFloat(item.unit_price)
  }, 0)
})

const canRefund = computed(() =>
  selectedItems.value.length > 0 &&
  reason.value &&
  managerPin.value?.length === 4 &&
  refundTotal.value > 0
)

function formatAmount(n) {
  return parseFloat(n || 0).toFixed(2)
}

async function processRefund() {
  if (!canRefund.value || processing.value) return
  processing.value = true

  try {
    const items = selectedItems.value
      .filter(item => (refundQtys.value[item.product_id] || 0) > 0)
      .map(item => ({
        product_id: item.product_id,
        product_name: item.product_name,
        qty_returned: refundQtys.value[item.product_id]
      }))

    await api.post('/api/refunds', {
      original_txn_id: props.transactionId,
      items,
      reason: reason.value,
      manager_pin: managerPin.value
    })

    emit('refunded')
    visible.value = false
  } catch (e) {
    alert(e.message)
  } finally {
    processing.value = false
  }
}
</script>

<style scoped>
.refund-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.refund-info {
  display: grid;
  grid-template-columns: auto 1fr auto 1fr;
  gap: 8px 16px;
  align-items: center;
  background: var(--bg-surface);
  border-radius: 12px;
  padding: 12px 16px;
  font-size: 14px;
}

.items-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.section-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.refund-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: var(--bg-surface);
  border-radius: 12px;
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

.hint-text {
  font-size: 12px;
  color: var(--text-muted);
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 40px;
  color: var(--text-secondary);
}
</style>
