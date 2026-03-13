-- Test Products Seed
-- Run: psql -U pos_user -d market_pos -f src/db/seeds/test_products.sql

-- Categories
INSERT INTO categories (id, name, parent_id, color, icon) VALUES
  (1,  'Groceries',       NULL, '#7b68ee', 'pi pi-shopping-bag'),
  (2,  'Grains & Rice',   1,    '#9d4edd', 'pi pi-tag'),
  (3,  'Oils & Fats',     1,    '#9d4edd', 'pi pi-tag'),
  (4,  'Canned Goods',    1,    '#9d4edd', 'pi pi-tag'),
  (5,  'Condiments',      1,    '#9d4edd', 'pi pi-tag'),
  (6,  'Beverages',       NULL, '#00d4aa', 'pi pi-inbox'),
  (7,  'Soft Drinks',     6,    '#00d4aa', 'pi pi-tag'),
  (8,  'Water & Juices',  6,    '#00d4aa', 'pi pi-tag'),
  (9,  'Personal Care',   NULL, '#ffb02e', 'pi pi-star'),
  (10, 'Soap & Shampoo',  9,    '#ffb02e', 'pi pi-tag'),
  (11, 'Snacks',          NULL, '#ff5c5c', 'pi pi-heart'),
  (12, 'Chips & Crackers',11,   '#ff5c5c', 'pi pi-tag'),
  (13, 'Dairy',           NULL, '#4e54c8', 'pi pi-box'),
  (14, 'Frozen Foods',    NULL, '#4e54c8', 'pi pi-box'),
  (15, 'Cleaning',        NULL, '#c77dff', 'pi pi-wrench')
ON CONFLICT (id) DO NOTHING;

-- Reset sequence
SELECT setval('categories_id_seq', (SELECT MAX(id) FROM categories));

-- Products (no stock_qty column — stock lives in warehouse_stock)
INSERT INTO products (barcode, name, category_id, price, cost, unit) VALUES
-- Grains & Rice
('8991234560001', 'Rice 5kg',              2,  450.00, 380.00, 'bag'),
('8991234560002', 'Rice 1kg',              2,   95.00,  78.00, 'bag'),
('8991234560003', 'Rice 25kg Sack',        2, 2100.00,1750.00, 'sack'),
('8991234560004', 'Glutinous Rice 1kg',    2,  110.00,  90.00, 'bag'),
('8991234560005', 'Corn Grits 1kg',        2,   55.00,  42.00, 'bag'),
('8991234560006', 'Oatmeal 800g',          2,   88.00,  68.00, 'pack'),
('8991234560007', 'Pancake Mix 500g',      2,   75.00,  58.00, 'pack'),

-- Oils & Fats
('8991234560010', 'Cooking Oil 1L',        3,   85.00,  68.00, 'btl'),
('8991234560011', 'Cooking Oil 2L',        3,  160.00, 130.00, 'btl'),
('8991234560012', 'Coconut Oil 500ml',     3,   72.00,  58.00, 'btl'),
('8991234560013', 'Margarine 225g',        3,   38.00,  28.00, 'pcs'),
('8991234560014', 'Butter 100g',           3,   55.00,  42.00, 'pcs'),

-- Canned Goods
('8991234560020', 'Tuna in Oil 155g',      4,   28.00,  20.00, 'can'),
('8991234560021', 'Sardines 155g',         4,   22.00,  15.00, 'can'),
('8991234560022', 'Corned Beef 175g',      4,   45.00,  34.00, 'can'),
('8991234560023', 'Liver Spread 165g',     4,   32.00,  24.00, 'can'),
('8991234560024', 'Tomato Sauce 250g',     4,   18.00,  13.00, 'can'),
('8991234560025', 'Coconut Milk 400ml',    4,   35.00,  26.00, 'can'),
('8991234560026', 'Pork & Beans 420g',     4,   38.00,  28.00, 'can'),

-- Condiments
('8991234560030', 'Soy Sauce 1L',          5,   38.00,  28.00, 'btl'),
('8991234560031', 'Vinegar 1L',            5,   28.00,  20.00, 'btl'),
('8991234560032', 'Fish Sauce 750ml',      5,   45.00,  34.00, 'btl'),
('8991234560033', 'Ketchup 320g',          5,   42.00,  32.00, 'btl'),
('8991234560034', 'Oyster Sauce 505g',     5,   55.00,  42.00, 'btl'),
('8991234560035', 'Sugar 1kg',             5,   62.00,  50.00, 'bag'),
('8991234560036', 'Brown Sugar 1kg',       5,   68.00,  54.00, 'bag'),
('8991234560037', 'Salt 1kg',              5,   20.00,  14.00, 'bag'),
('8991234560038', 'Seasoning Granules 8g', 5,    5.00,   3.00, 'sachet'),

-- Soft Drinks
('8991234560040', 'Cola 1.5L',             7,   58.00,  44.00, 'btl'),
('8991234560041', 'Cola 355ml Can',        7,   30.00,  22.00, 'can'),
('8991234560042', 'Orange Soda 1.5L',      7,   55.00,  42.00, 'btl'),
('8991234560043', 'Root Beer 330ml Can',   7,   28.00,  20.00, 'can'),
('8991234560044', 'Energy Drink 250ml',    7,   40.00,  30.00, 'can'),
('8991234560045', 'Iced Tea 1L',           7,   45.00,  34.00, 'btl'),

