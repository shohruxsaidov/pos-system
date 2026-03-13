import { pool } from '../db/connection.js'
import { sendTelegram } from '../services/notificationService.js'

export default async function notificationRoutes(fastify) {
  // POST /api/notifications/test-telegram
  fastify.post('/api/notifications/test-telegram', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    if (!['manager', 'admin'].includes(req.user.role)) {
      return reply.code(403).send({ error: 'Manager access required' })
    }

    const { rows } = await pool.query(
      "SELECT key, value FROM settings WHERE key IN ('telegram_bot_token','telegram_chat_id','store_name')"
    )
    const s = Object.fromEntries(rows.map(r => [r.key, r.value]))

    if (!s.telegram_bot_token || !s.telegram_chat_id) {
      return reply.code(400).send({ error: 'Telegram bot token and chat ID not configured' })
    }

    const ok = await sendTelegram(
      s.telegram_bot_token,
      s.telegram_chat_id,
      `✅ <b>Test Message</b>\n\nTelegram notifications are working!\nStore: ${s.store_name || 'POS'}`
    )

    if (!ok) return reply.code(500).send({ error: 'Failed to send Telegram message' })
    return { success: true }
  })

  // GET /api/notifications/status
  fastify.get('/api/notifications/status', { onRequest: [fastify.authenticate] }, async () => {
    const { rows } = await pool.query(
      "SELECT key, value FROM settings WHERE key IN ('telegram_enabled','telegram_bot_token','telegram_chat_id')"
    )
    const s = Object.fromEntries(rows.map(r => [r.key, r.value]))
    return {
      enabled: s.telegram_enabled === 'true',
      configured: !!(s.telegram_bot_token && s.telegram_chat_id)
    }
  })
}
