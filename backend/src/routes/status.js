import { desktopClients, getStatusPayload } from '../services/statusService.js'

export default async function statusRoutes(fastify) {
  // WebSocket /ws/status
  fastify.get('/ws/status', { websocket: true }, async (socket, req) => {
    console.log('[ws] Client connected:', req.ip)

    // Send initial status
    try {
      const payload = await getStatusPayload()
      socket.send(JSON.stringify({ type: 'status', ...payload }))
    } catch (e) {
      console.error('[ws] Failed to send initial status:', e.message)
    }

    socket.on('message', async (raw) => {
      try {
        const msg = JSON.parse(raw.toString())

        // Desktop identification
        if (msg.client === 'desktop' || msg.type === 'identify') {
          desktopClients.add(socket)
          console.log('[ws] Desktop client identified')
          socket.send(JSON.stringify({ type: 'identified', client: 'desktop' }))
        }

        // Ping / pong
        if (msg.type === 'ping') {
          socket.send(JSON.stringify({ type: 'pong', ts: Date.now() }))
        }
      } catch (e) {
        // non-JSON message, ignore
      }
    })

    socket.on('close', () => {
      desktopClients.delete(socket)
      console.log('[ws] Client disconnected')
    })

    socket.on('error', (err) => {
      console.error('[ws] Socket error:', err.message)
      desktopClients.delete(socket)
    })
  })
}
