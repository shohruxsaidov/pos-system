import { pool } from '../db/connection.js'

export default async function inventoryRoutes(fastify) {
  // GET /api/inventory/mobile — optimized for mobile product list
  fastify.get('/api/inventory/mobile', { onRequest: [fastify.authenticate] }, async (req) => {
    const { search, status } = req.query
    const warehouseId = req.user.warehouse_id || 1

    const params = [warehouseId]
    let pIdx = 2

    let where = 'WHERE p.is_active=true'

    if (search) {
      where += ` AND (p.name ILIKE $${pIdx} OR p.barcode ILIKE $${pIdx})`
      params.push(`%${search}%`)
      pIdx++
    }
    if (status === 'low') where += ` AND COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5`
    else if (status === 'oversold') where += ` AND ws.stock_qty < 0`
    else if (status === 'out') where += ` AND COALESCE(ws.stock_qty, 0) = 0`

    const { rows } = await pool.query(`
      SELECT p.id, p.name, p.barcode, COALESCE(ws.stock_qty, 0) as stock_qty, p.price, p.unit, p.cost, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON c.id=p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${where}
      ORDER BY p.name
    `, params)

    return rows
  })

  // GET /api/inventory/adjustments — audit of adjustments
  fastify.get('/api/inventory/adjustments', { onRequest: [fastify.authenticate] }, async (req) => {
    if (!['manager', 'admin'].includes(req.user.role)) {
      return { error: 'Manager only', data: [] }
    }

    const { product_id, page = 1, limit = 50 } = req.query
    const offset = (page - 1) * limit
    const warehouseId = req.user.warehouse_id || 1

    let where = 'WHERE sa.warehouse_id=$1'
    const params = [warehouseId]
    let pIdx = 2

    if (product_id) {
      where += ` AND sa.product_id=$${pIdx++}`
      params.push(product_id)
    }

    const { rows } = await pool.query(`
      SELECT sa.*, p.name as product_name, u.name as adjusted_by_name
      FROM stock_adjustments sa
      LEFT JOIN products p ON p.id=sa.product_id
      LEFT JOIN users u ON u.id=sa.adjusted_by
      ${where}
      ORDER BY sa.created_at DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1}
    `, [...params, limit, offset])

    return rows
  })
}
