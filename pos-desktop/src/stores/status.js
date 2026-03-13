import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:3000/ws/status'

export const useStatusStore = defineStore('status', () => {
  const server = ref('connecting')
  const db = ref('unknown')
  const sync = ref('unknown')
  const syncQueue = ref(0)
  const lastSync = ref(null)
  const uptime = ref(0)
  const mobileUrl = ref('')
  const missedPings = ref(0)
  const isOffline = computed(() => server.value !== 'ok' || db.value !== 'ok')

  let ws = null
  let pingTimer = null
  let reconnectTimer = null
  let reconnectDelay = 3000

  function connect() {
    if (ws && ws.readyState <= 1) return

    try {
      ws = new WebSocket(WS_URL)

      ws.onopen = () => {
        console.log('[ws] Connected to status server')
        server.value = 'ok'
        missedPings.value = 0
        reconnectDelay = 3000

        // Identify as desktop
        ws.send(JSON.stringify({ type: 'identify', client: 'desktop' }))

        // Heartbeat check
        pingTimer = setInterval(() => {
          if (ws.readyState === 1) {
            ws.send(JSON.stringify({ type: 'ping' }))
          }
        }, 5000)

        // Missed ping counter
        setInterval(() => {
          missedPings.value++
          if (missedPings.value >= 2) {
            server.value = 'offline'
          }
        }, 6000)
      }

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data)
          missedPings.value = 0

          if (msg.type === 'status') {
            server.value = msg.server || 'ok'
            db.value = msg.db || 'unknown'
            syncQueue.value = msg.sync_queue || 0
            lastSync.value = msg.last_sync
            uptime.value = msg.uptime || 0
            mobileUrl.value = msg.mobile_url || ''
          }

          if (msg.type === 'pong') {
            missedPings.value = 0
            server.value = 'ok'
          }

          // Handle print label from mobile
          if (msg.type === 'print_label') {
            window.dispatchEvent(new CustomEvent('pos:print_label', { detail: msg.payload }))
          }
        } catch (e) {
          console.error('[ws] Parse error:', e)
        }
      }

      ws.onclose = () => {
        server.value = 'offline'
        clearInterval(pingTimer)
        scheduleReconnect()
      }

      ws.onerror = () => {
        server.value = 'offline'
      }
    } catch (e) {
      server.value = 'offline'
      scheduleReconnect()
    }
  }

  function scheduleReconnect() {
    clearTimeout(reconnectTimer)
    reconnectTimer = setTimeout(() => {
      reconnectDelay = Math.min(reconnectDelay * 1.5, 10000)
      connect()
    }, reconnectDelay)
  }

  function disconnect() {
    clearInterval(pingTimer)
    clearTimeout(reconnectTimer)
    if (ws) ws.close()
  }

  return {
    server, db, sync, syncQueue, lastSync, uptime, mobileUrl, missedPings, isOffline,
    connect, disconnect
  }
})
