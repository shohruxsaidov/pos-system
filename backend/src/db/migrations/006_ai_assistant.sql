-- AI assistant settings (POST /api/ai/chat)
-- ai_model:  Claude model id used by the assistant and the EOD summary tool loop.
-- ai_effort: low | medium | high | xhigh | max — thinking depth vs latency/cost.
INSERT INTO settings (key, value) VALUES
  ('ai_model',  'claude-opus-5'),
  ('ai_effort', 'low')
ON CONFLICT (key) DO NOTHING;
