import argon from "argon2";
import { pool } from "../db/connection.js";
import { logAudit } from "../services/auditService.js";
import { broadcastStatus } from "../services/statusService.js";

function generateRefundNo() {
  const d = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  return `RFD-${d}-${String(Date.now()).slice(-5)}`;
}

export default async function refundRoutes(fastify) {
  // GET /api/transactions/:id/refundable
  fastify.get(
    "/api/transactions/:id/refundable",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { rows: txn } = await pool.query(
        "SELECT * FROM transactions WHERE id=$1 AND status IN ('completed','partially_refunded')",
        [req.params.id],
      );
      if (!txn[0])
        return reply.code(404).send({ error: "Transaction not refundable" });

      const { rows: items } = await pool.query(
        `
      SELECT ti.*, p.name as product_name,
        COALESCE((
          SELECT SUM(ri.qty_returned) FROM refund_items ri
          JOIN refunds r ON r.id=ri.refund_id
          WHERE r.original_txn_id=$1 AND ri.product_id=ti.product_id
        ), 0) as qty_refunded
      FROM transaction_items ti
      LEFT JOIN products p ON p.id=ti.product_id
      WHERE ti.transaction_id=$1
    `,
        [req.params.id],
      );

      const refundable = items
        .map((i) => ({
          ...i,
          qty_refundable: parseFloat(i.qty) - parseFloat(i.qty_refunded),
        }))
        .filter((i) => i.qty_refundable > 0);

      return { transaction: txn[0], items: refundable };
    },
  );

  // POST /api/refunds
  fastify.post(
    "/api/refunds",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { original_txn_id, items, reason, manager_pin, payment_method } =
        req.body;

      if (!original_txn_id || !items?.length || !reason || !manager_pin) {
        return reply.code(400).send({
          error: "original_txn_id, items, reason, manager_pin required",
        });
      }

      // Verify manager PIN
      const { rows: managers } = await pool.query(
        "SELECT * FROM users WHERE role IN ('manager','admin') AND is_active=true",
      );
      let approver = null;
      for (const m of managers) {
        const valid = await argon.verify(m.pin_hash, String(manager_pin));
        if (valid) {
          approver = m;
          break;
        }
      }
      if (!approver)
        return reply.code(403).send({ error: "Invalid manager PIN" });

      // Validate transaction
      const { rows: txnRows } = await pool.query(
        "SELECT * FROM transactions WHERE id=$1 AND status IN ('completed','partially_refunded')",
        [original_txn_id],
      );
      if (!txnRows[0])
        return reply
          .code(404)
          .send({ error: "Transaction not found or already fully refunded" });
      const txn = txnRows[0];

      const client = await pool.connect();
      try {
        await client.query("BEGIN");

        let totalRefundAmount = 0;
        const refundRef = generateRefundNo();

        // Determine refund type
        const { rows: allItems } = await client.query(
          "SELECT * FROM transaction_items WHERE transaction_id=$1",
          [original_txn_id],
        );

        // Insert refund header
        const { rows: refundRows } = await client.query(
          `
        INSERT INTO refunds (ref_no, original_txn_id, processed_by, approved_by, refund_type, reason, total_refund_amount, payment_method)
        VALUES ($1,$2,$3,$4,'partial',$5,0,$6) RETURNING *
      `,
          [
            refundRef,
            original_txn_id,
            req.user.id,
            approver.id,
            reason,
            payment_method || txn.payment_method,
          ],
        );
        const refund = refundRows[0];

        // Process each refund item
        for (const item of items) {
          const txnItem = allItems.find(
            (i) => i.product_id === item.product_id,
          );
          if (!txnItem)
            throw new Error(
              `Product ${item.product_id} not in original transaction`,
            );

          if (item.qty_returned > parseFloat(txnItem.qty)) {
            throw new Error(
              `Cannot refund more than purchased for product ${item.product_id}`,
            );
          }

          const itemRefundAmount =
            item.qty_returned * parseFloat(txnItem.unit_price);
          totalRefundAmount += itemRefundAmount;

          await client.query(
            `
          INSERT INTO refund_items (refund_id, product_id, product_name, qty_returned, unit_price, subtotal)
          VALUES ($1,$2,$3,$4,$5,$6)
        `,
            [
              refund.id,
              item.product_id,
              item.product_name,
              item.qty_returned,
              txnItem.unit_price,
              itemRefundAmount,
            ],
          );

          // Restock
          await client.query(
            "UPDATE products SET stock_qty=stock_qty+$1, updated_at=NOW() WHERE id=$2",
            [item.qty_returned, item.product_id],
          );
        }

        // Update refund total
        await client.query(
          "UPDATE refunds SET total_refund_amount=$1 WHERE id=$2",
          [totalRefundAmount, refund.id],
        );

        // Determine if full or partial refund
        const totalOriginalQty = allItems.reduce(
          (s, i) => s + parseFloat(i.qty),
          0,
        );
        const totalRefundedQty = items.reduce((s, i) => s + i.qty_returned, 0);
        const newStatus =
          totalRefundedQty >= totalOriginalQty
            ? "refunded"
            : "partially_refunded";

        await client.query(
          "UPDATE transactions SET status=$1, refund_id=$2 WHERE id=$3",
          [newStatus, refund.id, original_txn_id],
        );

        await client.query("COMMIT");

        await logAudit({
          action: "refund",
          actor: req.user,
          approver: { id: approver.id },
          target: {
            type: "transaction",
            id: original_txn_id,
            name: txn.ref_no,
          },
          details: { refund_ref: refundRef, amount: totalRefundAmount, reason },
          ip: req.ip,
        });

        await broadcastStatus();

        return reply.code(201).send({
          ...refund,
          total_refund_amount: totalRefundAmount,
          ref_no: refundRef,
        });
      } catch (err) {
        await client.query("ROLLBACK");
        return reply.code(500).send({ error: err.message });
      } finally {
        client.release();
      }
    },
  );

  // GET /api/refunds
  fastify.get(
    "/api/refunds",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { from, to, page = 1, limit = 50 } = req.query;
      const offset = (page - 1) * limit;

      let where = "WHERE 1=1";
      const params = [];
      let pIdx = 1;
      if (from) {
        where += ` AND r.created_at >= $${pIdx++}`;
        params.push(from);
      }
      if (to) {
        where += ` AND r.created_at <= $${pIdx++}`;
        params.push(to);
      }

      const { rows } = await pool.query(
        `
      SELECT r.*, t.ref_no as original_ref_no, u.name as processed_by_name, m.name as approved_by_name
      FROM refunds r
      JOIN transactions t ON t.id=r.original_txn_id
      LEFT JOIN users u ON u.id=r.processed_by
      LEFT JOIN users m ON m.id=r.approved_by
      ${where}
      ORDER BY r.created_at DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1}
    `,
        [...params, limit, offset],
      );

      return rows;
    },
  );

  // GET /api/refunds/:id
  fastify.get(
    "/api/refunds/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { rows } = await pool.query(
        `
      SELECT r.*, t.ref_no as original_ref_no, u.name as processed_by_name
      FROM refunds r
      JOIN transactions t ON t.id=r.original_txn_id
      LEFT JOIN users u ON u.id=r.processed_by
      WHERE r.id=$1
    `,
        [req.params.id],
      );
      if (!rows[0]) return reply.code(404).send({ error: "Refund not found" });

      const { rows: items } = await pool.query(
        "SELECT * FROM refund_items WHERE refund_id=$1",
        [req.params.id],
      );

      return { ...rows[0], items };
    },
  );
}
