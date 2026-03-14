-- ════════════════════════════════════════════════════════════════
-- Full schema — compacted from all prior migrations
-- ════════════════════════════════════════════════════════════════

-- Extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── Categories ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id        SERIAL PRIMARY KEY,
  name      TEXT NOT NULL,
  parent_id INTEGER REFERENCES categories(id),
  color     TEXT DEFAULT '#7b68ee',
  icon      TEXT DEFAULT 'pi pi-tag'
);

-- ── Warehouses ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouses (
  id         SERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Products (no stock_qty — stock lives in warehouse_stock) ─────
CREATE TABLE IF NOT EXISTS products (
  id                  SERIAL PRIMARY KEY,
  barcode             TEXT UNIQUE,
  name                TEXT NOT NULL,
  category_id         INTEGER REFERENCES categories(id),
  price               NUMERIC(10,2) NOT NULL DEFAULT 0,
  cost                NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit                TEXT NOT NULL DEFAULT 'pcs',
  image_url           TEXT,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  low_stock_threshold INTEGER DEFAULT 5,
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ── Users ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  pin_hash     TEXT NOT NULL,
  role         TEXT NOT NULL DEFAULT 'cashier'
                 CHECK (role IN ('cashier','manager','admin','warehouse')),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  warehouse_id INTEGER REFERENCES warehouses(id)
);

-- ── Customers ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id             SERIAL PRIMARY KEY,
  name           TEXT NOT NULL,
  phone          TEXT,
  email          TEXT,
  loyalty_points INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── Warehouse Stock ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_stock (
  id           SERIAL PRIMARY KEY,
  warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
  product_id   INTEGER NOT NULL REFERENCES products(id),
  stock_qty    NUMERIC(12,3) NOT NULL DEFAULT 0,
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(warehouse_id, product_id)
);

-- ── Refunds (created before transactions — transactions.refund_id refs refunds) ─
CREATE TABLE IF NOT EXISTS refunds (
  id                  SERIAL PRIMARY KEY,
  ref_no              TEXT UNIQUE NOT NULL,
  original_txn_id     INTEGER NOT NULL,        -- no FK: transactions is partitioned
  processed_by        INTEGER REFERENCES users(id),
  approved_by         INTEGER REFERENCES users(id),
  refund_type         TEXT NOT NULL DEFAULT 'partial'
                        CHECK (refund_type IN ('full','partial')),
  reason              TEXT NOT NULL,
  total_refund_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method      TEXT NOT NULL DEFAULT 'cash',
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refund_items (
  id           SERIAL PRIMARY KEY,
  refund_id    INTEGER NOT NULL REFERENCES refunds(id) ON DELETE CASCADE,
  product_id   INTEGER REFERENCES products(id),
  product_name TEXT NOT NULL,
  qty_returned NUMERIC(10,3) NOT NULL,
  unit_price   NUMERIC(10,2) NOT NULL,
  subtotal     NUMERIC(10,2) NOT NULL
);

-- ── Transactions (partitioned by created_at) ─────────────────────
CREATE TABLE IF NOT EXISTS transactions (
  id             INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
  ref_no         TEXT NOT NULL,
  customer_id    INTEGER REFERENCES customers(id),
  cashier_id     INTEGER REFERENCES users(id),
  warehouse_id   INTEGER REFERENCES warehouses(id),
  subtotal       NUMERIC(10,2) NOT NULL DEFAULT 0,
  discount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  tax            NUMERIC(10,2) NOT NULL DEFAULT 0,
  total          NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  status         TEXT NOT NULL DEFAULT 'completed'
                   CHECK (status IN ('completed','refunded','partially_refunded','voided')),
  refund_id      INTEGER REFERENCES refunds(id),
  synced         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- ── Transaction Items (partitioned) ──────────────────────────────
CREATE TABLE IF NOT EXISTS transaction_items (
  id             INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
  transaction_id INTEGER NOT NULL,             -- no FK: transactions is partitioned
  product_id     INTEGER REFERENCES products(id),
  qty            NUMERIC(10,3) NOT NULL,
  unit_price     NUMERIC(10,2) NOT NULL,
  discount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(10,2) NOT NULL,
  cost_at_sale   NUMERIC(12,2),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- ── Payments ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id             SERIAL PRIMARY KEY,
  transaction_id INTEGER NOT NULL,             -- no FK: transactions is partitioned
  method         TEXT NOT NULL,
  amount         NUMERIC(10,2) NOT NULL,
  change_given   NUMERIC(10,2) NOT NULL DEFAULT 0,
  reference      TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── Sync Log (partitioned) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_log (
  id         INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
  table_name TEXT NOT NULL,
  record_id  INTEGER NOT NULL,
  action     TEXT NOT NULL CHECK (action IN ('insert','update','delete')),
  synced_at  TIMESTAMPTZ,
  payload    JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- ── Audit Log (partitioned) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
  action      TEXT NOT NULL,
  actor_id    INTEGER,
  actor_name  TEXT,
  actor_role  TEXT,
  approver_id INTEGER,
  target_type TEXT,
  target_id   INTEGER,
  target_name TEXT,
  details     JSONB,
  ip_address  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- ── Monthly partitions 2025-01 → 2028-12 ─────────────────────────
DO $$
DECLARE y INT; m INT; fd DATE; td DATE;
BEGIN
  FOR y IN 2025..2028 LOOP
    FOR m IN 1..12 LOOP
      fd := make_date(y, m, 1);
      td := fd + INTERVAL '1 month';
      EXECUTE format('CREATE TABLE IF NOT EXISTS transactions_%s_%s PARTITION OF transactions FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text,2,'0'), fd, td);
      EXECUTE format('CREATE TABLE IF NOT EXISTS transaction_items_%s_%s PARTITION OF transaction_items FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text,2,'0'), fd, td);
      EXECUTE format('CREATE TABLE IF NOT EXISTS audit_log_%s_%s PARTITION OF audit_log FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text,2,'0'), fd, td);
      EXECUTE format('CREATE TABLE IF NOT EXISTS sync_log_%s_%s PARTITION OF sync_log FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text,2,'0'), fd, td);
    END LOOP;
  END LOOP;
END $$;

-- Default partitions (catch-all for out-of-range rows)
CREATE TABLE IF NOT EXISTS transactions_default      PARTITION OF transactions      DEFAULT;
CREATE TABLE IF NOT EXISTS transaction_items_default PARTITION OF transaction_items DEFAULT;
CREATE TABLE IF NOT EXISTS audit_log_default         PARTITION OF audit_log         DEFAULT;
CREATE TABLE IF NOT EXISTS sync_log_default          PARTITION OF sync_log          DEFAULT;

-- ── Settings ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
);

INSERT INTO settings (key, value) VALUES
  ('store_name',         'Main Market Store'),
  ('low_stock_threshold','5'),
  ('telegram_enabled',   'false'),
  ('eod_time',           '23:00'),
  ('telegram_bot_token', ''),
  ('telegram_chat_id',   ''),
  ('telegram_owner_ids', '[]'),
  ('receipt_footer',     'Thank you for shopping!'),
  ('tax_rate',           '0'),
  ('currency_symbol',    ''),
  ('printer_type',       'usb'),
  ('ai_summary_enabled', 'false'),
  ('gemini_api_key',     '')
ON CONFLICT (key) DO NOTHING;

-- ── Incoming Receipts ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS incoming_receipts (
  id           SERIAL PRIMARY KEY,
  ref_no       TEXT UNIQUE NOT NULL,
  received_by  INTEGER REFERENCES users(id),
  warehouse_id INTEGER REFERENCES warehouses(id),
  supplier     TEXT,
  notes        TEXT,
  total_cost   NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incoming_items (
  id            SERIAL PRIMARY KEY,
  receipt_id    INTEGER NOT NULL REFERENCES incoming_receipts(id) ON DELETE CASCADE,
  product_id    INTEGER REFERENCES products(id),
  product_name  TEXT NOT NULL,
  qty_received  NUMERIC(10,3) NOT NULL,
  cost_per_unit NUMERIC(10,2) NOT NULL DEFAULT 0,
  expiry_date   DATE,
  subtotal      NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit          TEXT NOT NULL DEFAULT 'шт'
);

-- ── Stock Adjustments ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id           SERIAL PRIMARY KEY,
  product_id   INTEGER NOT NULL REFERENCES products(id),
  adjusted_by  INTEGER REFERENCES users(id),
  warehouse_id INTEGER REFERENCES warehouses(id),
  delta        NUMERIC(12,3) NOT NULL,
  reason       TEXT NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── Z Reports ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS z_reports (
  id                SERIAL PRIMARY KEY,
  report_no         TEXT UNIQUE NOT NULL,
  warehouse_id      INTEGER,
  opened_at         TIMESTAMPTZ NOT NULL,
  closed_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_by         INTEGER REFERENCES users(id),
  closed_by_name    TEXT NOT NULL,
  transaction_count INTEGER NOT NULL DEFAULT 0,
  gross_sales       NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_discount    NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_tax         NUMERIC(12,2) NOT NULL DEFAULT 0,
  net_sales         NUMERIC(12,2) NOT NULL DEFAULT 0,
  refund_count      INTEGER NOT NULL DEFAULT 0,
  refund_amount     NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_methods   JSONB NOT NULL DEFAULT '[]',
  cashier_summary   JSONB NOT NULL DEFAULT '[]',
  top_products      JSONB NOT NULL DEFAULT '[]',
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ── Seed Data ────────────────────────────────────────────────────
INSERT INTO warehouses (id, name) VALUES (1, 'Main Warehouse')
ON CONFLICT (id) DO NOTHING;

INSERT INTO categories (name, color, icon) VALUES
  ('Grocery',       '#00d4aa', 'pi pi-shopping-cart'),
  ('Beverages',     '#7b68ee', 'pi pi-glass-filled'),
  ('Snacks',        '#ffb02e', 'pi pi-star'),
  ('Personal Care', '#9d4edd', 'pi pi-heart'),
  ('Household',     '#ff5c5c', 'pi pi-home')
ON CONFLICT DO NOTHING;

-- ── Indexes ──────────────────────────────────────────────────────

-- products
CREATE INDEX IF NOT EXISTS idx_products_barcode     ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_category    ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active      ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_active_name ON products(is_active, name);
CREATE INDEX IF NOT EXISTS idx_products_name_trgm   ON products USING GIN (name gin_trgm_ops);

-- customers
CREATE INDEX IF NOT EXISTS idx_customers_phone      ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm  ON customers USING GIN (name gin_trgm_ops);

-- payments
CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id);

-- stock_adjustments
CREATE INDEX IF NOT EXISTS idx_stock_adj_product    ON stock_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_adj_created    ON stock_adjustments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_adj_warehouse  ON stock_adjustments(warehouse_id);

-- refunds
CREATE INDEX IF NOT EXISTS idx_refunds_txn          ON refunds(original_txn_id);
CREATE INDEX IF NOT EXISTS idx_refunds_created      ON refunds(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refund_items_refund  ON refund_items(refund_id);
CREATE INDEX IF NOT EXISTS idx_refund_items_product ON refund_items(product_id);

-- incoming
CREATE INDEX IF NOT EXISTS idx_incoming_receipts_warehouse ON incoming_receipts(warehouse_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incoming_items_receipt      ON incoming_items(receipt_id);

-- z_reports
CREATE INDEX IF NOT EXISTS idx_z_reports_warehouse  ON z_reports(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_z_reports_closed_at  ON z_reports(closed_at DESC);

-- transactions (indexes on partitioned parent propagate to all partitions)
CREATE INDEX IF NOT EXISTS idx_transactions_created           ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_cashier           ON transactions(cashier_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status            ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_customer          ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_warehouse         ON transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_transactions_warehouse_created ON transactions(warehouse_id, created_at DESC);

-- transaction_items
CREATE INDEX IF NOT EXISTS idx_txn_items_txn     ON transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_txn_items_product ON transaction_items(product_id);

-- audit_log
CREATE INDEX IF NOT EXISTS idx_audit_action  ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_actor   ON audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_target  ON audit_log(target_type, target_id);

-- sync_log
CREATE INDEX IF NOT EXISTS idx_sync_log_synced ON sync_log(synced_at NULLS FIRST);
CREATE INDEX IF NOT EXISTS idx_sync_log_table  ON sync_log(table_name);
