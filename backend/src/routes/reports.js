import argon from "argon2";
import { pool } from "../db/connection.js";
import { logAudit } from "../services/auditService.js";

// Returns today's date in local timezone as 'YYYY-MM-DD'
function localToday() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

// Returns [startDate, endDate] covering the full local calendar day.
// new Date('YYYY-MM-DDT00:00:00') — no timezone suffix — is local midnight in Node.js.
// connection.js serialises Date objects via .toISOString(), giving the correct UTC equivalent.
function localDateRange(dateStr) {
  const start = new Date(dateStr + "T00:00:00");
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return [start, end];
}

async function getPeriodData(pool, warehouseId) {
  const wid = warehouseId ? parseInt(warehouseId) : null;

  // Find opened_at = last z_report closed_at for this warehouse, or start of today
  const { rows: lastReport } = await pool.query(
    `SELECT closed_at FROM z_reports WHERE warehouse_id IS NOT DISTINCT FROM $1 ORDER BY closed_at DESC LIMIT 1`,
    [wid],
  );

  const openedAt = lastReport[0]
    ? lastReport[0].closed_at
    : new Date(localToday() + "T00:00:00"); // local midnight, not UTC midnight

  const closedAt = new Date();

  const whFilter = wid ? `AND warehouse_id = ${wid}` : "";

  // Main summary
  const { rows: summary } = await pool.query(
    `
    SELECT
      COUNT(*) as transaction_count,
      COALESCE(SUM(total), 0) as gross_sales,
      COALESCE(SUM(discount), 0) as total_discount,
      COALESCE(SUM(tax), 0) as total_tax,
      COALESCE(SUM(total), 0) - COALESCE(SUM(discount), 0) as net_sales
    FROM transactions
    WHERE created_at > $1 AND created_at <= $2 AND status != 'voided' ${whFilter}
  `,
    [openedAt, closedAt],
  );

  // Payment methods
  const { rows: paymentMethods } = await pool.query(
    `
    SELECT
      p.method as method,
      COUNT(DISTINCT t.id) as count,
      COALESCE(SUM(p.amount), 0) as amount
    FROM transactions t
    LEFT JOIN payments p ON p.transaction_id = t.id
    WHERE t.created_at > $1 AND t.created_at <= $2 AND t.status != 'voided' ${whFilter}
    GROUP BY p.method
    ORDER BY amount DESC
  `,
    [openedAt, closedAt],
  );

  // Cashier summary
  const { rows: cashierSummary } = await pool.query(
    `
    SELECT
      u.id, u.name,
      COUNT(t.id) as transaction_count,
      COALESCE(SUM(t.total), 0) as total_sales
    FROM transactions t
    JOIN users u ON u.id = t.cashier_id
    WHERE t.created_at > $1 AND t.created_at <= $2 AND t.status != 'voided' ${whFilter}
    GROUP BY u.id, u.name
    ORDER BY total_sales DESC
  `,
    [openedAt, closedAt],
  );

  // Top products
  const { rows: topProducts } = await pool.query(
    `
    SELECT
      p.id, p.name,
      SUM(ti.qty) as total_qty,
      SUM(ti.subtotal) as total_amount
    FROM transaction_items ti
    JOIN products p ON p.id = ti.product_id
    JOIN transactions t ON t.id = ti.transaction_id
    WHERE t.created_at > $1 AND t.created_at <= $2 AND t.status != 'voided' ${whFilter}
    GROUP BY p.id, p.name
    ORDER BY total_qty DESC
    LIMIT 10
  `,
    [openedAt, closedAt],
  );

  // Refunds in this period
  const { rows: refundData } = await pool.query(
    `
    SELECT COUNT(*) as refund_count, COALESCE(SUM(r.total_refund_amount), 0) as refund_amount
    FROM refunds r
    JOIN transactions t ON t.id = r.original_txn_id
    WHERE r.created_at > $1 AND r.created_at <= $2 ${whFilter ? whFilter.replace("AND warehouse_id", "AND t.warehouse_id") : ""}
  `,
    [openedAt, closedAt],
  );

  const s = summary[0];
  return {
    opened_at: openedAt,
    closed_at: closedAt,
    transaction_count: parseInt(s.transaction_count),
    gross_sales: parseFloat(s.gross_sales),
    total_discount: parseFloat(s.total_discount),
    total_tax: parseFloat(s.total_tax),
    net_sales: parseFloat(s.net_sales),
    payment_methods: paymentMethods.map((m) => ({
      method: m.payment_method,
      count: parseInt(m.count),
      amount: parseFloat(m.amount),
    })),
    cashier_summary: cashierSummary.map((c) => ({
      id: c.id,
      name: c.name,
      transaction_count: parseInt(c.transaction_count),
      total_sales: parseFloat(c.total_sales),
    })),
    top_products: topProducts.map((p) => ({
      id: p.id,
      name: p.name,
      total_qty: parseFloat(p.total_qty),
      total_amount: parseFloat(p.total_amount),
    })),
    refund_count: parseInt(refundData[0]?.refund_count || 0),
    refund_amount: parseFloat(refundData[0]?.refund_amount || 0),
  };
}

