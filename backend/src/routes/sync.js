import { pool } from '../db/connection.js'

export default async function syncRoutes(fastify) {
  // POST /api/sync/push — push local changes to cloud
  fastify.post('/api/sync/push', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { rows } = await pool.query(
      'SELECT * FROM sync_log WHERE synced_at IS NULL ORDER BY created_at LIMIT 100'
    )

    if (!rows.length) return { pushed: 0, message: 'Nothing to sync' }

    // In production, this would push to cloud DB
    // For now, mark as synced
    const ids = rows.map(r => r.id)
    await pool.query(
      'UPDATE sync_log SET synced_at=NOW() WHERE id=ANY($1)',
      [ids]
    )

    return { pushed: rows.length, message: 'Sync successful' }
  })

  // GET /api/sync/pull — pull changes from cloud
  fastify.get('/api/sync/pull', { onRequest: [fastify.authenticate] }, async () => {
    // In production, this would pull from cloud DB
    return { pulled: 0, message: 'Cloud sync not configured' }
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