-- Water & Juices
('8991234560050', 'Mineral Water 500ml',   8,   12.00,   8.00, 'btl'),
('8991234560051', 'Mineral Water 1.5L',    8,   22.00,  16.00, 'btl'),
('8991234560052', 'Mineral Water 6L',      8,   65.00,  50.00, 'btl'),
('8991234560053', 'Orange Juice 1L',       8,   75.00,  58.00, 'btl'),
('8991234560054', 'Apple Juice 250ml',     8,   28.00,  20.00, 'btl'),
('8991234560055', 'Mango Juice 1L',        8,   68.00,  52.00, 'btl'),

-- Soap & Shampoo
('8991234560060', 'Bath Soap 135g',        10,  22.00,  15.00, 'pcs'),
('8991234560061', 'Bath Soap 6-pack',      10, 110.00,  82.00, 'pack'),
('8991234560062', 'Shampoo 200ml',         10,  55.00,  40.00, 'btl'),
('8991234560063', 'Shampoo Sachet 9ml',    10,   5.00,   3.00, 'sachet'),
('8991234560064', 'Conditioner 200ml',     10,  58.00,  44.00, 'btl'),
('8991234560065', 'Toothpaste 150g',       10,  42.00,  32.00, 'pcs'),
('8991234560066', 'Toothbrush Medium',     10,  28.00,  20.00, 'pcs'),
('8991234560067', 'Facial Wash 100ml',     10,  65.00,  50.00, 'btl'),
('8991234560068', 'Deodorant 40ml',        10,  48.00,  36.00, 'pcs'),

-- Chips & Crackers
('8991234560070', 'Potato Chips 60g',      12,  28.00,  20.00, 'pack'),
('8991234560071', 'Potato Chips 100g',     12,  42.00,  32.00, 'pack'),
('8991234560072', 'Crackers 250g',         12,  38.00,  28.00, 'pack'),
('8991234560073', 'Cheese Curls 55g',      12,  22.00,  15.00, 'pack'),
('8991234560074', 'Corn Chips 70g',        12,  25.00,  18.00, 'pack'),
('8991234560075', 'Biscuits 150g',         12,  35.00,  26.00, 'pack'),
('8991234560076', 'Chocolate Bar 35g',     12,  18.00,  12.00, 'pcs'),
('8991234560077', 'Gummy Bears 80g',       12,  32.00,  24.00, 'pack'),

-- Dairy
('8991234560080', 'Fresh Milk 1L',         13,  78.00,  62.00, 'btl'),
('8991234560081', 'UHT Milk 250ml',        13,  22.00,  16.00, 'btl'),
('8991234560082', 'Evaporated Milk 370ml', 13,  35.00,  26.00, 'can'),
('8991234560083', 'Condensed Milk 300ml',  13,  38.00,  28.00, 'can'),
('8991234560084', 'Cheese 165g',           13,  72.00,  56.00, 'pcs'),
('8991234560085', 'Yogurt 125g',           13,  28.00,  20.00, 'cup'),
('8991234560086', 'Eggs 12pcs',            13,  88.00,  72.00, 'tray'),

-- Frozen Foods
('8991234560090', 'Hotdog 250g',           14,  68.00,  52.00, 'pack'),
('8991234560091', 'Hotdog 500g',           14, 125.00,  98.00, 'pack'),
('8991234560092', 'Chicken Nuggets 400g',  14,  95.00,  75.00, 'pack'),
('8991234560093', 'Fish Balls 200g',       14,  42.00,  32.00, 'pack'),
('8991234560094', 'Frozen Fries 500g',     14,  65.00,  50.00, 'pack'),
('8991234560095', 'Ice Cream 750ml',       14, 120.00,  92.00, 'tub'),
('8991234560096', 'Ice Cream Bar 60ml',    14,  28.00,  20.00, 'pcs'),

-- Cleaning
('8991234560100', 'Laundry Detergent 1kg', 15,  78.00,  60.00, 'bag'),
('8991234560101', 'Laundry Det. Sachet',   15,  10.00,   7.00, 'sachet'),
('8991234560102', 'Fabric Conditioner 1L', 15,  58.00,  44.00, 'btl'),
('8991234560103', 'Dishwashing Liquid 500ml',15, 42.00, 32.00, 'btl'),
('8991234560104', 'Bleach 1L',             15,  28.00,  20.00, 'btl'),
('8991234560105', 'Floor Cleaner 900ml',   15,  68.00,  52.00, 'btl'),
('8991234560106', 'Toilet Bowl Cleaner 500ml',15,38.00, 28.00, 'btl'),
('8991234560107', 'Trash Bags 10pcs',      15,  32.00,  24.00, 'roll'),
('8991234560108', 'Sponge Scrub 2pcs',     15,  18.00,  12.00, 'pack')

ON CONFLICT (barcode) DO NOTHING;

-- Stock for all new products in Main Warehouse (id=1)
INSERT INTO warehouse_stock (warehouse_id, product_id, stock_qty)
SELECT 1, id,
  CASE
    WHEN unit = 'sachet' THEN 300
    WHEN unit IN ('can', 'pcs') THEN 150
    WHEN unit IN ('pack', 'btl', 'cup') THEN 80
    WHEN unit IN ('bag', 'sack', 'tray', 'roll', 'tub') THEN 40
    ELSE 50
  END
FROM products
WHERE barcode LIKE '8991234560%'
ON CONFLICT (warehouse_id, product_id) DO NOTHING;
