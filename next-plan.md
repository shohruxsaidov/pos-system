Here is Claude's plan:
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
Plan: Missed Sales Tracking for Daily AI Analysis

Context

When a cashier scans a barcode that doesn't exist in the system, or a customer asks for a product that's out of stock, the event is silently dropped — no logging, no
feedback. The owner has no visibility into what products customers are requesting but can't get. This feature logs those "missed sales" events and feeds them into the daily
AI end-of-day summary so Claude can identify purchasing opportunities.

Two trigger cases:

- not_found — barcode scanned but no matching product in DB (auto-logged by backend)
- out_of_stock — product found but stock_qty ≤ 0 (logged by frontend when cashier adds to cart)

---

Files to Create

- backend/src/db/migrations/006_missed_sales.sql
- backend/src/routes/missed_sales.js

Files to Modify

- backend/src/server.js — register new route
- backend/src/routes/products.js — auto-log 404 barcode lookups
- backend/src/services/notificationService.js — add missed sales to EOD summary + AI data
- backend/src/services/botService.js — add /missed bot command
- pos-desktop/src/views/POSView.vue — log out_of_stock when adding to cart

---

Step 1 — Migration 006_missed_sales.sql

CREATE TABLE IF NOT EXISTS missed_sales (
id SERIAL PRIMARY KEY,
barcode TEXT NOT NULL,
product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
product_name TEXT,
cashier_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
warehouse_id INTEGER,
reason TEXT NOT NULL DEFAULT 'not_found',
source TEXT NOT NULL DEFAULT 'desktop',
created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_missed_sales_created ON missed_sales(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_missed_sales_barcode ON missed_sales(barcode);

---

Step 2 — New Route missed_sales.js

import { pool } from '../db/connection.js'

export default async function missedSalesRoutes(fastify) {
// POST /api/missed-sales — frontend logs out_of_stock events
fastify.post('/api/missed-sales', { onRequest: [fastify.authenticate] }, async (req, reply) => {
const { barcode, product_id, product_name, reason = 'out_of_stock', source = 'desktop' } = req.body
if (!barcode) return reply.code(400).send({ error: 'barcode is required' })
const cashier_id = req.user?.id || null
const warehouse_id = req.user?.warehouse_id || null
await pool.query(
`INSERT INTO missed_sales (barcode, product_id, product_name, cashier_id, warehouse_id, reason, source)
        VALUES ($1, $2, $3, $4, $5, $6, $7)`,
[barcode, product_id || null, product_name || null, cashier_id, warehouse_id, reason, source]
)
return reply.code(201).send({ ok: true })
})
}

---

Step 3 — Register in server.js

Add after the last import (line ~39):
import missedSalesRoutes from './routes/missed_sales.js'
Add after the last fastify.register(...) call in the startup block:
await fastify.register(missedSalesRoutes)

---

Step 4 — Auto-log 404 in products.js

Inside GET /api/products/barcode/:code, after the if (!rows[0]) check, before the return reply.code(404):

if (!rows[0]) {
const source = ['desktop','mobile'].includes(req.query.source) ? req.query.source : 'desktop'
pool.query(
`INSERT INTO missed_sales (barcode, cashier_id, warehouse_id, reason, source)
      VALUES ($1, $2, $3, 'not_found', $4)`,
[req.params.code, req.user?.id || null, warehouseId, source]
).catch(e => console.error('[missed-sales] Auto-log failed:', e.message))
return reply.code(404).send({ error: 'Product not found' })
}

Also update the barcode URL in the same file if it calls itself — not needed here, only the client needs ?source=.

---

Step 5 — Desktop POSView.vue

handleBarcodeEnter (line 247) — append ?source=desktop:
const product = await api.get(`/api/products/barcode/${encodeURIComponent(searchQuery.value.trim())}?source=desktop`)

addToCart (line 256) — add out_of_stock logging + toast:
function addToCart(product) {
if (!product.is_active) return
if (product.stock_qty <= 0) {
api.post('/api/missed-sales', {
barcode: product.barcode,
product_id: product.id,
product_name: product.name,
reason: 'out_of_stock',
source: 'desktop'
}).catch(() => {})
toast.add({ severity: 'warn', summary: 'Нет в наличии', detail: `${product.name} — записано`, life: 3000 })
}
cart.addItem(product)
}
(api and toast are already imported at lines 161–162)

---

Step 6 — EOD Summary in notificationService.js

Add missed sales query after stockAdjustments query (after line 215):
const { rows: missedSales } = await pool.query(
`SELECT COALESCE(product_name, barcode) AS label, reason, COUNT(*) AS occurrences
    FROM missed_sales WHERE DATE(created_at) = $1
    GROUP BY COALESCE(product_name, barcode), reason
    ORDER BY occurrences DESC LIMIT 10`,
[today]
)

Add to Telegram message (after the topList line, before AI block):
if (missedSales.length > 0) {
const lines = missedSales.map(m => {
const icon = m.reason === 'not_found' ? '🔍' : '📭'
return `  ${icon} ${m.label} ×${m.occurrences}`
}).join('\n')
message += `\n\n<b>Запросы без наличия (${missedSales.length}):</b>\n${lines}`
}

Add to aiData object (line ~258):
missedSales: missedSales.map(m => ({
label: m.label,
reason: m.reason,
occurrences: parseInt(m.occurrences)
})),

Telegram section will look like:
Запросы без наличия (4):
🔍 4607001234567 ×3
📭 Молоко 3.2% ×2
🔍 8901030888061 ×1
📭 Хлеб белый ×1

---

Step 7 — Bot Command in botService.js

Add /missed case before case '/status' (around line 298):
case '/missed': {
const date = args[0] || today
const { rows: missed } = await pool.query(
`SELECT COALESCE(product_name, barcode) AS label, reason, COUNT(*) AS occurrences
      FROM missed_sales WHERE DATE(created_at) = $1
      GROUP BY COALESCE(product_name, barcode), reason
      ORDER BY occurrences DESC LIMIT 15`,
[date]
)
if (!missed.length) {
reply = `✅ <b>Пропущенные продажи за ${date}</b>\n\nНет данных`
break
}
const lines = missed.map(m => {
const icon = m.reason === 'not_found' ? '🔍' : '📭'
return `${icon} ${m.label} ×${m.occurrences}`
}).join('\n')
reply = `📭 <b>Пропущенные продажи за ${date}</b>\n\n${lines}`
break
}

Add to setMyCommands array (after summary):
{ command: 'missed', description: 'Пропущенные продажи: /missed или /missed YYYY-MM-DD' },

Add to /help reply string:
/missed — Пропущенные продажи сегодня\n

---

Verification

1.  Backend migration: Restart backend — confirm missed_sales table is created (check logs).
2.  not_found logging: Scan a non-existent barcode in desktop POS → check SELECT \* FROM missed_sales WHERE reason='not_found'.
3.  out_of_stock logging: Click an out-of-stock product card → confirm toast appears + row inserted with reason='out_of_stock'.
4.  Bot command: Send /missed in Telegram → should return today's data (or "Нет данных").
5.  EOD summary: Trigger POST /api/notifications/test-telegram or wait for cron → confirm "Запросы без наличия" section appears in message and AI receives the data.
