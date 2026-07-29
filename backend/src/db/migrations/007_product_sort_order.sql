-- Per-category display order for products.
-- sort_order = 0 means "not ordered" — those fall back to alphabetical, after the ordered ones.
-- Used by GET /api/products when a category_id filter is applied (POS category tabs).
ALTER TABLE products ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_products_category_sort ON products(category_id, sort_order);
