import { pool } from '../db/connection.js'

export default async function reportRoutes(fastify) {
  // GET /api/reports/daily
  fastify.get('/api/reports/daily', { onRequest: [fastify.authenticate] }, async (req) => {
    const { date = new Date().toISOString().split('T')[0] } = req.query

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
      WHERE DATE(created_at) = $1 AND status != 'voided'
    `, [date])

    const { rows: byHour } = await pool.query(`
      SELECT
        EXTRACT(HOUR FROM created_at) as hour,
        COUNT(*) as count,
        COALESCE(SUM(total), 0) as sales
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided'
      GROUP BY hour ORDER BY hour
    `, [date])

    const { rows: byMethod } = await pool.query(`
      SELECT payment_method, COUNT(*) as count, COALESCE(SUM(total), 0) as total
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided'
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
    const { from, to, limit = 20 } = req.query
    const fromDate = from || new Date().toISOString().split('T')[0]
    const toDate = to || fromDate

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
      WHERE DATE(t.created_at) BETWEEN $1 AND $2 AND t.status != 'voided'
      GROUP BY p.id, p.name, p.barcode, p.price, p.cost
      ORDER BY total_qty DESC
      LIMIT $3
    `, [fromDate, toDate, limit])

    return rows
  })

  // GET /api/reports/cashiers
  fastify.get('/api/reports/cashiers', { onRequest: [fastify.authenticate] }, async (req) => {
    const { date = new Date().toISOString().split('T')[0] } = req.query

    const { rows } = await pool.query(`
      SELECT
        u.id, u.name, u.role,
        COUNT(t.id) as transaction_count,
        COALESCE(SUM(t.total), 0) as total_sales,
        COALESCE(AVG(t.total), 0) as avg_transaction,
        MIN(t.created_at) as first_sale,
        MAX(t.created_at) as last_sale
      FROM users u
      LEFT JOIN transactions t ON t.cashier_id = u.id AND DATE(t.created_at) = $1 AND t.status != 'voided'
      WHERE u.is_active = true AND u.role IN ('cashier','manager','admin')
      GROUP BY u.id, u.name, u.role
      ORDER BY total_sales DESC
    `, [date])

    return rows
  })

  // GET /api/reports/inventory
  fastify.get('/api/reports/inventory', { onRequest: [fastify.authenticate] }, async (req) => {
    const { status } = req.query

    let where = 'WHERE p.is_active = true'
    if (status === 'low') where += ' AND p.stock_qty > 0 AND p.stock_qty <= 5'
    else if (status === 'out') where += ' AND p.stock_qty = 0'
    else if (status === 'oversold') where += ' AND p.stock_qty < 0'

    const { rows } = await pool.query(`
      SELECT
        p.id, p.name, p.barcode, p.stock_qty, p.cost, p.price, p.unit,
        c.name as category_name,
        p.stock_qty * p.cost as inventory_value
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      ${where}
      ORDER BY p.stock_qty ASC
    `)

    const { rows: summary } = await pool.query(`
      SELECT
        COUNT(*) as total_products,
        SUM(CASE WHEN stock_qty > 5 THEN 1 ELSE 0 END) as in_stock,
        SUM(CASE WHEN stock_qty > 0 AND stock_qty <= 5 THEN 1 ELSE 0 END) as low_stock,
        SUM(CASE WHEN stock_qty = 0 THEN 1 ELSE 0 END) as out_of_stock,
        SUM(CASE WHEN stock_qty < 0 THEN 1 ELSE 0 END) as oversold,
        COALESCE(SUM(stock_qty * cost), 0) as total_inventory_value
      FROM products WHERE is_active = true
    `)

    return { products: rows, summary: summary[0] }
  })
}
