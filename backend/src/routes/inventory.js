import { pool } from '../db/connection.js'

export default async function inventoryRoutes(fastify) {
  // GET /api/inventory/mobile — optimized for mobile product list
  fastify.get('/api/inventory/mobile', { onRequest: [fastify.authenticate] }, async (req) => {
    const { search, status } = req.query

    let where = 'WHERE p.is_active=true'
    const params = []

    if (search) {
      where += ` AND (p.name ILIKE $1 OR p.barcode ILIKE $1)`
      params.push(`%${search}%`)
    }
    if (status === 'low') where += ` AND p.stock_qty > 0 AND p.stock_qty <= 5`
    else if (status === 'oversold') where += ` AND p.stock_qty < 0`
    else if (status === 'out') where += ` AND p.stock_qty = 0`

    const { rows } = await pool.query(`
      SELECT p.id, p.name, p.barcode, p.stock_qty, p.price, p.unit, p.cost, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON c.id=p.category_id
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

    let where = 'WHERE 1=1'
    const params = []
    let pIdx = 1

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
