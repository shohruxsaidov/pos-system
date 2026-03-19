INSERT INTO settings (key, value) VALUES
  ('printer_address', ''),
  ('printer_paper_width', '58mm')
ON CONFLICT (key) DO NOTHING;
