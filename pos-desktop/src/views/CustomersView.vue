<template>
  <div class="customers-view">
    <div class="view-header">
      <div>
        <h1 class="view-title">Customers</h1>
        <p class="view-subtitle">{{ total }} customers</p>
      </div>
      <div class="header-actions">
        <InputText v-model="search" placeholder="Search name or phone..." class="search-input" @input="debouncedSearch" />
        <Button label="Add Customer" icon="pi pi-plus" @click="openCreate" />
      </div>
    </div>

    <DataTable
      :value="customers"
      :loading="loading"
      scrollable
      scroll-height="flex"
      row-hover
      :expand-row="expandedRows"
      dataKey="id"
    >
      <Column expander style="width:50px" />
      <Column field="name" header="Name" sortable />
      <Column field="phone" header="Phone" style="width:150px">
        <template #body="{ data }">
          <span class="font-mono">{{ data.phone || '—' }}</span>
        </template>
      </Column>
      <Column field="email" header="Email" style="width:200px">
        <template #body="{ data }">
          {{ data.email || '—' }}
        </template>
      </Column>
      <Column field="loyalty_points" header="Loyalty" style="width:200px">
        <template #body="{ data }">
          <div class="loyalty-cell">
            <ProgressBar :value="Math.min(100, (data.loyalty_points / 1000) * 100)" style="height:6px;flex:1" />
            <span class="font-mono" style="font-size:12px;color:var(--text-accent)">{{ data.loyalty_points }} pts</span>
          </div>
        </template>
      </Column>
      <Column field="created_at" header="Since" style="width:110px">
        <template #body="{ data }">
          <span style="font-size:12px;color:var(--text-muted)">{{ formatDate(data.created_at) }}</span>
        </template>
      </Column>
      <Column header="" style="width:90px">
        <template #body="{ data }">
          <div style="display:flex;gap:4px">
            <Button icon="pi pi-pencil" class="p-button-secondary" style="height:36px;width:36px" @click="openEdit(data)" />
            <Button icon="pi pi-trash" class="p-button-danger" style="height:36px;width:36px" @click="deleteCustomer(data)" />
          </div>
        </template>
      </Column>
      <template #expansion="{ data }">
        <div class="expansion-panel">
          <h4 class="text-secondary" style="margin-bottom:10px">Purchase History</h4>
          <DataTable :value="data.purchase_history || []" :loading="!data.purchase_history">
            <Column field="ref_no" header="Ref No">
              <template #body="{ data }">
                <span class="font-mono" style="font-size:12px">{{ data.ref_no }}</span>
              </template>
            </Column>
            <Column field="total" header="Total">
              <template #body="{ data }">
                <span class="font-mono">₱{{ formatAmount(data.total) }}</span>
              </template>
            </Column>
            <Column field="payment_method" header="Method" />
            <Column field="created_at" header="Date">
              <template #body="{ data }">
                <span style="font-size:12px">{{ formatDate(data.created_at) }}</span>
              </template>
            </Column>
          </DataTable>
        </div>
      </template>
    </DataTable>

    <!-- Drawer -->
    <Drawer v-model:visible="showDrawer" :header="editingCustomer ? 'Edit Customer' : 'New Customer'" position="right" style="width:420px">
      <div class="drawer-form">
        <div class="field-group">
          <label class="field-label">Full Name *</label>
          <InputText v-model="form.name" class="w-full" placeholder="Customer name" />
        </div>
        <div class="field-group">
          <label class="field-label">Phone</label>
          <InputText v-model="form.phone" class="w-full" placeholder="+63..." />
        </div>
        <div class="field-group">
          <label class="field-label">Email</label>
          <InputText v-model="form.email" class="w-full" placeholder="email@example.com" />
        </div>
        <div class="field-group" v-if="editingCustomer">
          <label class="field-label">Loyalty Points</label>
          <InputText v-model="form.loyalty_points" type="number" class="w-full" />
        </div>
      </div>
      <template #footer>
        <div style="display:flex;gap:10px;padding:16px">
          <Button label="Cancel" class="p-button-secondary" @click="showDrawer = false" />
          <Button :label="editingCustomer ? 'Save Changes' : 'Add Customer'" :loading="saving" @click="saveCustomer" style="flex:1" />
        </div>
      </template>
    </Drawer>

    <Toast />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../composables/useApi.js'
import { useToast } from 'primevue/usetoast'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Drawer from 'primevue/drawer'
import ProgressBar from 'primevue/progressbar'
import Toast from 'primevue/toast'

const api = useApi()
const toast = useToast()

const customers = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const total = ref(0)
const showDrawer = ref(false)
const editingCustomer = ref(null)
const expandedRows = ref({})
let searchTimeout = null

const defaultForm = () => ({ name: '', phone: '', email: '', loyalty_points: 0 })
const form = ref(defaultForm())

onMounted(loadCustomers)

async function loadCustomers() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (search.value) params.set('search', search.value)
    const data = await api.get(`/api/customers?${params}`)
    customers.value = data
    total.value = data.length
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

function debouncedSearch() {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(loadCustomers, 300)
}

async function loadPurchaseHistory(customer) {
  if (customer.purchase_history) return
  try {
    const data = await api.get(`/api/customers/${customer.id}`)
    customer.purchase_history = data.purchase_history
  } catch (e) {}
}

function openCreate() {
  editingCustomer.value = null
  form.value = defaultForm()
  showDrawer.value = true
}

function openEdit(customer) {
  editingCustomer.value = customer
  form.value = { ...customer }
  showDrawer.value = true
}

async function saveCustomer() {
  saving.value = true
  try {
    if (editingCustomer.value) {
      await api.put(`/api/customers/${editingCustomer.value.id}`, form.value)
      toast.add({ severity: 'success', summary: 'Updated', life: 2000 })
    } else {
      await api.post('/api/customers', form.value)
      toast.add({ severity: 'success', summary: 'Customer Added', life: 2000 })
    }
    showDrawer.value = false
    await loadCustomers()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    saving.value = false
  }
}

async function deleteCustomer(customer) {
  if (!confirm(`Delete ${customer.name}?`)) return
  try {
    await api.delete(`/api/customers/${customer.id}`)
    toast.add({ severity: 'success', summary: 'Deleted', life: 2000 })
    await loadCustomers()
  } catch (e) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  }
}

function formatAmount(n) { return parseFloat(n || 0).toFixed(2) }
function formatDate(d) { return d ? new Date(d).toLocaleDateString() : '—' }
</script>

<style scoped>
.customers-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px;
  gap: 16px;
  overflow: hidden;
}

.view-header { display: flex; justify-content: space-between; align-items: center; }
.view-title { font-size: 24px; font-weight: 800; color: var(--text-primary); }
.view-subtitle { font-size: 13px; color: var(--text-muted); }
.header-actions { display: flex; gap: 10px; }
.search-input { width: 260px; }

.loyalty-cell { display: flex; align-items: center; gap: 8px; }

.expansion-panel {
  padding: 16px 20px;
  background: var(--bg-input);
  border-top: 1px solid var(--border-subtle);
}

.drawer-form { display: flex; flex-direction: column; gap: 16px; }
.field-group { display: flex; flex-direction: column; gap: 6px; }
.field-label { font-size: 12px; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.05em; }
.w-full { width: 100%; }
</style>
