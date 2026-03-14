import { pool } from '../db/connection.js'
import { logAudit } from '../services/auditService.js'
import { sendLowStockAlert, sendOversoldAlert } from '../services/notificationService.js'
import { broadcastStatus } from '../services/statusService.js'
import { printReceipt } from '../services/printService.js'

function generateRefNo() {
  const now = new Date()
  const d = now.toISOString().slice(0,10).replace(/-/g,'')
  const t = String(Date.now()).slice(-6)
  return `TXN-${d}-${t}`
}

export default async function transactionRoutes(fastify) {
  // POST /api/transactions — create sale
  fastify.post('/api/transactions', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { items, customer_id, discount = 0, tax = 0, payment_method = 'cash', tendered, change_given = 0, payment_reference, print_receipt = false } = req.body

    if (!items || !items.length) {
      return reply.code(400).send({ error: 'items required' })
    }

    const warehouseId = req.user.warehouse_id || 1
    const client = await pool.connect()
    try {
      await client.query('BEGIN')

      // Validate items and calculate totals
      let subtotal = 0
      const processedItems = []
      for (const item of items) {
        const { rows } = await client.query(
          'SELECT * FROM products WHERE id=$1 AND is_active=true',
          [item.product_id]
        )
        if (!rows[0]) throw new Error(`Product ${item.product_id} not found`)
        const product = rows[0]
        const itemSubtotal = item.unit_price * item.qty - (item.discount || 0)
        subtotal += itemSubtotal
        processedItems.push({ ...item, product, itemSubtotal })
      }

      const total = subtotal - discount + tax
      const refNo = generateRefNo()

      // Insert transaction with warehouse_id
      const { rows: txnRows } = await client.query(`
        INSERT INTO transactions (ref_no, customer_id, cashier_id, subtotal, discount, tax, total, payment_method, warehouse_id)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *
      `, [refNo, customer_id || null, req.user.id, subtotal, discount, tax, total, payment_method, warehouseId])
      const txn = txnRows[0]

      // Insert items & deduct from warehouse_stock
      for (const item of processedItems) {
        await client.query(`
          INSERT INTO transaction_items (transaction_id, product_id, qty, unit_price, discount, subtotal, cost_at_sale)
          VALUES ($1,$2,$3,$4,$5,$6,$7)
        `, [txn.id, item.product_id, item.qty, item.unit_price, item.discount || 0, item.itemSubtotal, item.product.cost ?? 0])

        await client.query(`
          INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty, updated_at)
          VALUES ($1, $2, $3, NOW())
          ON CONFLICT (warehouse_id, product_id)
          DO UPDATE SET stock_qty = warehouse_stock.stock_qty - $4, updated_at = NOW()
        `, [warehouseId, item.product_id, -item.qty, item.qty])
      }

      // Insert payment
      await client.query(`
        INSERT INTO payments (transaction_id, method, amount, change_given, reference)
        VALUES ($1,$2,$3,$4,$5)
      `, [txn.id, payment_method, tendered || total, change_given, payment_reference || null])

      // Update customer loyalty points
      if (customer_id) {
        const points = Math.floor(total / 100)
        await client.query(
          'UPDATE customers SET loyalty_points=loyalty_points+$1 WHERE id=$2',
          [points, customer_id]
        )
      }

      // Add to sync log
      await client.query(
        "INSERT INTO sync_log (table_name, record_id, action, payload) VALUES ('transactions',$1,'insert',$2::jsonb)",
        [txn.id, JSON.stringify({ ref_no: refNo, total })]
      )

      await client.query('COMMIT')

      // Audit log
      await logAudit({
        action: 'sale',
        actor: req.user,
        target: { type: 'transaction', id: txn.id, name: refNo },
        details: { total, items: processedItems.length, payment_method, warehouse_id: warehouseId },
        ip: req.ip
      })

      // Post-transaction stock alerts (async, don't block response)
      for (const item of processedItems) {
        const { rows: ws } = await pool.query(
          'SELECT stock_qty FROM warehouse_stock WHERE warehouse_id=$1 AND product_id=$2',
          [warehouseId, item.product_id]
        )
        const stockQty = ws[0]?.stock_qty ?? 0
        const threshold = item.product.low_stock_threshold ?? 5
        if (stockQty < 0) sendOversoldAlert({ ...item.product, stock_qty: stockQty }).catch(() => {})
        else if (stockQty <= threshold) sendLowStockAlert({ ...item.product, stock_qty: stockQty }).catch(() => {})
      }

      broadcastStatus().catch(() => {})

      if (print_receipt) {
        printReceipt(txn.id).catch((err) => {
          fastify.log.warn(`Receipt print failed: ${err.message}`)
        })
      }

      return reply.code(201).send({ ...txn, ref_no: refNo })
    } catch (err) {
      await client.query('ROLLBACK')
      return reply.code(500).send({ error: err.message })
    } finally {
      client.release()
    }
  })

  // GET /api/transactions
  fastify.get('/api/transactions', { onRequest: [fastify.authenticate] }, async (req) => {
    const { from, to, cashier_id, status, search, page = 1, limit = 50 } = req.query
    const offset = (page - 1) * limit

    let where = 'WHERE 1=1'
    const params = []
    let pIdx = 1

    if (from) { where += ` AND t.created_at >= $${pIdx++}`; params.push(from) }
    if (to) { where += ` AND t.created_at <= $${pIdx++}`; params.push(to) }
    if (cashier_id) { where += ` AND t.cashier_id=$${pIdx++}`; params.push(cashier_id) }
    if (status) { where += ` AND t.status=$${pIdx++}`; params.push(status) }
    if (search) { where += ` AND (t.ref_no ILIKE $${pIdx++} OR u.name ILIKE $${pIdx++})`; params.push(`%${search}%`, `%${search}%`) }

    const { rows } = await pool.query(`
      SELECT t.*, u.name as cashier_name, c.name as customer_name
      FROM transactions t
      LEFT JOIN users u ON u.id=t.cashier_id
      LEFT JOIN customers c ON c.id=t.customer_id
      ${where}
      ORDER BY t.created_at DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1}
    `, [...params, limit, offset])

    const { rows: countRows } = await pool.query(
      `SELECT COUNT(*) FROM transactions t LEFT JOIN users u ON u.id=t.cashier_id LEFT JOIN customers c ON c.id=t.customer_id ${where}`,
      params
    )

    return { data: rows, total: parseInt(countRows[0].count), page: parseInt(page), limit: parseInt(limit) }
  })

  // GET /api/transactions/:id
  fastify.get('/api/transactions/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { rows } = await pool.query(`
      SELECT t.*, u.name as cashier_name, c.name as customer_name
      FROM transactions t
      LEFT JOIN users u ON u.id=t.cashier_id
      LEFT JOIN customers c ON c.id=t.customer_id
      WHERE t.id=$1
    `, [req.params.id])

    if (!rows[0]) return reply.code(404).send({ error: 'Transaction not found' })

    const { rows: items } = await pool.query(`
      SELECT ti.*, p.name as product_name, p.barcode
      FROM transaction_items ti
      LEFT JOIN products p ON p.id=ti.product_id
      WHERE ti.transaction_id=$1
    `, [req.params.id])

    const { rows: payments } = await pool.query(
      'SELECT * FROM payments WHERE transaction_id=$1',
      [req.params.id]
    )

    return { ...rows[0], items, payments }
  })

  // POST /api/transactions/:id/void
  fastify.post('/api/transactions/:id/void', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { id } = req.params
    const { rows } = await pool.query(
      "SELECT * FROM transactions WHERE id=$1 AND status='completed'",
      [id]
    )
    if (!rows[0]) return reply.code(404).send({ error: 'Transaction not found or cannot be voided' })

    const txn = rows[0]
    const warehouseId = txn.warehouse_id || 1

    // Restore stock to original warehouse
    const { rows: items } = await pool.query(
      'SELECT * FROM transaction_items WHERE transaction_id=$1',
      [id]
    )
    for (const item of items) {
      await pool.query(`
        INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty, updated_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (warehouse_id, product_id)
        DO UPDATE SET stock_qty = warehouse_stock.stock_qty + $4, updated_at = NOW()
      `, [warehouseId, item.product_id, item.qty, item.qty])
    }

    await pool.query(
      "UPDATE transactions SET status='voided' WHERE id=$1",
      [id]
    )

    await logAudit({
      action: 'void',
      actor: req.user,
      target: { type: 'transaction', id: txn.id, name: txn.ref_no },
      details: { total: txn.total, warehouse_id: warehouseId },
      ip: req.ip
    })

    await broadcastStatus()
    return { success: true }
  })
}
