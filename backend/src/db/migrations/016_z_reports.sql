CREATE TABLE IF NOT EXISTS z_reports (
  id SERIAL PRIMARY KEY,
  report_no TEXT UNIQUE NOT NULL,
  warehouse_id INTEGER,
  opened_at TIMESTAMPTZ NOT NULL,
  closed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_by INTEGER REFERENCES users(id),
  closed_by_name TEXT NOT NULL,
  transaction_count INTEGER NOT NULL DEFAULT 0,
  gross_sales NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_discount NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_tax NUMERIC(12,2) NOT NULL DEFAULT 0,
  net_sales NUMERIC(12,2) NOT NULL DEFAULT 0,
  refund_count INTEGER NOT NULL DEFAULT 0,
  refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_methods JSONB NOT NULL DEFAULT '[]',
  cashier_summary JSONB NOT NULL DEFAULT '[]',
  top_products JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_z_reports_warehouse ON z_reports(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_z_reports_closed_at ON z_reports(closed_at DESC);
