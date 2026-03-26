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
      where += ` AND (p.name ILIKE $${pIdx} OR EXISTS (SELECT 1 FROM product_barcodes pb WHERE pb.product_id = p.id AND pb.barcode LIKE $${pIdx}))`
      params.push(`%${search}%`)
      pIdx++
    }
    if (status === 'low') where += ` AND COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5`
    else if (status === 'oversold') where += ` AND ws.stock_qty < 0`
    else if (status === 'out') where += ` AND COALESCE(ws.stock_qty, 0) = 0`

    const { rows } = await pool.query(`
      SELECT p.id, p.name, COALESCE(ws.stock_qty, 0) as stock_qty, p.price, p.unit, p.cost, c.name as category_name,
        COALESCE(
          (SELECT json_group_array(json_object('id', pb2.id, 'barcode', pb2.barcode, 'is_primary', pb2.is_primary))
           FROM product_barcodes pb2 WHERE pb2.product_id = p.id),
          '[]'
        ) as barcodes
      FROM products p
      LEFT JOIN categories c ON c.id=p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${where}
      ORDER BY p.name
    `, params)

    // Attach primary barcode for backward compat
    const result = rows.map(p => {
      const barcodes = Array.isArray(p.barcodes) ? p.barcodes : []
      const primary = barcodes.find(b => b.is_primary) || barcodes[0]
      return { ...p, barcode: primary?.barcode || null }
    })

    return result
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
