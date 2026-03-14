import argon from "argon2";
import { pool } from "../db/connection.js";
import { logAudit } from "../services/auditService.js";
import { broadcastStatus } from "../services/statusService.js";

function generateReceiptNo() {
  const d = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  return `RCV-${d}-${String(Date.now()).slice(-5)}`;
}

export default async function incomingRoutes(fastify) {
  // POST /api/incoming/auth — warehouse PIN login
  fastify.post("/api/incoming/auth", async (req, reply) => {
    const { pin } = req.body || {};
    if (!pin) return reply.code(400).send({ error: "pin required" });

    const { rows } = await pool.query(
      "SELECT * FROM users WHERE role='warehouse' AND is_active=true",
    );

    let user = null;
    for (const u of rows) {
      if (await argon.verify(u.pin_hash, String(pin))) {
        user = u;
        break;
      }
    }

    if (!user) return reply.code(401).send({ error: "Invalid PIN" });

    const token = fastify.jwt.sign(
      { id: user.id, name: user.name, role: user.role, warehouse_id: user.warehouse_id },
      { expiresIn: "12h" },
    );

    return { token, user: { id: user.id, name: user.name, role: user.role, warehouse_id: user.warehouse_id } };
  });

  // POST /api/incoming — confirm receipt
  fastify.post(
    "/api/incoming",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!["warehouse", "manager", "admin"].includes(req.user.role)) {
        return reply.code(403).send({ error: "Insufficient permissions" });
      }

      const { supplier, notes, items } = req.body;
      if (!items?.length)
        return reply.code(400).send({ error: "items required" });

      const warehouseId = req.user.warehouse_id || 1;
      const client = await pool.connect();
      try {
        await client.query("BEGIN");

        const refNo = generateReceiptNo();
        let totalCost = 0;

        const { rows: receiptRows } = await client.query(
          `INSERT INTO incoming_receipts (ref_no, received_by, supplier, notes, total_cost, warehouse_id)
           VALUES ($1,$2,$3,$4,0,$5) RETURNING *`,
          [refNo, req.user.id, supplier || null, notes || null, warehouseId],
        );
        const receipt = receiptRows[0];

        for (const item of items) {
          const subtotal = item.qty_received * item.cost_per_unit;
          totalCost += subtotal;

          await client.query(
            `INSERT INTO incoming_items (receipt_id, product_id, product_name, qty_received, cost_per_unit, expiry_date, subtotal, unit)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
            [
              receipt.id,
              item.product_id || null,
              item.product_name,
              item.qty_received,
              item.cost_per_unit || 0,
              item.expiry_date || null,
              subtotal,
              item.unit || 'шт',
            ],
          );

          if (item.product_id) {
            // Update cost on products table
            await client.query(
              "UPDATE products SET cost=$1, updated_at=NOW() WHERE id=$2",
              [item.cost_per_unit || 0, item.product_id],
            );
            // Add stock to this warehouse
            await client.query(
              `INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty, updated_at)
               VALUES ($1, $2, $3, NOW())
               ON CONFLICT (warehouse_id, product_id)
               DO UPDATE SET stock_qty = warehouse_stock.stock_qty + $4, updated_at = NOW()`,
              [warehouseId, item.product_id, item.qty_received, item.qty_received],
            );
          }
        }

        await client.query(
          "UPDATE incoming_receipts SET total_cost=$1 WHERE id=$2",
          [totalCost, receipt.id],
        );

        await client.query("COMMIT");

        await logAudit({
          action: "stock_incoming",
          actor: req.user,
          target: { type: "receipt", id: receipt.id, name: refNo },
          details: {
            supplier,
            total_cost: totalCost,
            item_count: items.length,
            warehouse_id: warehouseId,
          },
          ip: req.ip,
        });

        broadcastStatus().catch(() => {});

        return reply
          .code(201)
          .send({ ...receipt, total_cost: totalCost, ref_no: refNo });
      } catch (err) {
        await client.query("ROLLBACK");
        return reply.code(500).send({ error: err.message });
      } finally {
        client.release();
      }
    },
  );

  // GET /api/incoming
  fastify.get(
    "/api/incoming",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { page = 1, limit = 50 } = req.query;
      const offset = (page - 1) * limit;
      const warehouseId = req.user.warehouse_id || 1;

      const { rows } = await pool.query(
        `SELECT r.*, u.name as received_by_name
         FROM incoming_receipts r
         LEFT JOIN users u ON u.id=r.received_by
         WHERE r.warehouse_id=$1
         ORDER BY r.created_at DESC
         LIMIT $2 OFFSET $3`,
        [warehouseId, limit, offset],
      );

      return rows;
    },
  );

  // GET /api/incoming/:id
  fastify.get(
    "/api/incoming/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { rows } = await pool.query(
        `SELECT r.*, u.name as received_by_name
         FROM incoming_receipts r
         LEFT JOIN users u ON u.id=r.received_by
         WHERE r.id=$1`,
        [req.params.id],
      );
      if (!rows[0]) return reply.code(404).send({ error: "Receipt not found" });

      const { rows: items } = await pool.query(
        "SELECT * FROM incoming_items WHERE receipt_id=$1",
        [req.params.id],
      );

      return { ...rows[0], items };
    },
  );
}
