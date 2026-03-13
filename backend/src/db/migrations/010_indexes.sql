-- Migration 010: Missing indexes
-- Covers gaps found after query analysis across all routes

-- Trigram extension for efficient ILIKE searches
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- products: composite for main list (WHERE is_active=true ORDER BY name)
CREATE INDEX IF NOT EXISTS idx_products_active_name
  ON products(is_active, name);

-- products: GIN trigram for name ILIKE search
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON products USING GIN (name gin_trgm_ops);

-- transactions: customer lookup (purchase history)
CREATE INDEX IF NOT EXISTS idx_transactions_customer
  ON transactions(customer_id);

-- transactions: warehouse filter (all report queries)
CREATE INDEX IF NOT EXISTS idx_transactions_warehouse
  ON transactions(warehouse_id);

-- transactions: composite for date-range reports per warehouse
-- (WHERE DATE(created_at) = $1 AND status != 'voided' AND warehouse_id = $wid)
CREATE INDEX IF NOT EXISTS idx_transactions_warehouse_created
  ON transactions(warehouse_id, created_at DESC);

-- payments: FK has no auto index in Postgres
CREATE INDEX IF NOT EXISTS idx_payments_transaction
  ON payments(transaction_id);

-- incoming_receipts: warehouse listing (WHERE warehouse_id=$1 ORDER BY created_at DESC)
CREATE INDEX IF NOT EXISTS idx_incoming_receipts_warehouse
  ON incoming_receipts(warehouse_id, created_at DESC);

-- stock_adjustments: warehouse_id added in 009 but never indexed
CREATE INDEX IF NOT EXISTS idx_stock_adj_warehouse
  ON stock_adjustments(warehouse_id);

-- refund_items: product_id FK has no index
CREATE INDEX IF NOT EXISTS idx_refund_items_product
  ON refund_items(product_id);

-- customers: phone search
CREATE INDEX IF NOT EXISTS idx_customers_phone
  ON customers(phone);

-- customers: GIN trigram for name/phone ILIKE search
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm
  ON customers USING GIN (name gin_trgm_ops);
