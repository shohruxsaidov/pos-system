CREATE TABLE IF NOT EXISTS refunds (
  id SERIAL PRIMARY KEY,
  ref_no TEXT UNIQUE NOT NULL,
  original_txn_id INTEGER NOT NULL REFERENCES transactions(id),
  processed_by INTEGER REFERENCES users(id),
  approved_by INTEGER REFERENCES users(id),
  refund_type TEXT NOT NULL DEFAULT 'partial' CHECK (refund_type IN ('full','partial')),
  reason TEXT NOT NULL,
  total_refund_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refunds_txn ON refunds(original_txn_id);
CREATE INDEX IF NOT EXISTS idx_refunds_created ON refunds(created_at DESC);

CREATE TABLE IF NOT EXISTS refund_items (
  id SERIAL PRIMARY KEY,
  refund_id INTEGER NOT NULL REFERENCES refunds(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id),
  product_name TEXT NOT NULL,
  qty_returned NUMERIC(10,3) NOT NULL,
  unit_price NUMERIC(10,2) NOT NULL,
  subtotal NUMERIC(10,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_refund_items_refund ON refund_items(refund_id);

-- Add columns to transactions if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'transactions' AND column_name = 'refund_id'
  ) THEN
    ALTER TABLE transactions ADD COLUMN refund_id INTEGER REFERENCES refunds(id);
  END IF;
END $$;
