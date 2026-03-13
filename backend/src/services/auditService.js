import { pool } from '../db/connection.js'

/**
 * Log a sensitive action to audit_log
 * @param {object} opts
 * @param {string} opts.action - Action type (e.g. 'sale', 'refund', 'product_edit')
 * @param {object} opts.actor - { id, name, role }
 * @param {object} [opts.approver] - { id } optional approver
 * @param {object} [opts.target] - { type, id, name }
 * @param {object} [opts.details] - JSONB details object
 * @param {string} [opts.ip] - IP address
 * @param {object} [opts.client] - Optional pg client for use within a transaction
 */
export async function logAudit({ action, actor, approver, target, details, ip, client }) {
  const db = client || pool
  try {
    await db.query(
      `INSERT INTO audit_log
        (action, actor_id, actor_name, actor_role, approver_id,
         target_type, target_id, target_name, details, ip_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        action,
        actor?.id || null,
        actor?.name || null,
        actor?.role || null,
        approver?.id || null,
        target?.type || null,
        target?.id || null,
        target?.name || null,
        details ? JSON.stringify(details) : null,
        ip || null
      ]
    )
  } catch (err) {
    console.error('[audit] Failed to log action:', err.message)
  }
}
