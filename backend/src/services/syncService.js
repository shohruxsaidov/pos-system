import { pool } from '../db/connection.js'

export async function pushToCloud() {
  const cloudUrl = process.env.CLOUD_API_URL
  const cloudKey = process.env.CLOUD_API_KEY

  if (!cloudUrl) return { pushed: 0, skipped: 0, message: 'CLOUD_API_URL not set' }

  // Fetch unsynced transaction log entries
  const { rows: pending } = await pool.query(
    `SELECT * FROM sync_log
     WHERE synced_at IS NULL AND table_name = 'transactions'
     ORDER BY created_at
     LIMIT 100`
  )

  if (!pending.length) return { pushed: 0, skipped: 0, message: 'Nothing to sync' }

  // Fetch full transaction data for each pending entry
  const transactions = []
  for (const entry of pending) {
    const { rows: [txn] } = await pool.query(
      `SELECT t.*, u.name AS cashier_name
       FROM transactions t
       LEFT JOIN users u ON u.id = t.cashier_id
       WHERE t.id = $1`,
      [entry.record_id]
    )
    if (!txn) continue

    const { rows: items } = await pool.query(
      `SELECT ti.*, p.name AS product_name
       FROM transaction_items ti
       LEFT JOIN products p ON p.id = ti.product_id
       WHERE ti.transaction_id = $1`,
      [txn.id]
    )

    const { rows: [payment] } = await pool.query(
      'SELECT * FROM payments WHERE transaction_id = $1 LIMIT 1',
      [txn.id]
    )

    transactions.push({
      ref_no:         txn.ref_no,
      cashier_id:     txn.cashier_id,
      cashier_name:   txn.cashier_name,
      warehouse_id:   txn.warehouse_id,
      customer_id:    txn.customer_id ?? null,
      subtotal:       txn.subtotal,
      discount:       txn.discount,
      tax:            txn.tax,
      total:          txn.total,
      payment_method: txn.payment_method,
      status:         txn.status,
      created_at:     txn.created_at,
      items: items.map(i => ({
        product_id:   i.product_id,
        product_name: i.product_name,
        qty:          i.qty,
        unit_price:   i.unit_price,
        discount:     i.discount,
        subtotal:     i.subtotal,
        cost_at_sale: i.cost_at_sale ?? null
      })),
      payment: payment ? {
        method:       payment.method,
        amount:       payment.amount,
        change_given: payment.change_given,
        reference:    payment.reference ?? null
      } : null
    })
  }

  if (!transactions.length) return { pushed: 0, skipped: 0, message: 'No valid transactions found' }

  // POST batch to cloud
  const res = await fetch(`${cloudUrl}/api/sync/receive`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Api-Key': cloudKey
    },
    body: JSON.stringify({ transactions })
  })

  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Cloud sync failed: ${res.status} ${text}`)
  }

  const result = await res.json()

  // Mark all pending entries as synced
  const ids = pending.map(r => r.id)
  const placeholders = ids.map((_, i) => `$${i + 1}`).join(',')
  await pool.query(
    `UPDATE sync_log SET synced_at = NOW() WHERE id IN (${placeholders})`,
    ids
  )

  console.log(`[sync] Pushed ${result.received}, skipped ${result.skipped}`)
  return { pushed: result.received, skipped: result.skipped }
}
