CREATE TABLE IF NOT EXISTS transactions (
  id               SERIAL PRIMARY KEY,
  ref_no           TEXT NOT NULL UNIQUE,
  cashier_id       INTEGER,
  cashier_name     TEXT,
  warehouse_id     INTEGER,
  customer_id      INTEGER,
  subtotal         NUMERIC(12,2) NOT NULL,
  discount         NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax              NUMERIC(12,2) NOT NULL DEFAULT 0,
  total            NUMERIC(12,2) NOT NULL,
  payment_method   TEXT,
  status           TEXT NOT NULL DEFAULT 'completed',
  created_at       TIMESTAMPTZ NOT NULL,
  received_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_txn_created_at ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_txn_cashier    ON transactions(cashier_id);
CREATE INDEX IF NOT EXISTS idx_txn_status     ON transactions(status);

CREATE TABLE IF NOT EXISTS transaction_items (
  id               SERIAL PRIMARY KEY,
  transaction_id   INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  product_id       INTEGER,
  product_name     TEXT,
  qty              NUMERIC(12,3) NOT NULL,
  unit_price       NUMERIC(12,2) NOT NULL,
  discount         NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal         NUMERIC(12,2) NOT NULL,
  cost_at_sale     NUMERIC(12,2)
);

CREATE INDEX IF NOT EXISTS idx_items_txn ON transaction_items(transaction_id);

CREATE TABLE IF NOT EXISTS payments (
  id               SERIAL PRIMARY KEY,
  transaction_id   INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  method           TEXT NOT NULL,
  amount           NUMERIC(12,2) NOT NULL,
  change_given     NUMERIC(12,2) NOT NULL DEFAULT 0,
  reference        TEXT
);
