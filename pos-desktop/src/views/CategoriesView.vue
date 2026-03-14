<template>
  <div class="categories-view">
    <!-- Header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Категории</h1>
        <p class="view-subtitle">{{ categories.length }} категорий</p>
      </div>
      <Button label="Добавить категорию" icon="pi pi-plus" @click="openCreate" />
    </div>

    <!-- DataTable -->
    <DataTable
      :value="categories"
      :loading="loading"
      scrollable
      scroll-height="flex"
      class="categories-table"
      row-hover
    >
      <Column header="Цвет" style="width:64px">
        <template #body="{ data }">
          <div class="color-dot" :style="{ background: data.color || '#7b68ee' }" />
        </template>
      </Column>
      <Column header="Иконка" style="width:64px">
        <template #body="{ data }">
          <i :class="data.icon || 'pi pi-tag'" style="font-size:18px;color:var(--text-secondary)" />
        </template>
      </Column>
      <Column field="name" header="Название" sortable />
      <Column header="Родитель" style="width:180px">
        <template #body="{ data }">
          <span v-if="data.parent_id" class="parent-badge">
            {{ parentName(data.parent_id) }}
          </span>
          <span v-else class="text-muted" style="font-size:13px">—</span>
        </template>
      </Column>
      <Column header="Товаров" style="width:100px">
        <template #body="{ data }">
          <span class="font-mono" style="color:var(--text-secondary)">{{ data.product_count ?? '—' }}</span>
        </template>
      </Column>
      <Column header="Действия" style="width:100px">
        <template #body="{ data }">
          <div style="display:flex;gap:4px">
            <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px" @click="openEdit(data)" v-tooltip="'Редактировать'" />
            <Button icon="pi pi-trash" class="p-button-danger" style="height:36px;width:36px" @click="deleteCategory(data)" v-tooltip="'Удалить'" />
          </div>
        </template>
      </Column>
    </DataTable>

    <!-- Create/Edit Drawer -->
    <Drawer
      v-model:visible="showDrawer"
      :header="editingCategory ? 'Редактировать категорию' : 'Новая категория'"
      position="right"
      style="width:420px"
    >
      <div class="drawer-form">
        <div class="field-group">
          <label class="field-label">Название *</label>
          <InputText v-model="form.name" class="w-full" placeholder="Название категории" />
        </div>

        <div class="field-group">
          <label class="field-label">Родительская категория</label>
          <Select
            v-model="form.parent_id"
            :options="parentOptions"
            option-label="name"
            option-value="id"
            placeholder="Нет (корневая)"
            class="w-full"
            show-clear
          />
        </div>

        <div class="field-group">
          <label class="field-label">Цвет</label>
          <div class="color-row">
            <input type="color" v-model="form.color" class="color-picker" />
            <InputText v-model="form.color" class="w-full" placeholder="#7b68ee" />
          </div>
          <div class="color-presets">
            <button
              v-for="c in COLOR_PRESETS"
              :key="c"
              type="button"
              class="color-preset"
              :class="{ active: form.color === c }"
              :style="{ background: c }"
              @click="form.color = c"
            />
          </div>
        </div>

        <div class="field-group">
          <label class="field-label">Иконка</label>
          <InputText v-model="form.icon" class="w-full" placeholder="pi pi-tag" style="margin-bottom:8px" />
          <div class="icon-chips">
            <button
              v-for="ic in CATEGORY_ICONS"
              :key="ic"
              type="button"
              class="icon-chip"
              :class="{ active: form.icon === ic }"
              @click="form.icon = ic"
              v-tooltip="ic"
            >
              <i :class="ic" />
            </button>
          </div>
        </div>

        <!-- Preview -->
        <div class="preview-card">
          <div class="preview-icon" :style="{ background: form.color + '22', borderColor: form.color + '55' }">
            <i :class="form.icon || 'pi pi-tag'" :style="{ color: form.color || '#7b68ee' }" />
          </div>
          <span class="preview-name">{{ form.name || 'Название категории' }}</span>
        </div>
      </div>

      <template #footer>
        <div class="drawer-footer">
          <Button label="Отмена" class="p-button-secondary" @click="showDrawer = false" />
          <Button
            :label="editingCategory ? 'Сохранить изменения' : 'Создать категорию'"
            :loading="saving"
            :disabled="!form.name.trim()"
            @click="saveCategory"
            style="flex:1"
          />
        </div>
      </template>
    </Drawer>

    <Toast />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Drawer from 'primevue/drawer'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const categories = ref([])
