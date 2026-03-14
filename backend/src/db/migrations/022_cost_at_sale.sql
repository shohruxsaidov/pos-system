-- Add cost_at_sale to transaction_items so gross profit uses historical cost,
-- not the current product cost (which changes with each incoming receipt).
ALTER TABLE transaction_items
  ADD COLUMN IF NOT EXISTS cost_at_sale NUMERIC(12,2);

-- Backfill existing rows with current product cost (best available approximation)
UPDATE transaction_items ti
SET cost_at_sale = p.cost
FROM products p
WHERE ti.product_id = p.id AND ti.cost_at_sale IS NULL;
