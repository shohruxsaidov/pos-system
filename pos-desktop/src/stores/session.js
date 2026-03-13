import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useSessionStore = defineStore('session', () => {
  const user = ref(JSON.parse(localStorage.getItem('pos_user') || 'null'))
  const token = ref(localStorage.getItem('pos_token') || '')

  const isLoggedIn = computed(() => !!token.value && !!user.value)
  const warehouseId = computed(() => user.value?.warehouse_id || 1)

  function login(userData, jwt) {
    user.value = userData
    token.value = jwt
    localStorage.setItem('pos_user', JSON.stringify(userData))
    localStorage.setItem('pos_token', jwt)
  }

  function logout() {
    user.value = null
    token.value = ''
    localStorage.removeItem('pos_user')
    localStorage.removeItem('pos_token')
  }

  return { user, token, isLoggedIn, warehouseId, login, logout }
})
