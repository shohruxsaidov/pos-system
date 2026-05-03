import { readFile } from "fs/promises";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { db } from "./src/db/connection.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

const JSON_PATH = join(__dirname, "../products.json");
const WAREHOUSE_ID = 1;

const insertCategory = db.prepare(
  `INSERT OR IGNORE INTO categories (name) VALUES (?)`,
);
const findCategory = db.prepare(`SELECT id FROM categories WHERE name = ?`);
const insertProduct = db.prepare(`
  INSERT INTO products (name, price, cost, unit, is_active)
  VALUES (?, ?, ?, ?, 1)
  
  RETURNING id
`);
const insertBarcode = db.prepare(`
  INSERT OR IGNORE INTO product_barcodes (product_id, barcode, is_primary)
  VALUES (?, ?, ?)
`);
const upsertStock = db.prepare(`
  INSERT INTO warehouse_stock (product_id, warehouse_id, stock_qty)
  VALUES (?, ?, ?)
  ON CONFLICT(product_id, warehouse_id) DO UPDATE SET
    stock_qty  = excluded.stock_qty,
    updated_at = datetime('now')
`);

function getOrCreateCategory(name) {
  if (!name || !name.trim()) return null;
  const trimmed = name.trim();
  insertCategory.run(trimmed);
  return findCategory.get(trimmed).id;
}

const migrate = db.transaction((products) => {
  let inserted = 0,
    updated = 0,
    barcodes = 0,
    skipped = 0;

  for (const p of products) {
    if (!p.barcode || !p.name) {
      skipped++;
      continue;
    }

    const unit = p.unit?.trim() || "pcs";

    const rows = insertProduct.all(p.name, p.price ?? 0, p.cost ?? 0, unit);

    if (!rows.length) {
      skipped++;
      continue;
    }
    const productId = rows[0].id;

    // primary barcode
    const pb = insertBarcode.run(productId, p.barcode, 1);
    if (pb.changes) barcodes++;

    // extra barcodes
    for (const extra of p.extra_barcodes ?? []) {
      if (!extra) continue;
      const eb = insertBarcode.run(productId, extra, 0);
      if (eb.changes) barcodes++;
    }

    // stock (default warehouse)
    upsertStock.run(productId, WAREHOUSE_ID, 0);

    // ON CONFLICT returns the row with updated_at changed — detect insert vs update
    // by checking if the RETURNING id matches a freshly inserted row
    // (simpler: track via a flag from the SQL change info)
    inserted++;
  }

  return { inserted, barcodes, skipped };
});

async function main() {
  console.log("[migrate-products] Reading", JSON_PATH);
  const raw = await readFile(JSON_PATH, "utf8");
  const { products, total, skipped: jsonSkipped } = JSON.parse(raw);

  console.log(
    `[migrate-products] JSON: ${total} total, ${jsonSkipped} skipped by exporter`,
  );
  console.log(`[migrate-products] Migrating ${products.length} products...`);

  const { inserted, barcodes, skipped } = migrate(products);

  console.log(`[migrate-products] Done.`);
  console.log(`  Products upserted : ${inserted}`);
  console.log(`  Barcodes added    : ${barcodes}`);
  console.log(`  Skipped (no data) : ${skipped}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
