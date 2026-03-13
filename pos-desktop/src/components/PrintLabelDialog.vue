<template>
  <Dialog
    v-model:visible="visible"
    modal
    header="Print Label"
    :style="{ width: '480px' }"
  >
    <div class="print-content">
      <!-- Preview -->
      <div class="label-preview" :class="`size-${size}`">
        <div class="label-store">{{ storeName }}</div>
        <div class="label-name">{{ product?.name }}</div>
        <svg ref="svgRef" class="label-barcode" />
        <div class="label-price font-mono">₱{{ formatPrice(product?.price) }}</div>
      </div>

      <div class="print-fields">
        <div class="field-group">
          <label class="field-label">Label Size</label>
          <SelectButton
            v-model="size"
            :options="['58mm', '80mm']"
          />
        </div>

        <div class="field-group">
          <label class="field-label">Copies</label>
          <div class="copies-control">
            <Button
              icon="pi pi-minus"
              class="p-button-secondary"
              @click="copies = Math.max(1, copies - 1)"
              style="height:56px;width:56px"
            />
            <div class="copies-display font-mono">{{ copies }}</div>
            <Button
              icon="pi pi-plus"
              class="p-button-secondary"
              @click="copies = Math.min(50, copies + 1)"
              style="height:56px;width:56px"
            />
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <Button label="Cancel" class="p-button-secondary" @click="visible = false" />
      <Button label="Print" icon="pi pi-print" class="touch-lg" @click="print" style="flex:1" />
    </template>
  </Dialog>
</template>

<script setup>
import { ref, watch, nextTick, onMounted } from 'vue'
import { renderBarcode } from '../composables/useBarcode.js'
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'
import SelectButton from 'primevue/selectbutton'

const props = defineProps({
  modelValue: Boolean,
  product: Object
})
const emit = defineEmits(['update:modelValue', 'print'])

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

import { computed } from 'vue'

const svgRef = ref(null)
const size = ref('58mm')
const copies = ref(1)
const storeName = ref('Main Market Store')

watch([() => props.product, visible], async ([prod, vis]) => {
  if (prod && vis) {
    await nextTick()
    if (svgRef.value && prod.barcode) {
      renderBarcode(svgRef.value, prod.barcode)
    }
  }
})

function formatPrice(p) {
  return parseFloat(p || 0).toFixed(2)
}

function print() {
  emit('print', { product: props.product, copies: copies.value, size: size.value })
  visible.value = false
}
</script>

<style scoped>
.print-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.label-preview {
  background: #fff;
  color: #111;
  border-radius: 10px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  margin: 0 auto;
}

.size-58mm { width: 220px; }
.size-80mm { width: 300px; }

.label-store {
  font-size: 11px;
  color: #555;
  font-family: var(--font-sans);
}

.label-name {
  font-size: 14px;
  font-weight: 700;
  color: #111;
  text-align: center;
}

.label-barcode { width: 100%; }

.label-price {
  font-size: 18px;
  font-weight: 700;
  color: #111;
}

.print-fields {
  display: flex;
  flex-direction: column;
  gap: 16px;
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

.copies-control {
  display: flex;
  align-items: center;
  gap: 12px;
}

.copies-display {
  flex: 1;
  text-align: center;
  font-size: 28px;
  font-weight: 700;
  color: var(--text-primary);
}
</style>
