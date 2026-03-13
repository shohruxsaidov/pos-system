INSERT INTO settings (key, value) VALUES
  ('printer_interface',   'tcp'),
  ('printer_ip',          '192.168.1.100'),
  ('printer_port',        '9100'),
  ('printer_serial_path', 'COM3'),
  ('printer_serial_baud', '9600')
ON CONFLICT (key) DO NOTHING;
