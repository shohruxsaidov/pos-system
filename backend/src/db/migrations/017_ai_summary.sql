INSERT INTO settings (key, value) VALUES
  ('ai_summary_enabled', 'false'),
  ('gemini_api_key', '')
ON CONFLICT (key) DO NOTHING;
