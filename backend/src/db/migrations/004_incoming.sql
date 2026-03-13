CREATE TABLE IF NOT EXISTS incoming_receipts (
  id SERIAL PRIMARY KEY,
  ref_no TEXT UNIQUE NOT NULL,
  received_by INTEGER REFERENCES users(id),
  supplier TEXT,
  notes TEXT,
  total_cost NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incoming_receipts_created ON incoming_receipts(created_at DESC);

CREATE TABLE IF NOT EXISTS incoming_items (
  id SERIAL PRIMARY KEY,
  receipt_id INTEGER NOT NULL REFERENCES incoming_receipts(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id),
  product_name TEXT NOT NULL,
  qty_received NUMERIC(10,3) NOT NULL,
  cost_per_unit NUMERIC(10,2) NOT NULL DEFAULT 0,
  expiry_date DATE,
  subtotal NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_incoming_items_receipt ON incoming_items(receipt_id);
