ALTER TABLE transactions ADD COLUMN IF NOT EXISTS client_ref TEXT;
CREATE INDEX IF NOT EXISTS idx_transactions_client_ref
  ON transactions (client_ref) WHERE client_ref IS NOT NULL;
