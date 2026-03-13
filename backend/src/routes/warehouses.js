import { pool } from '../db/connection.js'

export default async function warehouseRoutes(fastify) {
  // GET /api/warehouses
  fastify.get('/api/warehouses', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    if (!['manager', 'admin'].includes(req.user.role)) {
      return reply.code(403).send({ error: 'Insufficient permissions' })
    }
    const { rows } = await pool.query('SELECT * FROM warehouses ORDER BY id')
    return rows
  })

  // POST /api/warehouses
  fastify.post('/api/warehouses', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    if (req.user.role !== 'admin') {
      return reply.code(403).send({ error: 'Admin only' })
    }
    const { name } = req.body
    if (!name) return reply.code(400).send({ error: 'name required' })
    const { rows } = await pool.query(
      'INSERT INTO warehouses (name) VALUES ($1) RETURNING *',
      [name]
    )
    return reply.code(201).send(rows[0])
  })

  // PUT /api/warehouses/:id
  fastify.put('/api/warehouses/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    if (req.user.role !== 'admin') {
      return reply.code(403).send({ error: 'Admin only' })
    }
    const { name, is_active } = req.body
    const { rows } = await pool.query(
      'UPDATE warehouses SET name=COALESCE($1, name), is_active=COALESCE($2, is_active) WHERE id=$3 RETURNING *',
      [name ?? null, is_active ?? null, req.params.id]
    )
    if (!rows[0]) return reply.code(404).send({ error: 'Warehouse not found' })
    return rows[0]
  })
}
