-- Sync log for cloud sync
CREATE TABLE IF NOT EXISTS sync_log (
  id SERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id INTEGER NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('insert','update','delete')),
  synced_at TIMESTAMPTZ,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_log_synced ON sync_log(synced_at NULLS FIRST);
CREATE INDEX IF NOT EXISTS idx_sync_log_table ON sync_log(table_name);
