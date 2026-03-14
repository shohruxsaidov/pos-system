import { pool } from '../db/connection.js'
import { logAudit } from '../services/auditService.js'
import { sendLowStockAlert, sendOversoldAlert } from '../services/notificationService.js'
import { broadcastStatus } from '../services/statusService.js'

async function checkStockAlerts(product, warehouseId) {
  try {
    const threshold = product.low_stock_threshold ?? 5
    const { rows: ws } = await pool.query(
      'SELECT stock_qty FROM warehouse_stock WHERE warehouse_id=$1 AND product_id=$2',
      [warehouseId, product.id]
    )
    const stockQty = ws[0]?.stock_qty ?? 0
    if (stockQty < 0) await sendOversoldAlert({ ...product, stock_qty: stockQty })
    else if (stockQty <= threshold) await sendLowStockAlert({ ...product, stock_qty: stockQty })
  } catch (e) {
    console.error('[products] Stock alert check failed:', e.message)
  }
}

export default async function productRoutes(fastify) {
  // GET /api/products
  fastify.get('/api/products', { onRequest: [fastify.authenticate] }, async (req) => {
    const { search, category_id, stock_status, page = 1, limit = 50 } = req.query
    const warehouseId = req.user.warehouse_id || 1
    const offset = (page - 1) * limit

    const params = [warehouseId]  // $1 = warehouse_id
    let pIdx = 2

    let whereClause = 'WHERE p.is_active=true'

    if (search) {
      whereClause += ` AND (p.name ILIKE $${pIdx} OR p.barcode ILIKE $${pIdx})`
      params.push(`%${search}%`)
      pIdx++
    }
    if (category_id) {
      whereClause += ` AND p.category_id=$${pIdx}`
      params.push(category_id)
      pIdx++
    }
    if (stock_status === 'low') {
      whereClause += ` AND COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5`
    } else if (stock_status === 'out') {
      whereClause += ` AND COALESCE(ws.stock_qty, 0) = 0`
    } else if (stock_status === 'oversold') {
      whereClause += ` AND ws.stock_qty < 0`
    }

    const { rows } = await pool.query(`
      SELECT p.*, c.name as category_name, COALESCE(ws.stock_qty, 0) AS stock_qty
      FROM products p
      LEFT JOIN categories c ON c.id=p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${whereClause}
      ORDER BY p.name
      LIMIT $${pIdx} OFFSET $${pIdx + 1}
    `, [...params, limit, offset])

    const { rows: countRows } = await pool.query(`
      SELECT COUNT(*)
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${whereClause}
    `, params)

    return { data: rows, total: parseInt(countRows[0].count), page: parseInt(page), limit: parseInt(limit) }
  })

  // GET /api/products/barcode/:code
  fastify.get('/api/products/barcode/:code', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const warehouseId = req.user.warehouse_id || 1
    const { rows } = await pool.query(`
      SELECT p.*, c.name as category_name, COALESCE(ws.stock_qty, 0) AS stock_qty
      FROM products p
      LEFT JOIN categories c ON c.id=p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE p.barcode=$2 AND p.is_active=true
    `, [warehouseId, req.params.code])
    if (!rows[0]) return reply.code(404).send({ error: 'Product not found' })
    return rows[0]
  })

  // POST /api/products
  fastify.post('/api/products', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { barcode, name, category_id, price, cost, stock_qty, unit, image_url, low_stock_threshold } = req.body
    if (!name || price === undefined) {
      return reply.code(400).send({ error: 'name and price are required' })
    }

    const { rows } = await pool.query(`
      INSERT INTO products (barcode, name, category_id, price, cost, unit, image_url, low_stock_threshold)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *
    `, [barcode || null, name, category_id || null, price, cost || 0, unit || 'pcs', image_url || null, low_stock_threshold ?? 5])

    const warehouseId = req.user.warehouse_id || 1
    const initialStock = stock_qty || 0
    await pool.query(`
      INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty)
      VALUES ($1, $2, $3)
      ON CONFLICT (warehouse_id, product_id) DO UPDATE SET stock_qty = EXCLUDED.stock_qty
    `, [warehouseId, rows[0].id, initialStock])

    await logAudit({
      action: 'product_create',
      actor: req.user,
      target: { type: 'product', id: rows[0].id, name: rows[0].name },
      ip: req.ip
    })

    return reply.code(201).send({ ...rows[0], stock_qty: initialStock })
  })

  // PUT /api/products/:id
  fastify.put('/api/products/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { id } = req.params
    const { barcode, name, category_id, price, cost, unit, image_url, is_active, low_stock_threshold } = req.body

    const { rows: before } = await pool.query('SELECT * FROM products WHERE id=$1', [id])
    if (!before[0]) return reply.code(404).send({ error: 'Product not found' })

    const { rows } = await pool.query(`
      UPDATE products SET
        barcode=$1, name=$2, category_id=$3, price=$4, cost=$5,
        unit=$6, image_url=$7, is_active=$8, low_stock_threshold=$9, updated_at=NOW()
      WHERE id=$10 RETURNING *
    `, [
      barcode ?? before[0].barcode,
      name ?? before[0].name,
      category_id ?? before[0].category_id,
      price ?? before[0].price,
      cost ?? before[0].cost,
      unit ?? before[0].unit,
      image_url ?? before[0].image_url,
      is_active ?? before[0].is_active,
      low_stock_threshold ?? before[0].low_stock_threshold ?? 5,
      id
    ])

    await logAudit({
      action: 'product_edit',
      actor: req.user,
      target: { type: 'product', id: rows[0].id, name: rows[0].name },
      details: { before: before[0], after: rows[0] },
      ip: req.ip
    })

    const warehouseId = req.user.warehouse_id || 1
    const { rows: result } = await pool.query(`
      SELECT p.*, COALESCE(ws.stock_qty, 0) as stock_qty
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE p.id=$2
    `, [warehouseId, id])
    return result[0]
  })

  // PATCH /api/products/:id/stock
  fastify.patch('/api/products/:id/stock', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { id } = req.params
    const { delta, reason } = req.body
    if (delta === undefined || !reason) {
      return reply.code(400).send({ error: 'delta and reason are required' })
    }

    const { rows: before } = await pool.query('SELECT * FROM products WHERE id=$1 AND is_active=true', [id])
    if (!before[0]) return reply.code(404).send({ error: 'Product not found' })

    const warehouseId = req.user.warehouse_id || 1

    const { rows: wsBefore } = await pool.query(
      'SELECT stock_qty FROM warehouse_stock WHERE warehouse_id=$1 AND product_id=$2',
      [warehouseId, id]
    )
    const stockBefore = wsBefore[0]?.stock_qty ?? 0

    await pool.query(`
      INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty, updated_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (warehouse_id, product_id)
      DO UPDATE SET stock_qty = warehouse_stock.stock_qty + $4, updated_at = NOW()
    `, [warehouseId, id, delta, delta])

    await pool.query(
      'INSERT INTO stock_adjustments (product_id, adjusted_by, delta, reason, warehouse_id) VALUES ($1,$2,$3,$4,$5)',
      [id, req.user?.id, delta, reason, warehouseId]
    )

    await logAudit({
      action: 'stock_adjust',
      actor: req.user,
      target: { type: 'product', id: before[0].id, name: before[0].name },
      details: { before: stockBefore, after: stockBefore + delta, delta, reason, warehouse_id: warehouseId },
      ip: req.ip
    })

    await checkStockAlerts(before[0], warehouseId)
    await broadcastStatus()

    const { rows: result } = await pool.query(`
      SELECT p.*, COALESCE(ws.stock_qty, 0) as stock_qty
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE p.id=$2
    `, [warehouseId, id])
    return result[0]
  })

  // DELETE /api/products/:id
  fastify.delete('/api/products/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { id } = req.params
    const { rows } = await pool.query(
      'UPDATE products SET is_active=false, updated_at=NOW() WHERE id=$1 RETURNING *',
      [id]
    )
    if (!rows[0]) return reply.code(404).send({ error: 'Product not found' })

    await logAudit({
      action: 'product_delete',
      actor: req.user,
      target: { type: 'product', id: rows[0].id, name: rows[0].name },
      ip: req.ip
    })

    return { success: true }
  })
}
