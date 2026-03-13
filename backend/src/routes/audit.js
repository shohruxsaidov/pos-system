import { pool } from '../db/connection.js'

export default async function auditRoutes(fastify) {
  fastify.get('/api/audit', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    if (!['manager', 'admin'].includes(req.user.role)) {
      return reply.code(403).send({ error: 'Manager or admin access required' })
    }

    const { action, actor_id, from, to, target_type, page = 1, limit = 50 } = req.query
    const offset = (page - 1) * limit

    let where = 'WHERE 1=1'
    const params = []
    let pIdx = 1

    if (action) { where += ` AND al.action=$${pIdx++}`; params.push(action) }
    if (actor_id) { where += ` AND al.actor_id=$${pIdx++}`; params.push(actor_id) }
    if (from) { where += ` AND al.created_at >= $${pIdx++}`; params.push(from) }
    if (to) { where += ` AND al.created_at <= $${pIdx++}`; params.push(to) }
    if (target_type) { where += ` AND al.target_type=$${pIdx++}`; params.push(target_type) }

    const { rows } = await pool.query(`
      SELECT al.*
      FROM audit_log al
      ${where}
      ORDER BY al.created_at DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1}
    `, [...params, limit, offset])

    const { rows: countRows } = await pool.query(
      `SELECT COUNT(*) FROM audit_log al ${where}`,
      params
    )

    return {
      data: rows,
      total: parseInt(countRows[0].count),
      page: parseInt(page),
      limit: parseInt(limit)
    }
  })
}
