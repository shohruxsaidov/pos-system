import { pool } from "../db/connection.js";
import { logAudit } from "../services/auditService.js";
import {
  sendLowStockAlert,
  sendOversoldAlert,
} from "../services/notificationService.js";
import { broadcastStatus } from "../services/statusService.js";

const BARCODES_SUBQUERY = `
  COALESCE(
    (SELECT json_group_array(json_object('id', pb2.id, 'barcode', pb2.barcode, 'is_primary', pb2.is_primary))
     FROM product_barcodes pb2 WHERE pb2.product_id = p.id),
    '[]'
  ) as barcodes`;

function withPrimaryBarcode(product) {
  const barcodes = Array.isArray(product.barcodes) ? product.barcodes : [];
  const primary = barcodes.find((b) => b.is_primary) || barcodes[0];
  return { ...product, barcode: primary?.barcode || null };
}

// Trim, drop blanks, de-duplicate, and guarantee exactly one primary.
function normalizeBarcodes(barcodes) {
  const seen = new Set();
  const clean = [];
  for (const bc of barcodes || []) {
    const code = bc?.barcode?.trim();
    if (!code || seen.has(code)) continue;
    seen.add(code);
    clean.push({ barcode: code, is_primary: bc.is_primary ? 1 : 0 });
  }
  if (clean.length > 0 && !clean.some((b) => b.is_primary)) {
    clean[0].is_primary = 1;
  }
  return clean;
}

// `product_barcodes.barcode` is globally UNIQUE, so a code held by another
// product cannot simply be inserted. Free the ones held by deleted (inactive)
// products, and reject the ones still in use so the cashier gets told why.
async function claimBarcodes(productId, barcodes, { actor, ip } = {}) {
  for (const bc of barcodes) {
    const { rows } = await pool.query(
      `SELECT pb.id, p.id AS product_id, p.name, p.is_active
       FROM product_barcodes pb
       LEFT JOIN products p ON p.id = pb.product_id
       WHERE pb.barcode=$1`,
      [bc.barcode],
    );
    const owner = rows[0];
    if (!owner) continue;
    if (productId && String(owner.product_id) === String(productId)) continue;

    if (owner.product_id && owner.is_active) {
      const err = new Error(
        `Штрихкод ${bc.barcode} уже используется товаром «${owner.name}»`,
      );
      err.statusCode = 409;
      throw err;
    }

    // Owner is deleted (or missing) — release the code for reuse.
    await pool.query("DELETE FROM product_barcodes WHERE id=$1", [owner.id]);
    if (owner.product_id) {
      await logAudit({
        action: "product_edit",
        actor,
        target: { type: "product", id: owner.product_id, name: owner.name },
        details: { field: "barcode", before: bc.barcode, after: null,
                   reason: "reassigned_from_deleted_product" },
        ip,
      });
    }
  }
}

async function saveBarcodes(productId, barcodes) {
  await pool.query("DELETE FROM product_barcodes WHERE product_id=$1", [
    productId,
  ]);
  for (const bc of barcodes) {
    await pool.query(
      "INSERT INTO product_barcodes (product_id, barcode, is_primary) VALUES ($1,$2,$3)",
      [productId, bc.barcode, bc.is_primary],
    );
  }
}

async function readProduct(productId, warehouseId) {
  const { rows } = await pool.query(
    `SELECT p.*, COALESCE(ws.stock_qty, 0) as stock_qty, ${BARCODES_SUBQUERY}
     FROM products p
     LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
     WHERE p.id=$2`,
    [warehouseId, productId],
  );
  return withPrimaryBarcode(rows[0]);
}

async function checkStockAlerts(product, warehouseId) {
  try {
    const threshold = product.low_stock_threshold ?? 5;
    const { rows: ws } = await pool.query(
      "SELECT stock_qty FROM warehouse_stock WHERE warehouse_id=$1 AND product_id=$2",
      [warehouseId, product.id],
    );
    const stockQty = ws[0]?.stock_qty ?? 0;
    if (stockQty < 0)
      await sendOversoldAlert({ ...product, stock_qty: stockQty });
    else if (stockQty <= threshold)
      await sendLowStockAlert({ ...product, stock_qty: stockQty });
  } catch (e) {
    console.error("[products] Stock alert check failed:", e.message);
  }
}

