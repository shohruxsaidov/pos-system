import { pool } from '../db/connection.js'
import { broadcastToDesktop } from '../services/statusService.js'
import { logAudit } from '../services/auditService.js'

function generateBarcode(productId) {
  const base = `200${String(productId).padStart(6, '0')}`
  let sum = 0
  base.split('').forEach((d, i) => {
    sum += parseInt(d) * (i % 2 === 0 ? 1 : 3)
  })
  const checkDigit = (10 - (sum % 10)) % 10
  return base + checkDigit
}

export default async function barcodeRoutes(fastify) {
  // POST /api/barcode/print — phone → push print cmd to Tauri via WS
  fastify.post('/api/barcode/print', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { product_id, barcode, product_name, price, copies = 1, size = '58mm' } = req.body

    if (!barcode) return reply.code(400).send({ error: 'barcode required' })

    const sent = broadcastToDesktop({
      type: 'print_label',
      payload: { product_id, barcode, product_name, price, copies, size }
    })

    if (!sent) {
      return reply.code(503).send({ error: 'Desktop app not connected' })
    }

    await logAudit({
      action: 'barcode_print',
      actor: req.user,
      target: { type: 'product', id: product_id, name: product_name },
      details: { barcode, copies, size, source: 'mobile' },
      ip: req.ip
    })

    return { success: true }
  })

  // GET /api/barcode/generate — auto-generate barcode for product
  fastify.get('/api/barcode/generate', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { product_id } = req.query
    if (!product_id) return reply.code(400).send({ error: 'product_id required' })

    const { rows } = await pool.query('SELECT * FROM products WHERE id=$1', [product_id])
    if (!rows[0]) return reply.code(404).send({ error: 'Product not found' })

    const product = rows[0]
    if (product.barcode) {
      return { barcode: product.barcode, generated: false }
    }

    const barcode = generateBarcode(parseInt(product_id))

    // Check uniqueness
    const { rows: existing } = await pool.query('SELECT id FROM products WHERE barcode=$1', [barcode])
    if (existing.length > 0) {
      return reply.code(409).send({ error: 'Generated barcode conflicts, try again' })
    }

    await pool.query(
      'UPDATE products SET barcode=$1, updated_at=NOW() WHERE id=$2 AND barcode IS NULL',
      [barcode, product_id]
    )

    return { barcode, generated: true }
  })
}
