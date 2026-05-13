import { pool } from "../db/connection.js";

export default async function reportsRoutes(fastify) {
  // POST /api/reports/login — exchange password for JWT
  fastify.post("/api/reports/login", async (req, reply) => {
    const { password } = req.body ?? {};
    if (!password || password !== process.env.REPORTS_PASSWORD) {
      return reply.code(401).send({ error: "Invalid password" });
    }
    const token = fastify.jwt.sign({ role: "reports" }, { expiresIn: "7d" });
    return { token };
  });

  // Auth hook for all report GET endpoints
  fastify.addHook("onRequest", async (req, reply) => {
    if (req.method === "POST" && req.url === "/api/reports/login") return;
    try {
      await req.jwtVerify();
    } catch (err) {
      console.error("JWT verification failed:", err); // Debug log
      reply.code(401).send({ error: "Unauthorized" });
    }
  });

  // GET /api/reports/daily?from=YYYY-MM-DD&to=YYYY-MM-DD
  fastify.get("/api/reports/daily", async (req) => {
    const { from, to } = req.query;
    const fromDate = from || new Date().toISOString();
    const toDate = to || fromDate;
    console.log(`Generating daily report from ${fromDate} to ${toDate}`); // Debug log

    const [summary, payments] = await Promise.all([
      pool.query(
        `SELECT
           COUNT(*)                       AS transaction_count,
           COALESCE(SUM(total), 0)        AS total_sales,
           COALESCE(AVG(total), 0)        AS avg_per_transaction,
           COALESCE(SUM(subtotal), 0)     AS subtotal,
           COALESCE(SUM(discount), 0)     AS total_discount,
           COALESCE(SUM(tax), 0)          AS total_tax
         FROM transactions
         WHERE created_at::date >= $1
           AND created_at::date <= $2
           AND status = 'completed'`,
        [fromDate, toDate],
      ),
      pool.query(
        `SELECT p.method, COUNT(*) AS count, COALESCE(SUM(p.amount), 0) AS total
         FROM payments p
         JOIN transactions t ON t.id = p.transaction_id
         WHERE t.created_at::date >= $1
           AND t.created_at::date <= $2
           AND t.status = 'completed'
         GROUP BY p.method`,
        [fromDate, toDate],
      ),
    ]);

    return {
      from_date: fromDate,
      to_date: toDate,
      ...summary.rows[0],
      payment_methods: payments.rows,
    };
  });

  // GET /api/reports/products?from=YYYY-MM-DD&to=YYYY-MM-DD&limit=20
  fastify.get("/api/reports/products", async (req) => {
    const { from, to, limit = "20" } = req.query;
    const fromDate = from || new Date().toISOString().slice(0, 10);
    const toDate = to || fromDate;

    const { rows } = await pool.query(
      `SELECT
         ti.product_id,
         ti.product_name,
         SUM(ti.qty)      AS total_qty,
         SUM(ti.subtotal) AS total_revenue
       FROM transaction_items ti
       JOIN transactions t ON t.id = ti.transaction_id
       WHERE t.created_at::date >= $1
         AND t.created_at::date <= $2
         AND t.status = 'completed'
         AND ti.product_name IS NOT NULL
       GROUP BY ti.product_id, ti.product_name
       ORDER BY total_qty DESC
       LIMIT $3`,
      [fromDate, toDate, parseInt(limit, 10)],
    );

    return rows;
  });

  // GET /api/reports/cashiers?from=YYYY-MM-DD&to=YYYY-MM-DD
  fastify.get("/api/reports/cashiers", async (req) => {
    const { from, to } = req.query;
    const fromDate = from || new Date().toISOString().slice(0, 10);
    const toDate = to || fromDate;

    const { rows } = await pool.query(
      `SELECT
         cashier_id,
         cashier_name,
         COUNT(*)         AS transaction_count,
         SUM(total)       AS total_sales,
         AVG(total)       AS avg_per_transaction
       FROM transactions
       WHERE created_at::date >= $1
         AND created_at::date <= $2
         AND status = 'completed'
       GROUP BY cashier_id, cashier_name
       ORDER BY total_sales DESC`,
      [fromDate, toDate],
    );

    return rows;
  });

  // GET /api/transactions?from=ISO&to=ISO&page=1&limit=30
  fastify.get('/api/transactions', async (req) => {
    const { from, to, page = '1', limit = '30' } = req.query;
    const fromDate = from || new Date().toISOString();
    const toDate   = to   || fromDate;
    const pageNum  = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const offset   = (pageNum - 1) * limitNum;

    const [rows, countResult] = await Promise.all([
      pool.query(
        `SELECT ref_no, total, subtotal, discount, payment_method,
                cashier_name, status, created_at
         FROM transactions
         WHERE created_at >= $1 AND created_at <= $2
         ORDER BY created_at DESC
         LIMIT $3 OFFSET $4`,
        [fromDate, toDate, limitNum, offset]
      ),
      pool.query(
        `SELECT COUNT(*) FROM transactions
         WHERE created_at >= $1 AND created_at <= $2`,
        [fromDate, toDate]
      ),
    ]);

    return {
      transactions: rows.rows,
      total: parseInt(countResult.rows[0].count, 10),
      page: pageNum,
      limit: limitNum,
    };
  });

  // GET /api/transactions/:refNo — transaction detail with items
  fastify.get('/api/transactions/:refNo', async (req, reply) => {
    const { refNo } = req.params;

    const { rows: txnRows } = await pool.query(
      `SELECT id, ref_no, total, subtotal, discount, tax,
              payment_method, cashier_name, status, created_at
       FROM transactions WHERE ref_no = $1`,
      [refNo]
    );

    if (!txnRows.length) return reply.code(404).send({ error: 'Not found' });

    const txn = txnRows[0];

    const { rows: items } = await pool.query(
      `SELECT product_name, qty, unit_price, discount, subtotal
       FROM transaction_items WHERE transaction_id = $1
       ORDER BY id`,
      [txn.id]
    );

    return { ...txn, items };
  });

  // GET /api/sync/status — last time data was received from local POS
  fastify.get('/api/sync/status', async () => {
    const { rows } = await pool.query(`
      SELECT
        COUNT(*)              AS total,
        MAX(received_at)      AS last_sync
      FROM transactions
    `)
    return {
      total:     parseInt(rows[0].total, 10),
      last_sync: rows[0].last_sync ?? null,
    }
  })
}
