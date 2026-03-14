INSERT INTO settings (key, value) VALUES
  ('printer_type', 'usb')
ON CONFLICT (key) DO NOTHING;
