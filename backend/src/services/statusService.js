import { pool } from '../db/connection.js'
import { getMobileUrl } from './networkService.js'

export const desktopClients = new Set()
let fastifyInstance = null

export function setFastify(f) {
  fastifyInstance = f
}

export async function getStatusPayload() {
  let dbOk = false
  let syncQueue = 0

  try {
    await pool.query('SELECT 1')
    dbOk = true

    const { rows } = await pool.query(
      'SELECT COUNT(*) as count FROM sync_log WHERE synced_at IS NULL'
    )
    syncQueue = parseInt(rows[0].count)
  } catch (e) {
    // db unreachable
  }

  return {
    server: 'ok',
    db: dbOk ? 'ok' : 'error',
    sync_queue: syncQueue,
    last_sync: new Date().toISOString(),
    cloud_reachable: false,
    uptime: Math.floor(process.uptime()),
    mobile_url: getMobileUrl(),
    timestamp: new Date().toISOString()
  }
}

export async function broadcastStatus() {
  if (!fastifyInstance?.websocketServer) return

  const payload = await getStatusPayload()
  const message = JSON.stringify({ type: 'status', ...payload })

  fastifyInstance.websocketServer.clients.forEach(client => {
    if (client.readyState === 1) {
      client.send(message)
    }
  })
}

export function broadcastToDesktop(message) {
  if (desktopClients.size === 0) return false

  const payload = JSON.stringify(message)
  desktopClients.forEach(client => {
    if (client.readyState === 1) {
      client.send(payload)
    }
  })
  return true
}
