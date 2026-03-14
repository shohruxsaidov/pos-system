-- Rename anthropic_api_key → gemini_api_key (if old key exists from migration 017)
UPDATE settings SET key = 'gemini_api_key' WHERE key = 'anthropic_api_key';
INSERT INTO settings (key, value) VALUES ('gemini_api_key', '') ON CONFLICT (key) DO NOTHING;
