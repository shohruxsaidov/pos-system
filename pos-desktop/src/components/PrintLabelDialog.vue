<template>
  <Dialog v-model:visible="visible" modal header="Печать этикетки" :style="{ width: '480px' }">
    <div class="print-content">
      <!-- Preview -->
      <div class="label-preview" :class="`size-${size}`">
        <div v-if="showStoreName" class="label-store">{{ storeName }}</div>
        <div class="label-name" :style="{ fontSize: fontSize + 'px' }">{{ product?.name }}</div>
        <svg ref="svgRef" class="label-barcode" />
        <div v-if="showLabelPrice" class="label-price font-mono">{{ formatPrice(product?.price) }}</div>
      </div>

      <div class="print-fields">
        <!-- Barcode selector (only if product has multiple barcodes) -->
        <div v-if="productBarcodes.length > 1" class="field-group">
          <label class="field-label">Штрихкод</label>
          <div class="barcode-options">
            <button
              v-for="bc in productBarcodes"
              :key="bc.barcode"
              class="barcode-option"
              :class="{ active: selectedBarcode === bc.barcode }"
              type="button"
              @click="selectedBarcode = bc.barcode"
            >
              <span class="bc-value font-mono">{{ bc.barcode }}</span>
              <span v-if="bc.is_primary" class="bc-primary-tag">основной</span>
            </button>
          </div>
        </div>

        <div class="field-group">
          <label class="field-label">Размер</label>
          <div class="size-toggle">
            <button class="size-btn" :class="{ active: size === '80mm' }" type="button" @click="size = '80mm'">80mm</button>
            <button class="size-btn" :class="{ active: size === '58mm' }" type="button" @click="size = '58mm'">58mm</button>
          </div>
        </div>

        <div class="field-group">
          <label class="field-label">Копии</label>
          <div class="copies-control">
            <Button icon="pi pi-minus" class="p-button-secondary" @click="copies = Math.max(1, copies - 1)"
              style="height:56px;width:56px" />
            <div class="copies-display font-mono">{{ copies }}</div>
            <Button icon="pi pi-plus" class="p-button-secondary" @click="copies = Math.min(50, copies + 1)"
              style="height:56px;width:56px" />
          </div>
        </div>

        <div class="two-col">
          <div class="field-group">
            <label class="field-label">Шрифт (px)</label>
            <div class="copies-control">
              <Button icon="pi pi-minus" class="p-button-secondary" style="height:44px;width:44px"
                @click="fontSize = Math.max(8, fontSize - 1)" />
              <div class="counter-display font-mono">{{ fontSize }}</div>
              <Button icon="pi pi-plus" class="p-button-secondary" style="height:44px;width:44px"
                @click="fontSize = Math.min(40, fontSize + 1)" />
            </div>
          </div>

          <div class="field-group">
            <label class="field-label">Штрихкод (px)</label>
            <div class="copies-control">
              <Button icon="pi pi-minus" class="p-button-secondary" style="height:44px;width:44px"
                @click="barcodeHeight = Math.max(20, barcodeHeight - 4)" />
              <div class="counter-display font-mono">{{ barcodeHeight }}</div>
              <Button icon="pi pi-plus" class="p-button-secondary" style="height:44px;width:44px"
                @click="barcodeHeight = Math.min(120, barcodeHeight + 4)" />
            </div>
          </div>
        </div>

        <div class="toggles-row">
          <div class="toggle-item">
            <ToggleSwitch v-model="showStoreName" inputId="toggle-store" />
            <label for="toggle-store" class="toggle-label">Магазин</label>
          </div>
          <div class="toggle-item">
            <ToggleSwitch v-model="showLabelPrice" inputId="toggle-price" />
            <label for="toggle-price" class="toggle-label">Цена</label>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <Button label="Отмена" class="p-button-secondary touch-lg" @click="visible = false" />
      <Button label="Печать" icon="pi pi-print" class="touch-lg" @click="print" style="flex:1" />
    </template>
  </Dialog>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import { renderBarcode } from '../composables/useBarcode.js'
import { useApi } from '../composables/useApi.js'
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'
import ToggleSwitch from 'primevue/toggleswitch'

const props = defineProps({
  modelValue: Boolean,
  product: Object
})
const emit = defineEmits(['update:modelValue', 'print'])

const api = useApi()

const visible = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v)
})

const svgRef = ref(null)
const size = ref('80mm')
const copies = ref(1)
const storeName = ref('Main Market Store')
const selectedBarcode = ref(null)
const showStoreName = ref(true)
const showLabelPrice = ref(true)
const fontSize = ref(14)
const barcodeHeight = ref(48)
const defaultsLoaded = ref(false)

