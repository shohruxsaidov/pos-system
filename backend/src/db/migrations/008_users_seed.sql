-- Default users are seeded by the application on first run via migrate.js
-- This file is intentionally left as a placeholder.
-- The application will create default users if none exist.
-- Default admin PIN: 1234, Manager PIN: 5678, Cashier PIN: 1234

-- Default categories
INSERT INTO categories (name, color, icon) VALUES
  ('Grocery', '#00d4aa', 'pi pi-shopping-cart'),
  ('Beverages', '#7b68ee', 'pi pi-glass-filled'),
  ('Snacks', '#ffb02e', 'pi pi-star'),
  ('Personal Care', '#9d4edd', 'pi pi-heart'),
  ('Household', '#ff5c5c', 'pi pi-home')
ON CONFLICT DO NOTHING;
