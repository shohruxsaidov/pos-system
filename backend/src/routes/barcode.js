import { pool } from '../db/connection.js'
import { printLabel } from '../services/printService.js'
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

    try {
      await printLabel({ barcode, product_name, price, copies, size })
    } catch (err) {
      if (err.message === 'Printer not connected' || err.code === 'ECONNREFUSED') {
        return reply.code(503).send({ error: 'Printer not connected' })
      }
      return reply.code(500).send({ error: err.message })
    }

    await logAudit({
      action: 'barcode_print',
      actor: req.user,
      target: { type: 'product', id: product_id, name: product_name },
      details: { barcode, copies, size, source: req.user?.role === 'warehouse' ? 'mobile' : 'desktop' },
      ip: req.ip
    })

    return { success: true }
  })

  // GET /api/barcode/generate — auto-generate + save a barcode for product
  fastify.get('/api/barcode/generate', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { product_id } = req.query
    if (!product_id) return reply.code(400).send({ error: 'product_id required' })

    const { rows } = await pool.query('SELECT * FROM products WHERE id=$1', [product_id])
    if (!rows[0]) return reply.code(404).send({ error: 'Product not found' })

    // If product has no barcodes at all, generate one as primary
    const { rows: existing } = await pool.query(
      'SELECT barcode FROM product_barcodes WHERE product_id=$1 LIMIT 1',
      [product_id]
    )
    if (existing.length > 0) {
      return { barcode: existing[0].barcode, generated: false }
    }

    const barcode = generateBarcode(parseInt(product_id))

    // Check global uniqueness
    const { rows: conflict } = await pool.query('SELECT id FROM product_barcodes WHERE barcode=$1', [barcode])
    if (conflict.length > 0) {
      return reply.code(409).send({ error: 'Generated barcode conflicts, try again' })
    }

    await pool.query(
      'INSERT INTO product_barcodes (product_id, barcode, is_primary) VALUES ($1,$2,1)',
      [product_id, barcode]
    )

    return { barcode, generated: true }
  })
}