const loading = ref(false)
const saving = ref(false)
const showDrawer = ref(false)
const editingCategory = ref(null)

const CATEGORY_ICONS = [
  'pi pi-tag', 'pi pi-box', 'pi pi-shopping-cart', 'pi pi-apple',
  'pi pi-star', 'pi pi-home', 'pi pi-car', 'pi pi-bolt',
  'pi pi-heart', 'pi pi-gift', 'pi pi-wrench', 'pi pi-palette',
  'pi pi-globe', 'pi pi-phone', 'pi pi-desktop', 'pi pi-truck',
  'pi pi-briefcase', 'pi pi-leaf', 'pi pi-sun', 'pi pi-building',
]

const COLOR_PRESETS = [
  '#7b68ee', '#9d4edd', '#00d4aa', '#ffb02e',
  '#ff5c5c', '#4e90e8', '#f97316', '#22c55e',
]

const defaultForm = () => ({ name: '', color: '#7b68ee', icon: 'pi pi-tag', parent_id: null })
const form = ref(defaultForm())

// Exclude self when editing to avoid circular parent
const parentOptions = computed(() =>
  categories.value.filter(c => !editingCategory.value || c.id !== editingCategory.value.id)
)

function parentName(id) {
  return categories.value.find(c => c.id === id)?.name ?? '—'
}

onMounted(loadCategories)

async function loadCategories() {
  loading.value = true
  try {
    categories.value = await api.get('/api/categories')
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingCategory.value = null
  form.value = defaultForm()
  showDrawer.value = true
}

function openEdit(cat) {
  editingCategory.value = cat
  form.value = { name: cat.name, color: cat.color || '#7b68ee', icon: cat.icon || 'pi pi-tag', parent_id: cat.parent_id ?? null }
  showDrawer.value = true
}

async function saveCategory() {
  saving.value = true
  try {
    if (editingCategory.value) {
      await api.put(`/api/categories/${editingCategory.value.id}`, form.value)
      toast.add({ severity: 'success', summary: 'Обновлено', detail: form.value.name, life: 2000 })
    } else {
      await api.post('/api/categories', form.value)
      toast.add({ severity: 'success', summary: 'Категория создана', detail: form.value.name, life: 2000 })
    }
    showDrawer.value = false
    await loadCategories()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function deleteCategory(cat) {
  if (!confirm(`Удалить категорию "${cat.name}"?`)) return
  try {
    await api.delete(`/api/categories/${cat.id}`)
    toast.add({ severity: 'success', summary: 'Категория удалена', life: 2000 })
    await loadCategories()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Ошибка', detail: e.message, life: 3000 })
  }
}
</script>

<style scoped>
.categories-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: hidden;
}

.view-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.view-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
}

.view-subtitle {
  font-size: 13px;
  color: var(--text-muted);
  margin-top: 2px;
}

.categories-table { flex: 1; }

.color-dot {
  width: 22px;
  height: 22px;
  border-radius: 50%;
}

.parent-badge {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-accent);
  background: var(--accent-glow);
  padding: 3px 10px;
  border-radius: 20px;
}

.drawer-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 4px 0;
}

.field-group { display: flex; flex-direction: column; gap: 8px; }

.field-label {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.color-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.color-picker {
  width: 44px;
  height: 44px;
  border: 1px solid var(--border-default);
  border-radius: 10px;
  background: var(--bg-input);
  cursor: pointer;
  padding: 3px;
  flex-shrink: 0;
}

.color-presets {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.color-preset {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 2px solid transparent;
  cursor: pointer;
  transition: border-color 0.15s, transform 0.15s;
}

.color-preset:hover { transform: scale(1.15); }

.color-preset.active {
  border-color: #fff;
  transform: scale(1.15);
}

.icon-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.icon-chip {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-input);
  border: 1px solid var(--border-default);
  border-radius: 8px;
  color: var(--text-secondary);
  font-size: 15px;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s, color 0.15s;
}

.icon-chip:hover {
  border-color: rgba(123, 104, 238, 0.4);
  color: var(--text-primary);
}

.icon-chip.active {
  border-color: var(--accent-1);
  background: rgba(123, 104, 238, 0.15);
  color: var(--text-accent);
}

.preview-card {
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  padding: 14px 16px;
}

.preview-icon {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  border: 1px solid;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}

.preview-name {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

.drawer-footer {
  display: flex;
  gap: 10px;
  padding: 16px;
}

.w-full { width: 100%; }
</style>
