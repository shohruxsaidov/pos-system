INSERT INTO settings (key, value) VALUES
  ('ai_summary_enabled', 'false'),
  ('anthropic_api_key', '')
ON CONFLICT (key) DO NOTHING;
