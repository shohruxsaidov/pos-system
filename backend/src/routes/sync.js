import { pool } from '../db/connection.js'
import { pushToCloud } from '../services/syncService.js'

export default async function syncRoutes(fastify) {
  // POST /api/sync/push — push local transactions to cloud
  fastify.post('/api/sync/push', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    try {
      const result = await pushToCloud()
      return result
    } catch (err) {
      reply.code(502).send({ error: err.message })
    }
  })

  // GET /api/sync/pull — not implemented (push-only architecture)
  fastify.get('/api/sync/pull', { onRequest: [fastify.authenticate] }, async () => {
    return { pulled: 0, message: 'Push-only sync — no pull needed' }
  })

  // GET /api/sync/status
  fastify.get('/api/sync/status', { onRequest: [fastify.authenticate] }, async () => {
    const { rows } = await pool.query(`
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN synced_at IS NOT NULL THEN 1 ELSE 0 END) as synced,
        SUM(CASE WHEN synced_at IS NULL THEN 1 ELSE 0 END) as pending,
        MAX(synced_at) as last_sync
      FROM sync_log
    `)
    return rows[0]
  })
}
