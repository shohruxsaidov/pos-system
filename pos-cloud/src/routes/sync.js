import { pool } from '../db/connection.js'

export default async function syncRoutes(fastify) {
  // Auth hook — all routes in this plugin require X-Api-Key
  fastify.addHook('onRequest', async (req, reply) => {
    const key = req.headers['x-api-key']
    if (!key || key !== process.env.API_KEY) {
      reply.code(401).send({ error: 'Unauthorized' })
    }
  })

  // POST /api/sync/receive — receive a batch of transactions from local POS
  fastify.post('/api/sync/receive', async (req, reply) => {
    const { transactions } = req.body

    if (!Array.isArray(transactions) || !transactions.length) {
      return reply.code(400).send({ error: 'transactions array required' })
    }

    let received = 0
    let skipped = 0

    for (const txn of transactions) {
      const client = await pool.connect()
      try {
        await client.query('BEGIN')

        // Insert transaction — skip if ref_no already exists (idempotent)
        const { rowCount } = await client.query(
          `INSERT INTO transactions
             (ref_no, cashier_id, cashier_name, warehouse_id, customer_id,
              subtotal, discount, tax, total, payment_method, status, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
           ON CONFLICT (ref_no) DO NOTHING`,
          [
            txn.ref_no, txn.cashier_id, txn.cashier_name, txn.warehouse_id,
            txn.customer_id ?? null, txn.subtotal, txn.discount ?? 0,
            txn.tax ?? 0, txn.total, txn.payment_method, txn.status, txn.created_at
          ]
        )

        if (rowCount === 0) {
          // Already exists — skip items/payment too
          await client.query('ROLLBACK')
          skipped++
          continue
        }

        // Get the inserted transaction id
        const { rows: [row] } = await client.query(
          'SELECT id FROM transactions WHERE ref_no = $1',
          [txn.ref_no]
        )
        const txnId = row.id

        // Insert items
        for (const item of txn.items ?? []) {
          await client.query(
            `INSERT INTO transaction_items
               (transaction_id, product_id, product_name, qty, unit_price, discount, subtotal, cost_at_sale)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
            [
              txnId, item.product_id ?? null, item.product_name ?? null,
              item.qty, item.unit_price, item.discount ?? 0,
              item.subtotal, item.cost_at_sale ?? null
            ]
          )
        }

        // Insert payment
        if (txn.payment) {
          await client.query(
            `INSERT INTO payments (transaction_id, method, amount, change_given, reference)
             VALUES ($1,$2,$3,$4,$5)`,
            [
              txnId, txn.payment.method, txn.payment.amount,
              txn.payment.change_given ?? 0, txn.payment.reference ?? null
            ]
          )
        }

        await client.query('COMMIT')
        received++
      } catch (err) {
        await client.query('ROLLBACK')
        throw err
      } finally {
        client.release()
      }
    }

    return { received, skipped }
  })
}
