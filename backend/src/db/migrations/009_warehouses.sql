-- 1. Create warehouses table
CREATE TABLE IF NOT EXISTS warehouses (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default warehouse
INSERT INTO warehouses (id, name) VALUES (1, 'Main Warehouse')
ON CONFLICT (id) DO NOTHING;

-- 2. Create warehouse_stock table (replaces products.stock_qty)
CREATE TABLE IF NOT EXISTS warehouse_stock (
  id SERIAL PRIMARY KEY,
  warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
  product_id INTEGER NOT NULL REFERENCES products(id),
  stock_qty INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(warehouse_id, product_id)
);

-- Migrate existing global stock to warehouse 1
INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty)
SELECT 1, id, COALESCE(stock_qty, 0) FROM products
ON CONFLICT (warehouse_id, product_id) DO NOTHING;

-- 3. Add warehouse_id to users (nullable — admin has no warehouse)
ALTER TABLE users ADD COLUMN IF NOT EXISTS warehouse_id INTEGER REFERENCES warehouses(id);
UPDATE users SET warehouse_id = 1 WHERE role IN ('cashier', 'warehouse', 'manager') AND warehouse_id IS NULL;

-- 4. Add warehouse_id to transactions
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS warehouse_id INTEGER REFERENCES warehouses(id);
UPDATE transactions SET warehouse_id = 1 WHERE warehouse_id IS NULL;

-- 5. Add warehouse_id to incoming_receipts
ALTER TABLE incoming_receipts ADD COLUMN IF NOT EXISTS warehouse_id INTEGER REFERENCES warehouses(id);
UPDATE incoming_receipts SET warehouse_id = 1 WHERE warehouse_id IS NULL;

-- 6. Add warehouse_id to stock_adjustments
ALTER TABLE stock_adjustments ADD COLUMN IF NOT EXISTS warehouse_id INTEGER REFERENCES warehouses(id);
UPDATE stock_adjustments SET warehouse_id = 1 WHERE warehouse_id IS NULL;

-- 7. Drop the now-redundant global stock column
ALTER TABLE products DROP COLUMN IF EXISTS stock_qty;
