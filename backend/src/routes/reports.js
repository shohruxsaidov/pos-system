import { pool } from '../db/connection.js'

export default async function reportRoutes(fastify) {
  // GET /api/reports/daily
  fastify.get('/api/reports/daily', { onRequest: [fastify.authenticate] }, async (req) => {
    const { date = new Date().toISOString().split('T')[0], warehouse_id } = req.query
    const wid = warehouse_id ? parseInt(warehouse_id) : null

    const whFilter = wid ? `AND warehouse_id = ${wid}` : ''

    const { rows: summary } = await pool.query(`
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total), 0) as gross_sales,
        COALESCE(SUM(discount), 0) as total_discounts,
        COALESCE(SUM(tax), 0) as total_tax,
        COALESCE(SUM(total), 0) - COALESCE(SUM(discount), 0) as net_sales,
        COALESCE(AVG(total), 0) as avg_transaction,
        MIN(created_at) as first_sale,
        MAX(created_at) as last_sale
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided' ${whFilter}
    `, [date])

    const { rows: byHour } = await pool.query(`
      SELECT
        EXTRACT(HOUR FROM created_at) as hour,
        COUNT(*) as count,
        COALESCE(SUM(total), 0) as sales
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided' ${whFilter}
      GROUP BY hour ORDER BY hour
    `, [date])

    const { rows: byMethod } = await pool.query(`
      SELECT payment_method, COUNT(*) as count, COALESCE(SUM(total), 0) as total
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided' ${whFilter}
      GROUP BY payment_method
    `, [date])

    const { rows: refunds } = await pool.query(`
      SELECT COUNT(*) as count, COALESCE(SUM(total_refund_amount), 0) as total
      FROM refunds WHERE DATE(created_at) = $1
    `, [date])

    return { date, summary: summary[0], by_hour: byHour, by_method: byMethod, refunds: refunds[0] }
  })

  // GET /api/reports/products
  fastify.get('/api/reports/products', { onRequest: [fastify.authenticate] }, async (req) => {
    const { from, to, limit = 20, warehouse_id } = req.query
    const fromDate = from || new Date().toISOString().split('T')[0]
    const toDate = to || fromDate
    const wid = warehouse_id ? parseInt(warehouse_id) : null

    const whFilter = wid ? `AND t.warehouse_id = ${wid}` : ''

    const { rows } = await pool.query(`
      SELECT
        p.id, p.name, p.barcode, p.price, p.cost,
        SUM(ti.qty) as total_qty,
        SUM(ti.subtotal) as total_revenue,
        SUM(ti.qty * p.cost) as total_cost,
        SUM(ti.subtotal) - SUM(ti.qty * p.cost) as gross_profit,
        COUNT(DISTINCT ti.transaction_id) as transaction_count
      FROM transaction_items ti
      JOIN products p ON p.id = ti.product_id
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE DATE(t.created_at) BETWEEN $1 AND $2 AND t.status != 'voided' ${whFilter}
      GROUP BY p.id, p.name, p.barcode, p.price, p.cost
      ORDER BY total_qty DESC
      LIMIT $3
    `, [fromDate, toDate, limit])

    return rows
  })

  // GET /api/reports/cashiers
  fastify.get('/api/reports/cashiers', { onRequest: [fastify.authenticate] }, async (req) => {
    const { date = new Date().toISOString().split('T')[0], warehouse_id } = req.query
    const wid = warehouse_id ? parseInt(warehouse_id) : null

    const whFilter = wid ? `AND t.warehouse_id = ${wid}` : ''

    const { rows } = await pool.query(`
      SELECT
        u.id, u.name, u.role,
        COUNT(t.id) as transaction_count,
        COALESCE(SUM(t.total), 0) as total_sales,
        COALESCE(AVG(t.total), 0) as avg_transaction,
        MIN(t.created_at) as first_sale,
        MAX(t.created_at) as last_sale
      FROM users u
      LEFT JOIN transactions t ON t.cashier_id = u.id AND DATE(t.created_at) = $1 AND t.status != 'voided' ${whFilter}
      WHERE u.is_active = true AND u.role IN ('cashier','manager','admin')
      GROUP BY u.id, u.name, u.role
      ORDER BY total_sales DESC
    `, [date])

    return rows
  })

  // GET /api/reports/inventory
  fastify.get('/api/reports/inventory', { onRequest: [fastify.authenticate] }, async (req) => {
    const { status, warehouse_id } = req.query
    const wid = warehouse_id ? parseInt(warehouse_id) : (req.user.warehouse_id || 1)

    let where = 'WHERE p.is_active = true'
    if (status === 'low') where += ' AND COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5'
    else if (status === 'out') where += ' AND COALESCE(ws.stock_qty, 0) = 0'
    else if (status === 'oversold') where += ' AND ws.stock_qty < 0'

    const { rows } = await pool.query(`
      SELECT
        p.id, p.name, p.barcode, COALESCE(ws.stock_qty, 0) as stock_qty, p.cost, p.price, p.unit,
        c.name as category_name,
        COALESCE(ws.stock_qty, 0) * p.cost as inventory_value
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${where}
      ORDER BY COALESCE(ws.stock_qty, 0) ASC
    `, [wid])

    const { rows: summary } = await pool.query(`
      SELECT
        COUNT(*) as total_products,
        SUM(CASE WHEN COALESCE(ws.stock_qty, 0) > 5 THEN 1 ELSE 0 END) as in_stock,
        SUM(CASE WHEN COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5 THEN 1 ELSE 0 END) as low_stock,
        SUM(CASE WHEN COALESCE(ws.stock_qty, 0) = 0 THEN 1 ELSE 0 END) as out_of_stock,
        SUM(CASE WHEN ws.stock_qty < 0 THEN 1 ELSE 0 END) as oversold,
        COALESCE(SUM(COALESCE(ws.stock_qty, 0) * p.cost), 0) as total_inventory_value
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE p.is_active = true
    `, [wid])

    return { products: rows, summary: summary[0] }
  })
}