export default async function productRoutes(fastify) {
  // GET /api/products
  fastify.get(
    "/api/products",
    { onRequest: [fastify.authenticate] },
    async (req) => {
      const {
        search,
        category_id,
        stock_status,
        page = 1,
        limit = 50,
      } = req.query;
      const warehouseId = req.user.warehouse_id || 1;
      const offset = (page - 1) * limit;

      const params = [warehouseId]; // $1 = warehouse_id
      let pIdx = 2;

      let whereClause = "WHERE p.is_active=true";

      if (search) {
        whereClause += ` AND (p.name ILIKE $${pIdx} OR EXISTS (SELECT 1 FROM product_barcodes pb WHERE pb.product_id = p.id AND pb.barcode LIKE $${pIdx}))`;
        params.push(`%${search}%`);
        pIdx++;
      }
      if (category_id) {
        whereClause += ` AND p.category_id=$${pIdx}`;
        params.push(category_id);
        pIdx++;
      }
      // Within a single category, respect the manual order number (0 = unset → alphabetical, last)
      const orderClause = category_id
        ? "ORDER BY CASE WHEN p.sort_order > 0 THEN 0 ELSE 1 END, p.sort_order, p.name"
        : "ORDER BY p.name";

      if (stock_status === "low") {
        whereClause += ` AND COALESCE(ws.stock_qty, 0) > 0 AND COALESCE(ws.stock_qty, 0) <= 5`;
      } else if (stock_status === "out") {
        whereClause += ` AND COALESCE(ws.stock_qty, 0) = 0`;
      } else if (stock_status === "oversold") {
        whereClause += ` AND ws.stock_qty < 0`;
      }

      const { rows } = await pool.query(
        `
      SELECT p.*, c.name as category_name, COALESCE(ws.stock_qty, 0) AS stock_qty, ${BARCODES_SUBQUERY}
      FROM products p
      LEFT JOIN categories c ON c.id=p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${whereClause}
      ${orderClause}
      LIMIT $${pIdx} OFFSET $${pIdx + 1}
    `,
        [...params, limit, offset],
      );

      const { rows: countRows } = await pool.query(
        `
      SELECT COUNT(*) as count
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      ${whereClause}
    `,
        params,
      );

      return {
        data: rows.map(withPrimaryBarcode),
        total: parseInt(countRows[0].count),
        page: parseInt(page),
        limit: parseInt(limit),
      };
    },
  );

  // GET /api/products/barcode/:code
  fastify.get(
    "/api/products/barcode/:code",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const warehouseId = req.user.warehouse_id || 1;
      const { rows } = await pool.query(
        `
      SELECT p.*, c.name as category_name, COALESCE(ws.stock_qty, 0) AS stock_qty, ${BARCODES_SUBQUERY}
      FROM products p
      INNER JOIN product_barcodes pb ON pb.product_id = p.id
      LEFT JOIN categories c ON c.id=p.category_id
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE pb.barcode=$2 AND p.is_active=true
    `,
        [warehouseId, req.params.code],
      );
      if (!rows[0]) return reply.code(404).send({ error: "Product not found" });
      return withPrimaryBarcode(rows[0]);
    },
  );

  // POST /api/products
  fastify.post(
    "/api/products",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const {
        barcode,
        barcodes,
        name,
        category_id,
        price,
        cost,
        stock_qty,
        unit,
        image_url,
        low_stock_threshold,
        sort_order,
      } = req.body;
      if (!name || price === undefined) {
        return reply.code(400).send({ error: "name and price are required" });
      }

      // Resolve barcode ownership first — a conflict must not leave a
      // half-created product behind.
      const barcodesToSave = normalizeBarcodes(
        Array.isArray(barcodes) && barcodes.length > 0
          ? barcodes
          : barcode
            ? [{ barcode, is_primary: 1 }]
            : [],
      );
      try {
        await claimBarcodes(null, barcodesToSave, {
          actor: req.user,
          ip: req.ip,
        });
      } catch (e) {
        if (e.statusCode === 409)
          return reply.code(409).send({ error: e.message });
        throw e;
      }

      const { rows } = await pool.query(
        `
      INSERT INTO products (name, category_id, price, cost, unit, image_url, low_stock_threshold, sort_order, updated_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8, NOW()) RETURNING *
    `,
        [
          name,
          category_id || null,
          price,
          cost || 0,
          unit || "pcs",
          image_url || null,
          low_stock_threshold ?? 5,
          parseInt(sort_order, 10) || 0,
        ],
      );

      const productId = rows[0].id;
      const warehouseId = req.user.warehouse_id || 1;
      const initialStock = stock_qty || 0;

      await pool.query(
        `
      INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty)
      VALUES ($1, $2, $3)
      ON CONFLICT (warehouse_id, product_id) DO UPDATE SET stock_qty = EXCLUDED.stock_qty
    `,
        [warehouseId, productId, initialStock],
      );

      await saveBarcodes(productId, barcodesToSave);

      await logAudit({
        action: "product_create",
        actor: req.user,
        target: { type: "product", id: productId, name: rows[0].name },
        ip: req.ip,
      });

      // Read back from the DB so the client sees what was actually persisted.
      return reply.code(201).send(await readProduct(productId, warehouseId));
    },
  );

  // PUT /api/products/:id
  fastify.put(
    "/api/products/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { id } = req.params;
      const {
        barcodes,
        name,
        category_id,
        price,
        cost,
        unit,
        image_url,
        is_active,
        low_stock_threshold,
        sort_order,
      } = req.body;

      const { rows: before } = await pool.query(
        "SELECT * FROM products WHERE id=$1",
        [id],
      );
      if (!before[0])
        return reply.code(404).send({ error: "Product not found" });

      // Resolve barcode ownership before touching the product row.
      let barcodesToSave = null;
      if (Array.isArray(barcodes)) {
        barcodesToSave = normalizeBarcodes(barcodes);
        try {
          await claimBarcodes(id, barcodesToSave, {
            actor: req.user,
            ip: req.ip,
          });
        } catch (e) {
          if (e.statusCode === 409)
            return reply.code(409).send({ error: e.message });
          throw e;
        }
      }

      const { rows } = await pool.query(
        `
      UPDATE products SET
        name=$1, category_id=$2, price=$3, cost=$4,
        unit=$5, image_url=$6, is_active=$7, low_stock_threshold=$8, sort_order=$9, updated_at=NOW()
      WHERE id=$10 RETURNING *
    `,
        [
          name ?? before[0].name,
          category_id ?? before[0].category_id,
          price ?? before[0].price,
          cost ?? before[0].cost,
          unit ?? before[0].unit,
          image_url ?? before[0].image_url,
          is_active ?? before[0].is_active,
          low_stock_threshold ?? before[0].low_stock_threshold ?? 5,
          sort_order === undefined || sort_order === null || sort_order === ""
            ? (before[0].sort_order ?? 0)
            : parseInt(sort_order, 10) || 0,
          id,
        ],
      );

      if (barcodesToSave) await saveBarcodes(id, barcodesToSave);

      await logAudit({
        action: "product_edit",
        actor: req.user,
        target: { type: "product", id: rows[0].id, name: rows[0].name },
        details: { before: before[0], after: rows[0] },
        ip: req.ip,
      });

      return await readProduct(id, req.user.warehouse_id || 1);
    },
  );

  // PATCH /api/products/:id/stock
  fastify.patch(
    "/api/products/:id/stock",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { id } = req.params;
      const { delta, reason } = req.body;
      if (delta === undefined || !reason) {
        return reply.code(400).send({ error: "delta and reason are required" });
      }

      const { rows: before } = await pool.query(
        "SELECT * FROM products WHERE id=$1 AND is_active=true",
        [id],
      );
      if (!before[0])
        return reply.code(404).send({ error: "Product not found" });

      const warehouseId = req.user.warehouse_id || 1;

      const { rows: wsBefore } = await pool.query(
        "SELECT stock_qty FROM warehouse_stock WHERE warehouse_id=$1 AND product_id=$2",
        [warehouseId, id],
      );
      const stockBefore = wsBefore[0]?.stock_qty ?? 0;

      await pool.query(
        `
      INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty, updated_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (warehouse_id, product_id)
      DO UPDATE SET stock_qty = warehouse_stock.stock_qty + $4, updated_at = NOW()
    `,
        [warehouseId, id, delta, delta],
      );

      await pool.query(
        "INSERT INTO stock_adjustments (product_id, adjusted_by, delta, reason, warehouse_id, created_at) VALUES ($1,$2,$3,$4,$5, NOW())",
        [id, req.user?.id, delta, reason, warehouseId],
      );

      await logAudit({
        action: "stock_adjust",
        actor: req.user,
        target: { type: "product", id: before[0].id, name: before[0].name },
        details: {
          before: stockBefore,
          after: stockBefore + delta,
          delta,
          reason,
          warehouse_id: warehouseId,
        },
        ip: req.ip,
      });

      await checkStockAlerts(before[0], warehouseId);
      await broadcastStatus();

      const { rows: result } = await pool.query(
        `
      SELECT p.*, COALESCE(ws.stock_qty, 0) as stock_qty
      FROM products p
      LEFT JOIN warehouse_stock ws ON ws.product_id=p.id AND ws.warehouse_id=$1
      WHERE p.id=$2
    `,
        [warehouseId, id],
      );
      return result[0];
    },
  );

  // DELETE /api/products/:id
  fastify.delete(
    "/api/products/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const { id } = req.params;
      const { rows } = await pool.query(
        "UPDATE products SET is_active=false, updated_at=NOW() WHERE id=$1 RETURNING *",
        [id],
      );
      if (!rows[0]) return reply.code(404).send({ error: "Product not found" });

      await logAudit({
        action: "product_delete",
        actor: req.user,
        target: { type: "product", id: rows[0].id, name: rows[0].name },
        ip: req.ip,
      });

      return { success: true };
    },
  );
}
