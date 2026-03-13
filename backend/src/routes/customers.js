import { pool } from '../db/connection.js'

export default async function customerRoutes(fastify) {
  fastify.get('/api/customers', { onRequest: [fastify.authenticate] }, async (req) => {
    const { search, page = 1, limit = 50 } = req.query
    const offset = (page - 1) * limit

    let where = 'WHERE 1=1'
    const params = []
    if (search) {
      where += ` AND (name ILIKE $1 OR phone ILIKE $1)`
      params.push(`%${search}%`)
    }

    const { rows } = await pool.query(
      `SELECT * FROM customers ${where} ORDER BY name LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
      [...params, limit, offset]
    )
    return rows
  })

  fastify.get('/api/customers/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { rows } = await pool.query('SELECT * FROM customers WHERE id=$1', [req.params.id])
    if (!rows[0]) return reply.code(404).send({ error: 'Customer not found' })

    const { rows: history } = await pool.query(`
      SELECT t.*, u.name as cashier_name
      FROM transactions t
      LEFT JOIN users u ON u.id=t.cashier_id
      WHERE t.customer_id=$1
      ORDER BY t.created_at DESC LIMIT 20
    `, [req.params.id])

    return { ...rows[0], purchase_history: history }
  })

  fastify.post('/api/customers', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { name, phone, email } = req.body
    if (!name) return reply.code(400).send({ error: 'name required' })

    const { rows } = await pool.query(
      'INSERT INTO customers (name, phone, email) VALUES ($1,$2,$3) RETURNING *',
      [name, phone || null, email || null]
    )
    return reply.code(201).send(rows[0])
  })

  fastify.put('/api/customers/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { name, phone, email, loyalty_points } = req.body
    const { rows: existing } = await pool.query('SELECT * FROM customers WHERE id=$1', [req.params.id])
    if (!existing[0]) return reply.code(404).send({ error: 'Customer not found' })

    const c = existing[0]
    const { rows } = await pool.query(
      'UPDATE customers SET name=$1, phone=$2, email=$3, loyalty_points=$4 WHERE id=$5 RETURNING *',
      [name ?? c.name, phone ?? c.phone, email ?? c.email, loyalty_points ?? c.loyalty_points, req.params.id]
    )
    return rows[0]
  })

  fastify.delete('/api/customers/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { rows } = await pool.query('DELETE FROM customers WHERE id=$1 RETURNING id', [req.params.id])
    if (!rows[0]) return reply.code(404).send({ error: 'Customer not found' })
    return { success: true }
  })
}
