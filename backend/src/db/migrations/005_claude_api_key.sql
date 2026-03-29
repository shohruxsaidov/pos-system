-- Migrate AI provider from Gemini to Claude
UPDATE settings SET key = 'claude_api_key' WHERE key = 'gemini_api_key';
INSERT INTO settings (key, value)
SELECT 'claude_api_key', ''
WHERE NOT EXISTS (SELECT 1 FROM settings WHERE key = 'claude_api_key');
