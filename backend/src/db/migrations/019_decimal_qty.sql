-- Allow fractional quantities (e.g. 0.143 kg)
ALTER TABLE warehouse_stock ALTER COLUMN stock_qty TYPE NUMERIC(12,3);
ALTER TABLE stock_adjustments ALTER COLUMN delta TYPE NUMERIC(12,3);
