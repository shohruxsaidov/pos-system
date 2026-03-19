import { ref, onMounted, onUnmounted } from 'vue'

const BASE_URL = import.meta.env.VITE_API_URL || ''

export function useConnectivity() {
  const isOnline = ref(navigator.onLine)
  let pollInterval = null

  async function probe() {
    try {
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 3000)
      await fetch(`${BASE_URL}/health`, { signal: controller.signal })
      clearTimeout(timeout)
      isOnline.value = true
    } catch {
      isOnline.value = false
    }
    return isOnline.value
  }

  function startPolling() {
    if (pollInterval) return
    pollInterval = setInterval(async () => {
      const online = await probe()
      if (online) stopPolling()
    }, 15000)
  }

  function stopPolling() {
    if (pollInterval) {
      clearInterval(pollInterval)
      pollInterval = null
    }
  }

  function onOffline() {
    isOnline.value = false
    startPolling()
  }

  async function onOnline() {
    const confirmed = await probe()
    if (confirmed) stopPolling()
  }

  onMounted(() => {
    probe()
    window.addEventListener('offline', onOffline)
    window.addEventListener('online', onOnline)
  })

  onUnmounted(() => {
    stopPolling()
    window.removeEventListener('offline', onOffline)
    window.removeEventListener('online', onOnline)
  })

  return { isOnline, probe }
}
