-- ── Product Barcodes (multiple per product) ──────────────────────
CREATE TABLE IF NOT EXISTS product_barcodes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  barcode    TEXT NOT NULL,
  is_primary INTEGER NOT NULL DEFAULT 0,
  UNIQUE(barcode)
);

CREATE INDEX IF NOT EXISTS idx_pb_barcode    ON product_barcodes(barcode);
CREATE INDEX IF NOT EXISTS idx_pb_product_id ON product_barcodes(product_id);

-- Migrate existing barcodes from products table
INSERT OR IGNORE INTO product_barcodes (product_id, barcode, is_primary)
SELECT id, barcode, 1 FROM products WHERE barcode IS NOT NULL AND barcode != '';
