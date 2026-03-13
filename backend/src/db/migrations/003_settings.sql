CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
);

INSERT INTO settings (key, value) VALUES
  ('store_name', 'Main Market Store'),
  ('low_stock_threshold', '5'),
  ('telegram_enabled', 'false'),
  ('eod_time', '23:00'),
  ('telegram_bot_token', ''),
  ('telegram_chat_id', ''),
  ('telegram_owner_ids', '[]'),
  ('receipt_footer', 'Thank you for shopping!'),
  ('tax_rate', '0'),
  ('currency_symbol', '')
ON CONFLICT (key) DO NOTHING;
