import { pool } from '../db/connection.js'

async function getSettings() {
  const { rows } = await pool.query('SELECT key, value FROM settings')
  return Object.fromEntries(rows.map(r => [r.key, r.value]))
}

export async function sendTelegram(token, chatId, message) {
  if (!token || !chatId) return false
  try {
    const url = `https://api.telegram.org/bot${token}/sendMessage`
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: 'HTML'
      }),
      signal: AbortSignal.timeout(10000)
    })
    const data = await res.json()
    if (!data.ok) {
      console.error('[telegram] Send failed:', data.description)
      return false
    }
    return true
  } catch (err) {
    console.error('[telegram] Error sending message:', err.message)
    return false
  }
}

export async function sendLowStockAlert(product) {
  try {
    const settings = await getSettings()
    if (settings.telegram_enabled !== 'true') return
    const token = settings.telegram_bot_token
    const chatId = settings.telegram_chat_id
    const storeName = settings.store_name || 'Store'

    const message = `⚠️ <b>Low Stock Alert</b>\n\nProduct: ${product.name}\nStock: ${product.stock_qty} units\nBranch: ${storeName}\n\nAction needed: reorder`
    await sendTelegram(token, chatId, message)
  } catch (err) {
    console.error('[notify] Low stock alert failed:', err.message)
  }
}

export async function sendOversoldAlert(product) {
  try {
    const settings = await getSettings()
    if (settings.telegram_enabled !== 'true') return
    const token = settings.telegram_bot_token
    const chatId = settings.telegram_chat_id
    const storeName = settings.store_name || 'Store'

    const message = `🚨 <b>Oversold Alert</b>\n\nProduct: ${product.name}\nStock: ${product.stock_qty} (OVERSOLD)\nBranch: ${storeName}\n\nAction needed: receive stock`
    await sendTelegram(token, chatId, message)
  } catch (err) {
    console.error('[notify] Oversold alert failed:', err.message)
  }
}

export async function sendEODSummary() {
  try {
    const settings = await getSettings()
    if (settings.telegram_enabled !== 'true') return
    const token = settings.telegram_bot_token
    const chatId = settings.telegram_chat_id
    const storeName = settings.store_name || 'Store'

    const today = new Date().toISOString().split('T')[0]
    const { rows: summary } = await pool.query(`
      SELECT
        COUNT(*) as txn_count,
        COALESCE(SUM(total), 0) as net_sales,
        COALESCE(AVG(total), 0) as avg_txn
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided'
    `, [today])

    const { rows: topProducts } = await pool.query(`
      SELECT p.name, SUM(ti.qty) as total_qty
      FROM transaction_items ti
      JOIN products p ON p.id = ti.product_id
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE DATE(t.created_at) = $1 AND t.status != 'voided'
      GROUP BY p.id, p.name
      ORDER BY total_qty DESC
      LIMIT 3
    `, [today])

    const s = summary[0]
    const topList = topProducts.map((p, i) => `${i + 1}. ${p.name} (${p.total_qty} sold)`).join('\n')

    const message = `📊 <b>End of Day Summary</b>\n\n` +
      `Branch: ${storeName}\nDate: ${today}\n\n` +
      `Transactions: ${s.txn_count}\n` +
      `Net Sales: ₱${parseFloat(s.net_sales).toFixed(2)}\n` +
      `Avg/Txn: ₱${parseFloat(s.avg_txn).toFixed(2)}\n\n` +
      `<b>Top Products:</b>\n${topList || 'No sales today'}`

    await sendTelegram(token, chatId, message)
  } catch (err) {
    console.error('[notify] EOD summary failed:', err.message)
  }
}
