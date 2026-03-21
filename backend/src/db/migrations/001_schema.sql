-- ════════════════════════════════════════════════════════════════
-- Full schema — SQLite version
-- ════════════════════════════════════════════════════════════════

-- ── Categories ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      TEXT NOT NULL,
  parent_id INTEGER REFERENCES categories(id),
  color     TEXT DEFAULT '#7b68ee',
  icon      TEXT DEFAULT 'pi pi-tag'
);

-- ── Warehouses ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouses (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  is_active  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT DEFAULT (datetime('now'))
);

-- ── Products ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  barcode             TEXT UNIQUE,
  name                TEXT NOT NULL,
  category_id         INTEGER REFERENCES categories(id),
  price               REAL NOT NULL DEFAULT 0,
  cost                REAL NOT NULL DEFAULT 0,
  unit                TEXT NOT NULL DEFAULT 'pcs',
  image_url           TEXT,
  is_active           INTEGER NOT NULL DEFAULT 1,
  low_stock_threshold INTEGER DEFAULT 5,
  updated_at          TEXT DEFAULT (datetime('now'))
);

-- ── Users ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL,
  pin_hash     TEXT NOT NULL,
  role         TEXT NOT NULL DEFAULT 'cashier'
                 CHECK (role IN ('cashier','manager','admin','warehouse')),
  is_active    INTEGER NOT NULL DEFAULT 1,
  warehouse_id INTEGER REFERENCES warehouses(id)
);

-- ── Customers ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  name           TEXT NOT NULL,
  phone          TEXT,
  email          TEXT,
  loyalty_points INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT DEFAULT (datetime('now'))
);

-- ── Warehouse Stock ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_stock (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
  product_id   INTEGER NOT NULL REFERENCES products(id),
  stock_qty    REAL NOT NULL DEFAULT 0,
  updated_at   TEXT DEFAULT (datetime('now')),
  UNIQUE(warehouse_id, product_id)
);

-- ── Refunds ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS refunds (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  ref_no              TEXT UNIQUE NOT NULL,
  original_txn_id     INTEGER NOT NULL,
  processed_by        INTEGER REFERENCES users(id),
  approved_by         INTEGER REFERENCES users(id),
  refund_type         TEXT NOT NULL DEFAULT 'partial'
                        CHECK (refund_type IN ('full','partial')),
  reason              TEXT NOT NULL,
  total_refund_amount REAL NOT NULL DEFAULT 0,
  payment_method      TEXT NOT NULL DEFAULT 'cash',
  created_at          TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS refund_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  refund_id    INTEGER NOT NULL REFERENCES refunds(id) ON DELETE CASCADE,
  product_id   INTEGER REFERENCES products(id),
  product_name TEXT NOT NULL,
  qty_returned REAL NOT NULL,
  unit_price   REAL NOT NULL,
  subtotal     REAL NOT NULL
);

-- ── Transactions ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transactions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  ref_no         TEXT NOT NULL,
  customer_id    INTEGER REFERENCES customers(id),
  cashier_id     INTEGER REFERENCES users(id),
  warehouse_id   INTEGER REFERENCES warehouses(id),
  subtotal       REAL NOT NULL DEFAULT 0,
  discount       REAL NOT NULL DEFAULT 0,
  tax            REAL NOT NULL DEFAULT 0,
  total          REAL NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  status         TEXT NOT NULL DEFAULT 'completed'
                   CHECK (status IN ('completed','refunded','partially_refunded','voided')),
  refund_id      INTEGER REFERENCES refunds(id),
  client_ref     TEXT,
  synced         INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── Transaction Items ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transaction_items (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL REFERENCES transactions(id),
  product_id     INTEGER REFERENCES products(id),
  qty            REAL NOT NULL,
  unit_price     REAL NOT NULL,
  discount       REAL NOT NULL DEFAULT 0,
  subtotal       REAL NOT NULL,
  cost_at_sale   REAL,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── Payments ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL REFERENCES transactions(id),
  method         TEXT NOT NULL,
  amount         REAL NOT NULL,
  change_given   REAL NOT NULL DEFAULT 0,
  reference      TEXT,
  created_at     TEXT DEFAULT (datetime('now'))
);

-- ── Sync Log ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id  INTEGER NOT NULL,
  action     TEXT NOT NULL CHECK (action IN ('insert','update','delete')),
  synced_at  TEXT,
  payload    TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── Audit Log ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  action      TEXT NOT NULL,
  actor_id    INTEGER,
  actor_name  TEXT,
  actor_role  TEXT,
  approver_id INTEGER,
  target_type TEXT,
  target_id   INTEGER,
  target_name TEXT,
  details     TEXT,
  ip_address  TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

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
ON CONFLICT DO NOTHING;

