CREATE TABLE IF NOT EXISTS stock_adjustments (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id),
  adjusted_by INTEGER REFERENCES users(id),
  delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_adj_product ON stock_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_adj_created ON stock_adjustments(created_at DESC);
