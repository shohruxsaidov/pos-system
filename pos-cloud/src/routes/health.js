import { pool } from '../db/connection.js'

export default async function healthRoutes(fastify) {
  fastify.get('/health', async () => {
    let db = 'ok'
    try {
      await pool.query('SELECT 1')
    } catch {
      db = 'error'
    }
    return { status: 'ok', db, uptime: Math.floor(process.uptime()) }
  })
}