export default async function reportRoutes(fastify) {
  // GET /api/reports/daily
  fastify.get(
    "/api/reports/daily",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { date, from, to, warehouse_id } = req.query;
      const fromDate = from || date || localToday();
      const toDate = to || date || localToday();
      const wid = warehouse_id ? parseInt(warehouse_id) : null;
      const [rangeStart] = localDateRange(fromDate);
      const [, rangeEnd] = localDateRange(toDate);
      const isRange = fromDate !== toDate;

      const whFilter = wid ? `AND warehouse_id = ${wid}` : "";

      const { rows: summary } = await pool.query(
        `
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total), 0) as gross_sales,
        COALESCE(SUM(discount), 0) as total_discounts,
        COALESCE(SUM(tax), 0) as total_tax,
        COALESCE(SUM(total), 0) - COALESCE(SUM(discount), 0) as net_sales,
        COALESCE(AVG(total), 0) as avg_transaction,
        MIN(created_at) as first_sale,
        MAX(created_at) as last_sale
      FROM transactions
      WHERE created_at >= $1 AND created_at < $2 AND status != 'voided' ${whFilter}
    `,
        [rangeStart, rangeEnd],
      );

      let byHour = [];
      if (!isRange) {
        const { rows } = await pool.query(
          `
        SELECT
          EXTRACT(HOUR FROM created_at) as hour,
          COUNT(*) as count,
          COALESCE(SUM(total), 0) as sales
        FROM transactions
        WHERE created_at >= $1 AND created_at < $2 AND status != 'voided' ${whFilter}
        GROUP BY hour ORDER BY hour
      `,
          [rangeStart, rangeEnd],
        );
        byHour = rows.map((h) => ({
          ...h,
          hour: parseInt(h.hour),
          count: parseInt(h.count),
          sales: parseFloat(h.sales),
        }));
      }

      const { rows: byMethod } = await pool.query(
        `
      SELECT
        p.method as payment_method,
        COUNT(DISTINCT t.id) as count,
        COALESCE(SUM(p.amount), 0) as total
      FROM transactions t
      INNER JOIN payments p ON p.transaction_id = t.id
      WHERE t.created_at >= $1 AND t.created_at < $2 AND t.status != 'voided' ${whFilter}
      GROUP BY p.method
      ORDER BY total DESC
    `,
        [rangeStart, rangeEnd],
      );

      const { rows: refunds } = await pool.query(
        `
      SELECT COUNT(*) as count, COALESCE(SUM(total_refund_amount), 0) as total
      FROM refunds WHERE created_at >= $1 AND created_at < $2
    `,
        [rangeStart, rangeEnd],
      );

      const s = summary[0];

      return {
        date: fromDate,
        summary: {
          ...s,
          transaction_count: parseInt(s.transaction_count),
          gross_sales: parseFloat(s.gross_sales),
          total_discounts: parseFloat(s.total_discounts),
          total_tax: parseFloat(s.total_tax),
          net_sales: parseFloat(s.net_sales),
          avg_transaction: parseFloat(s.avg_transaction),
        },
        by_hour: byHour,
        by_method: byMethod.map((m) => ({
          ...m,
          count: parseInt(m.count),
          total: parseFloat(m.total),
        })),
        refunds: {
          count: parseInt(refunds[0].count),
          total: parseFloat(refunds[0].total),
        },
      };
    },
  );

  // GET /api/reports/products
  fastify.get(
    "/api/reports/products",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { from, to, limit = 20, warehouse_id } = req.query;
      const fromDate = from || localToday();
      const toDate = to || fromDate;
      const wid = warehouse_id ? parseInt(warehouse_id) : null;
      const [rangeStart] = localDateRange(fromDate);
      const [, rangeEnd] = localDateRange(toDate);

      const whFilter = wid ? `AND t.warehouse_id = ${wid}` : "";

      const { rows } = await pool.query(
        `
      SELECT
        p.id, p.name, p.barcode, p.price, p.cost,
        SUM(ti.qty) as total_qty,
        SUM(ti.subtotal) as total_revenue,
        SUM(ti.qty * COALESCE(ti.cost_at_sale, p.cost, 0)) as total_cost,
        SUM(ti.subtotal) - SUM(ti.qty * COALESCE(ti.cost_at_sale, p.cost, 0)) as gross_profit,
        COUNT(DISTINCT ti.transaction_id) as transaction_count
      FROM transaction_items ti
      JOIN products p ON p.id = ti.product_id
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.created_at >= $1 AND t.created_at < $2 AND t.status != 'voided' ${whFilter}
      GROUP BY p.id, p.name, p.barcode, p.price, p.cost
      ORDER BY total_qty DESC
      LIMIT $3
    `,
        [rangeStart, rangeEnd, limit],
      );

      return rows.map((r) => ({
        ...r,
        total_qty: parseFloat(r.total_qty),
        total_revenue: parseFloat(r.total_revenue),
        total_cost: parseFloat(r.total_cost),
        gross_profit: parseFloat(r.gross_profit),
        transaction_count: parseInt(r.transaction_count),
      }));
    },
  );

  // GET /api/reports/cashiers
  fastify.get(
    "/api/reports/cashiers",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { date, from, to, warehouse_id } = req.query;
      const fromDate = from || date || localToday();
      const toDate = to || date || localToday();
      const wid = warehouse_id ? parseInt(warehouse_id) : null;
      const [dayStart] = localDateRange(fromDate);
      const [, dayEnd] = localDateRange(toDate);

      const whFilter = wid ? `AND t.warehouse_id = ${wid}` : "";

      const { rows } = await pool.query(
        `
      SELECT
        u.id, u.name, u.role,
        COUNT(t.id) as transaction_count,
        COALESCE(SUM(t.total), 0) as total_sales,
        COALESCE(AVG(t.total), 0) as avg_transaction,
        MIN(t.created_at) as first_sale,
        MAX(t.created_at) as last_sale
      FROM users u
      LEFT JOIN transactions t ON t.cashier_id = u.id AND t.created_at >= $1 AND t.created_at < $2 AND t.status != 'voided' ${whFilter}
      WHERE u.is_active = true AND u.role IN ('cashier','manager','admin')
      GROUP BY u.id, u.name, u.role
      ORDER BY total_sales DESC
    `,
        [dayStart, dayEnd],
      );

      return rows.map((r) => ({
        ...r,
        transaction_count: parseInt(r.transaction_count),
        total_sales: parseFloat(r.total_sales),
        avg_transaction: parseFloat(r.avg_transaction),
      }));
    },
  );

  // GET /api/reports/inventory
  fastify.get(
    "/api/reports/inventory",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { status, warehouse_id } = req.query;
      const wid = warehouse_id
        ? parseInt(warehouse_id)
        : req.user.warehouse_id || 1;

      let where = "WHERE p.is_active = true";
      if (status === "low")
        where +=
          " AND COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5";
      else if (status === "out") where += " AND COALESCE(ws.stock_qty, 0) = 0";
      else if (status === "oversold") where += " AND ws.stock_qty < 0";

      const { rows } = await pool.query(
        `
      SELECT
        p.id, p.name, p.barcode, COALESCE(ws.stock_qty, 0) as stock_qty, p.cost, p.price, p.unit,
        c.name as category_name,
        COALESCE(ws.stock_qty, 0) * p.cost as inventory_value
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${where}
      ORDER BY COALESCE(ws.stock_qty, 0) ASC
    `,
        [wid],
      );

      const { rows: summary } = await pool.query(
        `
      SELECT
        COUNT(*) as total_products,
        SUM(CASE WHEN COALESCE(ws.stock_qty, 0) > 5 THEN 1 ELSE 0 END) as in_stock,
        SUM(CASE WHEN COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5 THEN 1 ELSE 0 END) as low_stock,
        SUM(CASE WHEN COALESCE(ws.stock_qty, 0) = 0 THEN 1 ELSE 0 END) as out_of_stock,
        SUM(CASE WHEN ws.stock_qty < 0 THEN 1 ELSE 0 END) as oversold,
        COALESCE(SUM(COALESCE(ws.stock_qty, 0) * p.cost), 0) as total_inventory_value
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE p.is_active = true
    `,
        [wid],
      );

      const sm = summary[0];
      return {
        products: rows,
        summary: {
          total_products: parseInt(sm.total_products),
          in_stock: parseInt(sm.in_stock),
          low_stock: parseInt(sm.low_stock),
          out_of_stock: parseInt(sm.out_of_stock),
          oversold: parseInt(sm.oversold),
          total_inventory_value: parseFloat(sm.total_inventory_value),
        },
      };
    },
  );

  // GET /api/reports/x-report
  fastify.get(
    "/api/reports/x-report",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { warehouse_id } = req.query;
      const data = await getPeriodData(pool, warehouse_id || null);
      return data;
    },
  );

  // POST /api/reports/z-report
  fastify.post(
    "/api/reports/z-report",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { manager_pin, warehouse_id } = req.body;

      if (!manager_pin) {
        return reply.code(400).send({ error: "manager_pin required" });
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

      const wid = warehouse_id ? parseInt(warehouse_id) : null;
      const periodData = await getPeriodData(pool, wid);

      // Generate report_no
      const { rows: countRows } = await pool.query(
        "SELECT COUNT(*) as cnt FROM z_reports WHERE warehouse_id IS NOT DISTINCT FROM $1",
        [wid],
      );
      const reportNo = `Z-${String(parseInt(countRows[0].cnt) + 1).padStart(4, "0")}`;

      const client = await pool.connect();
      try {
        await client.query("BEGIN");

        const { rows: reportRows } = await client.query(
          `
        INSERT INTO z_reports (
          report_no, warehouse_id, opened_at, closed_at, closed_by, closed_by_name,
          transaction_count, gross_sales, total_discount, total_tax, net_sales,
          refund_count, refund_amount, payment_methods, cashier_summary, top_products
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
        RETURNING *
      `,
          [
            reportNo,
            wid,
            periodData.opened_at,
            periodData.closed_at,
            approver.id,
            approver.name,
            periodData.transaction_count,
            periodData.gross_sales,
            periodData.total_discount,
            periodData.total_tax,
            periodData.net_sales,
            periodData.refund_count,
            periodData.refund_amount,
            JSON.stringify(periodData.payment_methods),
            JSON.stringify(periodData.cashier_summary),
            JSON.stringify(periodData.top_products),
          ],
        );

        await logAudit({
          action: "z_report",
          actor: req.user,
          approver: { id: approver.id },
          target: { type: "z_report", id: reportRows[0].id, name: reportNo },
          details: {
            report_no: reportNo,
            transaction_count: periodData.transaction_count,
            net_sales: periodData.net_sales,
            warehouse_id: wid,
          },
          ip: req.ip,
          client,
        });

        await client.query("COMMIT");

        return reply
          .code(201)
          .send({ ...periodData, report_no: reportNo, id: reportRows[0].id });
      } catch (err) {
        await client.query("ROLLBACK");
        return reply.code(500).send({ error: err.message });
      } finally {
        client.release();
      }
    },
  );

  // GET /api/reports/product/:id — per-product dynamics
  fastify.get(
    "/api/reports/product/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const productId = parseInt(req.params.id);
      const { from, to, days = 30 } = req.query;

      const fromDate =
        from ||
        (() => {
          const d = new Date();
          d.setDate(d.getDate() - parseInt(days) + 1);
          const y = d.getFullYear();
          const m = String(d.getMonth() + 1).padStart(2, "0");
          const day = String(d.getDate()).padStart(2, "0");
          return `${y}-${m}-${day}`;
        })();
      const toDate = to || localToday();
      const [rangeStart] = localDateRange(fromDate);
      const [, rangeEnd] = localDateRange(toDate);

      const { rows: productRows } = await pool.query(
        `SELECT p.*, c.name as category_name,
          COALESCE(ws.stock_qty, 0) as stock_qty
         FROM products p
         LEFT JOIN categories c ON c.id = p.category_id
         LEFT JOIN warehouse_stock ws ON ws.product_id = p.id AND ws.warehouse_id = 1
         WHERE p.id = $1`,
        [productId],
      );
      if (!productRows.length)
        return reply.code(404).send({ error: "Product not found" });

      const { rows: salesByDay } = await pool.query(
        `SELECT
          strftime('%Y-%m-%d', t.created_at) as date,
          SUM(ti.qty) as qty,
          SUM(ti.subtotal) as revenue,
          COUNT(DISTINCT ti.transaction_id) as txn_count
         FROM transaction_items ti
         JOIN transactions t ON t.id = ti.transaction_id
         WHERE ti.product_id = $1
           AND t.created_at >= $2 AND t.created_at < $3
           AND t.status != 'voided'
         GROUP BY strftime('%Y-%m-%d', t.created_at)
         ORDER BY date`,
        [productId, rangeStart, rangeEnd],
      );

      const { rows: adjustments } = await pool.query(
        `SELECT sa.delta, sa.reason, sa.created_at,
          u.name as adjusted_by_name
         FROM stock_adjustments sa
         LEFT JOIN users u ON u.id = sa.adjusted_by
         WHERE sa.product_id = $1
           AND sa.created_at >= $2 AND sa.created_at < $3
         ORDER BY sa.created_at DESC`,
        [productId, rangeStart, rangeEnd],
      );

      const { rows: incoming } = await pool.query(
        `SELECT ii.qty_received, ii.cost_per_unit, ii.expiry_date, ir.created_at,
          ir.supplier, ir.ref_no,
          u.name as received_by_name
         FROM incoming_items ii
         JOIN incoming_receipts ir ON ir.id = ii.receipt_id
         LEFT JOIN users u ON u.id = ir.received_by
         WHERE ii.product_id = $1
           AND ir.created_at >= $2 AND ir.created_at < $3
         ORDER BY ir.created_at DESC`,
        [productId, rangeStart, rangeEnd],
      );

      const { rows: refundItems } = await pool.query(
        `SELECT ri.qty_returned, ri.unit_price, ri.subtotal,
          r.ref_no, r.reason, r.created_at,
          u.name as processed_by_name
         FROM refund_items ri
         JOIN refunds r ON r.id = ri.refund_id
         LEFT JOIN users u ON u.id = r.processed_by
         WHERE ri.product_id = $1
           AND r.created_at >= $2 AND r.created_at < $3
         ORDER BY r.created_at DESC`,
        [productId, rangeStart, rangeEnd],
      );

      const { rows: summary } = await pool.query(
        `SELECT
          COALESCE(SUM(ti.qty), 0) as total_sold,
          COALESCE(SUM(ti.subtotal), 0) as total_revenue,
          COUNT(DISTINCT ti.transaction_id) as total_txns,
          (SELECT COALESCE(SUM(ri2.qty_returned), 0) FROM refund_items ri2 WHERE ri2.product_id = $1) as total_refunded_qty,
          (SELECT COALESCE(SUM(ri2.subtotal), 0) FROM refund_items ri2 WHERE ri2.product_id = $1) as total_refund_amount
         FROM transaction_items ti
         JOIN transactions t ON t.id = ti.transaction_id
         WHERE ti.product_id = $1 AND t.status != 'voided'`,
        [productId],
      );

      return {
        product: {
          ...productRows[0],
          price: parseFloat(productRows[0].price),
          cost: parseFloat(productRows[0].cost),
          stock_qty: parseInt(productRows[0].stock_qty),
        },
        sales_by_day: salesByDay.map((r) => ({
          date: r.date,
          qty: parseFloat(r.qty),
          revenue: parseFloat(r.revenue),
          txn_count: parseInt(r.txn_count),
        })),
        adjustments: adjustments.map((r) => ({
          delta: parseInt(r.delta),
          reason: r.reason,
          adjusted_by_name: r.adjusted_by_name,
          created_at: r.created_at,
        })),
        incoming: incoming.map((r) => ({
          qty_received: parseInt(r.qty_received),
          cost_per_unit: parseFloat(r.cost_per_unit),
          expiry_date: r.expiry_date,
          supplier: r.supplier,
          ref_no: r.ref_no,
          received_by_name: r.received_by_name,
          created_at: r.created_at,
        })),
        refunds: refundItems.map((r) => ({
          qty_returned: parseInt(r.qty_returned),
          unit_price: parseFloat(r.unit_price),
          subtotal: parseFloat(r.subtotal),
          ref_no: r.ref_no,
          reason: r.reason,
          processed_by_name: r.processed_by_name,
          created_at: r.created_at,
        })),
        summary: {
          total_sold: parseFloat(summary[0].total_sold),
          total_revenue: parseFloat(summary[0].total_revenue),
          total_txns: parseInt(summary[0].total_txns),
          total_incoming: incoming.reduce(
            (s, r) => s + parseInt(r.qty_received),
            0,
          ),
          total_adjustments: adjustments.length,
          total_refunded_qty: parseFloat(summary[0].total_refunded_qty),
          total_refund_amount: parseFloat(summary[0].total_refund_amount),
        },
        range: { from: fromDate, to: toDate },
      };
    },
  );

  // GET /api/reports/z-reports
  fastify.get(
    "/api/reports/z-reports",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const { warehouse_id, limit = 50, page = 1 } = req.query;
      const wid = warehouse_id ? parseInt(warehouse_id) : null;
      const offset = (page - 1) * limit;

      let rows;
      if (wid !== null) {
        ({ rows } = await pool.query(
          `SELECT * FROM z_reports WHERE warehouse_id = $1 ORDER BY closed_at DESC LIMIT $2 OFFSET $3`,
          [wid, limit, offset],
        ));
      } else {
        ({ rows } = await pool.query(
          `SELECT * FROM z_reports ORDER BY closed_at DESC LIMIT $1 OFFSET $2`,
          [limit, offset],
        ));
      }

      return rows;
    },
  );
}