-- ── Incoming Receipts ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS incoming_receipts (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  ref_no       TEXT UNIQUE NOT NULL,
  received_by  INTEGER REFERENCES users(id),
  warehouse_id INTEGER REFERENCES warehouses(id),
  supplier     TEXT,
  notes        TEXT,
  total_cost   REAL NOT NULL DEFAULT 0,
  created_at   TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS incoming_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id    INTEGER NOT NULL REFERENCES incoming_receipts(id) ON DELETE CASCADE,
  product_id    INTEGER REFERENCES products(id),
  product_name  TEXT NOT NULL,
  qty_received  REAL NOT NULL,
  cost_per_unit REAL NOT NULL DEFAULT 0,
  expiry_date   TEXT,
  subtotal      REAL NOT NULL DEFAULT 0,
  unit          TEXT NOT NULL DEFAULT 'pcs'
);

-- ── Stock Adjustments ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id   INTEGER NOT NULL REFERENCES products(id),
  adjusted_by  INTEGER REFERENCES users(id),
  warehouse_id INTEGER REFERENCES warehouses(id),
  delta        REAL NOT NULL,
  reason       TEXT NOT NULL,
  created_at   TEXT DEFAULT (datetime('now'))
);

-- ── Z Reports ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS z_reports (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  report_no         TEXT UNIQUE NOT NULL,
  warehouse_id      INTEGER,
  opened_at         TEXT NOT NULL,
  closed_at         TEXT NOT NULL DEFAULT (datetime('now')),
  closed_by         INTEGER REFERENCES users(id),
  closed_by_name    TEXT NOT NULL,
  transaction_count INTEGER NOT NULL DEFAULT 0,
  gross_sales       REAL NOT NULL DEFAULT 0,
  total_discount    REAL NOT NULL DEFAULT 0,
  total_tax         REAL NOT NULL DEFAULT 0,
  net_sales         REAL NOT NULL DEFAULT 0,
  refund_count      INTEGER NOT NULL DEFAULT 0,
  refund_amount     REAL NOT NULL DEFAULT 0,
  payment_methods   TEXT NOT NULL DEFAULT '[]',
  cashier_summary   TEXT NOT NULL DEFAULT '[]',
  top_products      TEXT NOT NULL DEFAULT '[]',
  created_at        TEXT DEFAULT (datetime('now'))
);

-- ── Seed Data ────────────────────────────────────────────────────
INSERT INTO warehouses (id, name) VALUES (1, 'Main Warehouse')
ON CONFLICT DO NOTHING;

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

-- customers
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_name  ON customers(name);

-- payments
CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id);

-- stock_adjustments
CREATE INDEX IF NOT EXISTS idx_stock_adj_product   ON stock_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_adj_created   ON stock_adjustments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_adj_warehouse ON stock_adjustments(warehouse_id);

-- refunds
CREATE INDEX IF NOT EXISTS idx_refunds_txn          ON refunds(original_txn_id);
CREATE INDEX IF NOT EXISTS idx_refunds_created      ON refunds(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refund_items_refund  ON refund_items(refund_id);
CREATE INDEX IF NOT EXISTS idx_refund_items_product ON refund_items(product_id);

-- incoming
CREATE INDEX IF NOT EXISTS idx_incoming_receipts_warehouse ON incoming_receipts(warehouse_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incoming_items_receipt      ON incoming_items(receipt_id);

-- z_reports
CREATE INDEX IF NOT EXISTS idx_z_reports_warehouse ON z_reports(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_z_reports_closed_at ON z_reports(closed_at DESC);

-- transactions
CREATE INDEX IF NOT EXISTS idx_transactions_created           ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_cashier           ON transactions(cashier_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status            ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_customer          ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_warehouse         ON transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_transactions_warehouse_created ON transactions(warehouse_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_client_ref        ON transactions(client_ref) WHERE client_ref IS NOT NULL;

-- transaction_items
CREATE INDEX IF NOT EXISTS idx_txn_items_txn     ON transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_txn_items_product ON transaction_items(product_id);

-- audit_log
CREATE INDEX IF NOT EXISTS idx_audit_action  ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_actor   ON audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_target  ON audit_log(target_type, target_id);

-- sync_log
CREATE INDEX IF NOT EXISTS idx_sync_log_synced ON sync_log(synced_at);
CREATE INDEX IF NOT EXISTS idx_sync_log_table  ON sync_log(table_name);
