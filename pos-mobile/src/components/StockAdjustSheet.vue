<template>
  <Transition name="slide-up">
    <div v-if="visible" class="sheet-overlay" @click.self="$emit('close')">
      <div class="adjust-sheet">
        <div class="sheet-handle" />
        <div class="sheet-header">
          <h3>Корректировка остатка</h3>
          <div class="product-label">{{ product?.name }}</div>
          <div class="current-stock">
            Текущий: <span class="font-mono">{{ product?.stock_qty }}</span>
          </div>
        </div>

        <!-- Add / Remove toggle -->
        <div class="toggle-row">
          <button :class="['toggle-btn', { active: mode === 'add' }]" @click="mode = 'add'">
            <i class="pi pi-plus" /> Добавить
          </button>
          <button :class="['toggle-btn', { active: mode === 'remove' }]" @click="mode = 'remove'">
            <i class="pi pi-minus" /> Убрать
          </button>
        </div>

        <!-- Qty Display -->
        <div class="qty-display" @click="showNumpad = true">
          <span class="qty-label">{{ mode === 'add' ? '+' : '−' }}</span>
          <span class="qty-value font-mono">{{ qty || 0 }}</span>
          <i class="pi pi-pencil" style="color:var(--text-muted);font-size:14px" />
        </div>

        <!-- Reason -->
        <div class="field-group">
          <label class="field-label">Причина</label>
          <select class="reason-select" v-model="reason">
            <option value="" disabled>Выберите причину...</option>
            <option v-for="r in reasons" :key="r" :value="r">{{ r }}</option>
          </select>
        </div>

        <button class="confirm-btn" :disabled="!qty || !reason" @click="confirm">
          Применить
        </button>

        <BottomNumPad
          :visible="showNumpad"
          v-model="qty"
          label="Количество"
          :integer="false"
          @close="showNumpad = false"
          @confirm="showNumpad = false"
        />
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { ref } from 'vue'
import BottomNumPad from './BottomNumPad.vue'

const props = defineProps({ visible: Boolean, product: Object })
const emit = defineEmits(['close', 'confirm'])

const mode = ref('add')
const qty = ref('')
const reason = ref('')
const showNumpad = ref(false)

const reasons = ['Корректировка приёмки', 'Повреждение', 'Корректировка инвентаризации', 'Возврат поставщику', 'Другое']

function confirm() {
  if (!qty.value || !reason.value) return
  const delta = mode.value === 'add' ? parseInt(qty.value) : -parseInt(qty.value)
  emit('confirm', { delta, reason: reason.value })
  qty.value = ''
  reason.value = ''
}
</script>

<style scoped>
.sheet-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
}

.adjust-sheet {
  width: 100%;
  background: var(--bg-elevated);
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  padding: 0 20px calc(20px + env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.sheet-handle {
  width: 40px; height: 4px;
  background: var(--border-default);
  border-radius: 2px;
  margin: 12px auto 4px;
}

.sheet-header { text-align: center; }
.sheet-header h3 { font-size: 18px; font-weight: 700; color: var(--text-primary); }
.product-label { font-size: 14px; color: var(--text-secondary); margin-top: 4px; }
.current-stock { font-size: 14px; color: var(--text-muted); }
.current-stock .font-mono { color: var(--text-accent); }

.toggle-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }

.toggle-btn {
  height: 52px;
  border-radius: 12px;
  border: 1px solid var(--border-default);
  background: var(--bg-surface);
  color: var(--text-secondary);
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: all 0.15s;
}

.toggle-btn.active {
  background: var(--gradient-hero);
  border-color: transparent;
  color: #fff;
}

.qty-display {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 20px;
  background: var(--bg-surface);
  border-radius: 16px;
  cursor: pointer;
}

.qty-label { font-size: 28px; color: var(--text-accent); }
.qty-value { font-size: 40px; font-weight: 700; color: var(--text-primary); }

.field-group { display: flex; flex-direction: column; gap: 6px; }
.field-label { font-size: 12px; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }

.reason-select {
  height: 56px;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 12px;
  color: var(--text-primary);
  font-size: 16px;
  padding: 0 16px;
  width: 100%;
  -webkit-appearance: none;
}

.confirm-btn {
  height: 64px;
  background: var(--gradient-hero);
  border: none;
  border-radius: 16px;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 4px 20px rgba(123,104,238,0.35);
}

.confirm-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.slide-up-enter-from, .slide-up-leave-to { transform: translateY(100%); }
.slide-up-enter-active, .slide-up-leave-active { transition: transform 0.3s cubic-bezier(0.4,0,0.2,1); }
</style>