async function loadDefaults() {
  if (defaultsLoaded.value) return
  try {
    const s = await api.get('/api/settings')
    size.value = s.label_default_size || '80mm'
    copies.value = parseInt(s.label_default_copies) || 1
    showStoreName.value = s.label_show_store !== 'false'
    showLabelPrice.value = s.label_show_price !== 'false'
    fontSize.value = parseInt(s.label_font_size) || 14
    barcodeHeight.value = parseInt(s.label_barcode_height) || 48
    storeName.value = s.store_name || 'Main Market Store'
    defaultsLoaded.value = true
  } catch { }
}

const productBarcodes = computed(() => {
  if (!props.product) return []
  const barcodes = Array.isArray(props.product.barcodes) ? props.product.barcodes : []
  return barcodes.filter(b => b.barcode)
})

watch([() => props.product, visible], async ([prod, vis]) => {
  if (prod && vis) {
    await loadDefaults()
    const barcodes = Array.isArray(prod.barcodes) ? prod.barcodes.filter(b => b.barcode) : []
    const primary = barcodes.find(b => b.is_primary) || barcodes[0]
    selectedBarcode.value = primary?.barcode || prod.barcode || null
    await nextTick()
    if (svgRef.value && selectedBarcode.value) {
      renderBarcode(svgRef.value, selectedBarcode.value, { displayValue: false, height: barcodeHeight.value })
    }
  }
})

watch(selectedBarcode, async (bc) => {
  if (bc && svgRef.value) {
    await nextTick()
    renderBarcode(svgRef.value, bc, { displayValue: false, height: barcodeHeight.value })
  }
})

watch(barcodeHeight, async (h) => {
  if (selectedBarcode.value && svgRef.value) {
    await nextTick()
    renderBarcode(svgRef.value, selectedBarcode.value, { displayValue: false, height: h })
  }
})

function formatPrice(p) {
  return parseFloat(p || 0).toFixed(2)
}

function print() {
  const svgHtml = svgRef.value ? svgRef.value.outerHTML : ''
  const labelWidth = size.value === '58mm' ? '58mm' : '80mm'
  const storeHtml = showStoreName.value ? `<div class="label-store">${storeName.value}</div>` : ''
  const priceHtml = showLabelPrice.value ? `<div class="label-price">${formatPrice(props.product?.price)}</div>` : ''
  const labelHtml = `
    <div class="label">
      ${storeHtml}
      <div class="label-name">${props.product?.name || ''}</div>
      <div class="label-barcode">${svgHtml}</div>
      ${priceHtml}
    </div>`

  const win = window.open('', '_blank', 'width=600,height=380')
  win.document.write(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Label</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Plus Jakarta Sans', Arial, sans-serif; background: #fff; }
    .label {
      width: ${labelWidth};
      padding: 6px 8px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 3px;
      page-break-after: always;
      break-after: page;
    }
    .label:last-child { page-break-after: avoid; break-after: avoid; }
    .label-store { font-size: 9px; color: #555; height: 11px; }
    .label-name  { font-size: ${fontSize.value}px; font-weight: 700; color: #111; text-align: center; }
    .label-barcode svg { width: 100%; height: auto; }
    .label-price { font-size: 30px; font-weight: 700; color: #111; font-family: monospace; }
    @page { margin: 0; size: ${labelWidth} auto; }
  </style>
</head>
<body>
  ${Array(copies.value).fill(labelHtml).join('')}
</body>
</html>`)
  win.document.close()
  win.focus()
  win.onload = () => { win.print(); win.close() }
  // fallback if onload already fired
  setTimeout(() => { try { win.print(); win.close() } catch { } }, 500)

  emit('print', { product: props.product, barcode: selectedBarcode.value, copies: copies.value, size: size.value })
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

.size-58mm {
  width: 220px;
}

.size-80mm {
  width: 300px;
}

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

.label-barcode {
  width: 100%;
}

.label-price {
  font-size: 26px;
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

.barcode-options {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.barcode-option {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  border-radius: 10px;
  border: 1px solid var(--border-default);
  background: var(--bg-input);
  cursor: pointer;
  transition: all 0.12s;
}

.barcode-option.active {
  border-color: var(--accent-1);
  background: var(--accent-glow);
}

.bc-value {
  font-size: 13px;
  color: var(--text-primary);
}

.bc-primary-tag {
  font-size: 11px;
  font-weight: 600;
  color: var(--warning);
  background: var(--warning-bg);
  padding: 2px 8px;
  border-radius: 6px;
}

.size-toggle {
  display: flex;
  gap: 8px;
}

.size-btn {
  padding: 0 20px;
  height: 48px;
  border-radius: 10px;
  border: 1px solid var(--border-default);
  background: var(--bg-input);
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.12s;
}

.size-btn.active {
  border-color: var(--accent-1);
  background: var(--accent-glow);
  color: var(--text-accent);
}

.toggles-row {
  display: flex;
  gap: 24px;
  align-items: center;
}

.toggle-item {
  display: flex;
  align-items: center;
  gap: 10px;
}

.toggle-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  cursor: pointer;
}

.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.counter-display {
  flex: 1;
  text-align: center;
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary);
}
</style>
