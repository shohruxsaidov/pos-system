-- Migration 020: Partition transactions, transaction_items, audit_log, sync_log
-- by RANGE on created_at (monthly buckets)

-- ── Guard ────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'transactions' AND n.nspname = 'public' AND c.relkind = 'p'
  ) THEN
    RAISE NOTICE '020: already applied, skipping';
    RETURN;
  END IF;
END $$;

-- ── Phase 1: Add & backfill created_at on transaction_items ──────────────────
ALTER TABLE transaction_items ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;

UPDATE transaction_items ti
SET created_at = t.created_at
FROM transactions t
WHERE ti.transaction_id = t.id AND ti.created_at IS NULL;

ALTER TABLE transaction_items ALTER COLUMN created_at SET DEFAULT NOW();
ALTER TABLE transaction_items ALTER COLUMN created_at SET NOT NULL;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM transaction_items WHERE created_at IS NULL) THEN
    RAISE EXCEPTION '020: orphaned transaction_items rows have NULL created_at';
  END IF;
END $$;

-- ── Phase 2: Drop FKs pointing INTO transactions ──────────────────────────────
DO $$
DECLARE r RECORD; tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['transaction_items', 'payments', 'refunds'] LOOP
    FOR r IN
      SELECT conname FROM pg_constraint
      WHERE conrelid = tbl::regclass
        AND contype = 'f'
        AND confrelid = 'transactions'::regclass
    LOOP
      EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', tbl, r.conname);
    END LOOP;
  END LOOP;
END $$;

-- ── Phase 3: Rename existing tables to _old ──────────────────────────────────
ALTER TABLE transactions      RENAME TO transactions_old;
ALTER TABLE transaction_items RENAME TO transaction_items_old;
ALTER TABLE audit_log         RENAME TO audit_log_old;
ALTER TABLE sync_log          RENAME TO sync_log_old;

-- ── Phase 4: Create partitioned parent tables ─────────────────────────────────
CREATE TABLE transactions (
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

CREATE TABLE transaction_items (
  id             INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
  transaction_id INTEGER NOT NULL,
  product_id     INTEGER REFERENCES products(id),
  qty            NUMERIC(10,3) NOT NULL,
  unit_price     NUMERIC(10,2) NOT NULL,
  discount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  subtotal       NUMERIC(10,2) NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE audit_log (
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

CREATE TABLE sync_log (
  id         INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
  table_name TEXT NOT NULL,
  record_id  INTEGER NOT NULL,
  action     TEXT NOT NULL CHECK (action IN ('insert','update','delete')),
  synced_at  TIMESTAMPTZ,
  payload    JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- ── Phase 5: Default partitions (safety net for out-of-range rows) ────────────
CREATE TABLE transactions_default      PARTITION OF transactions      DEFAULT;
CREATE TABLE transaction_items_default PARTITION OF transaction_items DEFAULT;
CREATE TABLE audit_log_default         PARTITION OF audit_log         DEFAULT;
CREATE TABLE sync_log_default          PARTITION OF sync_log          DEFAULT;

-- ── Phase 6: Monthly partitions 2025-01 → 2027-12 ────────────────────────────
DO $$
DECLARE y INT; m INT; fd DATE; td DATE;
BEGIN
  FOR y IN 2025..2027 LOOP
    FOR m IN 1..12 LOOP
      fd := make_date(y, m, 1);
      td := fd + INTERVAL '1 month';
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS transactions_%s_%s PARTITION OF transactions FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text, 2, '0'), fd, td
      );
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS transaction_items_%s_%s PARTITION OF transaction_items FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text, 2, '0'), fd, td
      );
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS audit_log_%s_%s PARTITION OF audit_log FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text, 2, '0'), fd, td
      );
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS sync_log_%s_%s PARTITION OF sync_log FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text, 2, '0'), fd, td
      );
    END LOOP;
  END LOOP;
END $$;

-- ── Phase 7: Copy data (preserve IDs with OVERRIDING SYSTEM VALUE) ────────────
INSERT INTO transactions OVERRIDING SYSTEM VALUE
  SELECT id, ref_no, customer_id, cashier_id, warehouse_id,
         subtotal, discount, tax, total, payment_method,
         status, refund_id, synced, created_at
  FROM transactions_old;

INSERT INTO transaction_items OVERRIDING SYSTEM VALUE
  SELECT id, transaction_id, product_id, qty, unit_price, discount, subtotal, created_at
  FROM transaction_items_old;

INSERT INTO audit_log OVERRIDING SYSTEM VALUE
  SELECT id, action, actor_id, actor_name, actor_role, approver_id,
         target_type, target_id, target_name, details, ip_address, created_at
  FROM audit_log_old;

INSERT INTO sync_log OVERRIDING SYSTEM VALUE
  SELECT id, table_name, record_id, action, synced_at, payload, created_at
  FROM sync_log_old;

-- ── Phase 8: Row count verification ──────────────────────────────────────────
DO $$
DECLARE oc BIGINT; nc BIGINT; tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['transactions', 'transaction_items', 'audit_log', 'sync_log'] LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I_old', tbl) INTO oc;
    EXECUTE format('SELECT COUNT(*) FROM %I',     tbl) INTO nc;
    IF oc != nc THEN
      RAISE EXCEPTION '020: % count mismatch — old=%, new=%', tbl, oc, nc;
    END IF;
  END LOOP;
END $$;

-- ── Phase 9: Recreate indexes on parent tables ────────────────────────────────
-- transactions
CREATE INDEX if not exists idx_transactions_created           ON transactions (created_at DESC);
CREATE INDEX if not exists idx_transactions_cashier           ON transactions (cashier_id);
CREATE INDEX if not exists idx_transactions_status            ON transactions (status);
CREATE INDEX if not exists idx_transactions_customer          ON transactions (customer_id);
CREATE INDEX if not exists idx_transactions_warehouse         ON transactions (warehouse_id);
CREATE INDEX if not exists idx_transactions_warehouse_created ON transactions (warehouse_id, created_at DESC);

-- transaction_items
CREATE INDEX if not exists idx_txn_items_txn     ON transaction_items (transaction_id);
CREATE INDEX if not exists idx_txn_items_product ON transaction_items (product_id);

-- audit_log
CREATE INDEX if not exists idx_audit_action  ON audit_log (action);
CREATE INDEX if not exists idx_audit_actor   ON audit_log (actor_id);
CREATE INDEX if not exists idx_audit_created ON audit_log (created_at DESC);
CREATE INDEX if not exists idx_audit_target  ON audit_log (target_type, target_id);

-- sync_log
CREATE INDEX if not exists idx_sync_synced ON sync_log (synced_at NULLS FIRST);
CREATE INDEX if not exists idx_sync_table  ON sync_log (table_name);

-- ── Phase 10: Reset identity sequences past max existing ID ───────────────────
DO $$
DECLARE max_id BIGINT; tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['transactions', 'transaction_items', 'audit_log', 'sync_log'] LOOP
    EXECUTE format('SELECT COALESCE(MAX(id), 0) FROM %I', tbl) INTO max_id;
    IF max_id > 0 THEN
      EXECUTE format('ALTER TABLE %I ALTER COLUMN id RESTART WITH %s', tbl, max_id + 1);
    END IF;
  END LOOP;
END $$;

-- ── Phase 11: Drop old tables ─────────────────────────────────────────────────
DROP TABLE transactions_old;
DROP TABLE transaction_items_old;
DROP TABLE audit_log_old;
DROP TABLE sync_log_old;
