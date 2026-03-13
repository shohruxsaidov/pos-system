import { pool } from '../db/connection.js'

export default async function categoryRoutes(fastify) {
  fastify.get('/api/categories', async () => {
    const { rows } = await pool.query('SELECT * FROM categories ORDER BY name')
    return rows
  })

  fastify.post('/api/categories', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { name, parent_id, color, icon } = req.body
    if (!name) return reply.code(400).send({ error: 'name required' })
    const { rows } = await pool.query(
      'INSERT INTO categories (name, parent_id, color, icon) VALUES ($1,$2,$3,$4) RETURNING *',
      [name, parent_id || null, color || '#7b68ee', icon || 'pi pi-tag']
    )
    return reply.code(201).send(rows[0])
  })

  fastify.put('/api/categories/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { name, parent_id, color, icon } = req.body
    const { rows: existing } = await pool.query('SELECT * FROM categories WHERE id=$1', [req.params.id])
    if (!existing[0]) return reply.code(404).send({ error: 'Category not found' })
    const c = existing[0]
    const { rows } = await pool.query(
      'UPDATE categories SET name=$1, parent_id=$2, color=$3, icon=$4 WHERE id=$5 RETURNING *',
      [name ?? c.name, parent_id ?? c.parent_id, color ?? c.color, icon ?? c.icon, req.params.id]
    )
    return rows[0]
  })

  fastify.delete('/api/categories/:id', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    // Check if any products use this category
    const { rows: products } = await pool.query(
      'SELECT COUNT(*) FROM products WHERE category_id=$1 AND is_active=true',
      [req.params.id]
    )
    if (parseInt(products[0].count) > 0) {
      return reply.code(400).send({ error: 'Category has active products, cannot delete' })
    }
    const { rows } = await pool.query('DELETE FROM categories WHERE id=$1 RETURNING id', [req.params.id])
    if (!rows[0]) return reply.code(404).send({ error: 'Category not found' })
    return { success: true }
  })
}
