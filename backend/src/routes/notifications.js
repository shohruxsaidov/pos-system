import { pool } from '../db/connection.js'
import { sendTelegram, generateAISummary } from '../services/notificationService.js'

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

  // POST /api/notifications/test-ai-summary
  fastify.post('/api/notifications/test-ai-summary', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    if (!['manager', 'admin'].includes(req.user.role)) {
      return reply.code(403).send({ error: 'Manager access required' })
    }

    const { rows } = await pool.query(
      "SELECT key, value FROM settings WHERE key IN ('telegram_bot_token','telegram_chat_id','store_name','gemini_api_key','ai_summary_enabled')"
    )
    const s = Object.fromEntries(rows.map(r => [r.key, r.value]))

    if (!s.gemini_api_key) {
      return reply.code(400).send({ error: 'Gemini API key not configured' })
    }
    if (s.ai_summary_enabled !== 'true') {
      return reply.code(400).send({ error: 'AI summary is disabled' })
    }
    if (!s.telegram_bot_token || !s.telegram_chat_id) {
      return reply.code(400).send({ error: 'Telegram not configured' })
    }

    const testData = {
      date: new Date().toISOString().split('T')[0],
      storeName: s.store_name || 'Store',
      txnCount: 42,
      netSales: 18500,
      avgTxn: 440.48,
      topProducts: [
        { name: 'Рис 5кг', qty: 18, revenue: 4500 },
        { name: 'Масло 1л', qty: 15, revenue: 3750 },
        { name: 'Сахар 1кг', qty: 12, revenue: 1800 },
      ],
      paymentMethods: [
        { method: 'cash', count: 30, total: 13000 },
        { method: 'card', count: 12, total: 5500 },
      ],
      refundCount: 1,
      refundTotal: 450,
      lowStockItems: [{ name: 'Мука 2кг', stock_qty: 3 }],
      oversoldItems: [],
      yesterdayNetSales: 16200,
    }

    const aiText = await generateAISummary(testData)
    if (!aiText) {
      return reply.code(500).send({ error: 'AI summary generation failed — check API key and logs' })
    }

    const ok = await sendTelegram(
      s.telegram_bot_token,
      s.telegram_chat_id,
      `🤖 <b>AI Анализ (тест)</b>\n\n${aiText}`
    )

    if (!ok) return reply.code(500).send({ error: 'Failed to send Telegram message' })
    return { success: true, preview: aiText }
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
