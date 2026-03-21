import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useSessionStore = defineStore('session', () => {
  const user = ref(JSON.parse(sessionStorage.getItem('pos_user') || 'null'))
  const token = ref(sessionStorage.getItem('pos_token') || '')

  const isLoggedIn = computed(() => !!token.value && !!user.value)
  const warehouseId = computed(() => user.value?.warehouse_id || 1)

  function login(userData, jwt) {
    user.value = userData
    token.value = jwt
    sessionStorage.setItem('pos_user', JSON.stringify(userData))
    sessionStorage.setItem('pos_token', jwt)
  }

  function logout() {
    user.value = null
    token.value = ''
    sessionStorage.removeItem('pos_user')
    sessionStorage.removeItem('pos_token')
  }

  return { user, token, isLoggedIn, warehouseId, login, logout }
})
