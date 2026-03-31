import { pool } from '../db/connection.js'

export default async function reportsRoutes(fastify) {
  // POST /api/reports/login — exchange password for JWT
  fastify.post('/api/reports/login', async (req, reply) => {
    const { password } = req.body ?? {}
    if (!password || password !== process.env.REPORTS_PASSWORD) {
      return reply.code(401).send({ error: 'Invalid password' })
    }
    const token = fastify.jwt.sign({ role: 'reports' }, { expiresIn: '7d' })
    return { token }
  })

  // Auth hook for all report GET endpoints
  fastify.addHook('onRequest', async (req, reply) => {
    if (req.method === 'POST' && req.url === '/api/reports/login') return
    try {
      await req.jwtVerify()
    } catch {
      reply.code(401).send({ error: 'Unauthorized' })
    }
  })

  // GET /api/reports/daily?from=YYYY-MM-DD&to=YYYY-MM-DD
  fastify.get('/api/reports/daily', async (req) => {
    const { from, to } = req.query
    const fromDate = from || new Date().toISOString().slice(0, 10)
    const toDate   = to   || fromDate

    const [summary, payments] = await Promise.all([
      pool.query(
        `SELECT
           COUNT(*)                       AS transaction_count,
           COALESCE(SUM(total), 0)        AS total_sales,
           COALESCE(AVG(total), 0)        AS avg_per_transaction,
           COALESCE(SUM(subtotal), 0)     AS subtotal,
           COALESCE(SUM(discount), 0)     AS total_discount,
           COALESCE(SUM(tax), 0)          AS total_tax
         FROM transactions
         WHERE created_at::date >= $1
           AND created_at::date <= $2
           AND status = 'completed'`,
        [fromDate, toDate]
      ),
      pool.query(
        `SELECT p.method, COUNT(*) AS count, COALESCE(SUM(p.amount), 0) AS total
         FROM payments p
         JOIN transactions t ON t.id = p.transaction_id
         WHERE t.created_at::date >= $1
           AND t.created_at::date <= $2
           AND t.status = 'completed'
         GROUP BY p.method`,
        [fromDate, toDate]
      ),
    ])

    return { ...summary.rows[0], payment_methods: payments.rows }
  })

  // GET /api/reports/products?from=YYYY-MM-DD&to=YYYY-MM-DD&limit=20
  fastify.get('/api/reports/products', async (req) => {
    const { from, to, limit = '20' } = req.query
    const fromDate = from || new Date().toISOString().slice(0, 10)
    const toDate   = to   || fromDate

    const { rows } = await pool.query(
      `SELECT
         ti.product_id,
         ti.product_name,
         SUM(ti.qty)      AS total_qty,
         SUM(ti.subtotal) AS total_revenue
       FROM transaction_items ti
       JOIN transactions t ON t.id = ti.transaction_id
       WHERE t.created_at::date >= $1
         AND t.created_at::date <= $2
         AND t.status = 'completed'
         AND ti.product_name IS NOT NULL
       GROUP BY ti.product_id, ti.product_name
       ORDER BY total_qty DESC
       LIMIT $3`,
      [fromDate, toDate, parseInt(limit, 10)]
    )

    return rows
  })

  // GET /api/reports/cashiers?from=YYYY-MM-DD&to=YYYY-MM-DD
  fastify.get('/api/reports/cashiers', async (req) => {
    const { from, to } = req.query
    const fromDate = from || new Date().toISOString().slice(0, 10)
    const toDate   = to   || fromDate

    const { rows } = await pool.query(
      `SELECT
         cashier_id,
         cashier_name,
         COUNT(*)         AS transaction_count,
         SUM(total)       AS total_sales,
         AVG(total)       AS avg_per_transaction
       FROM transactions
       WHERE created_at::date >= $1
         AND created_at::date <= $2
         AND status = 'completed'
       GROUP BY cashier_id, cashier_name
       ORDER BY total_sales DESC`,
      [fromDate, toDate]
    )

    return rows
  })
}
