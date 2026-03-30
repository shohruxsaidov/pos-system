# Offline POS System — Market Edition
Stack: Node.js + Fastify · Vue 3 + PrimeVue 4 · Flutter · PostgreSQL · PWA

---

## 1. Architecture

Three frontends, one shared backend.

```
MONOBLOCK (Browser)          PHONE — Vue PWA (WiFi)       PHONE — Flutter (native)
────────────────────         ──────────────────────       ────────────────────────
pos-desktop/ (Vue SPA)       pos-mobile/ (Vue SPA)        pos-mobile-flutter/
Chrome/Edge :5173            Chrome/Safari :3000/mobile   Android/iOS native
       │                            │                            │
       └─────────────► backend/ (Fastify :3000) ◄───────────────┘
                              │
                         PostgreSQL (local)
                              │ (when online)
                         Cloud / HQ DB (sync)
```

Rules:
- pos-desktop — plain Vue SPA (no Tauri), cashier UI, opened in browser at `http://localhost:5173`
- pos-mobile — Vue SPA, served by Fastify at `/mobile`, accessed via phone browser over WiFi
- pos-mobile-flutter — Flutter native app (Android/iOS), connects to same backend API
- backend — API at `/api/*` + serves mobile SPA static files at `/mobile`

---

## 2. Project Structure

```
pos/
├── ecosystem.config.cjs        # PM2 config (backend + pos-desktop)
├── pos-desktop/                # Vue SPA — monoblock cashier UI
│   └── src/
│       ├── views/              # POSView, InventoryView, ReportsView, SettingsView,
│       │                       # TransactionsView, CustomersView, CategoriesView, WarehouseView
│       ├── stores/             # cart.js, session.js, status.js (WebSocket)
│       ├── components/         # NumPad, PinPad, PaymentModal, StatusBar, PrintLabelDialog,
│       │                       # RefundDialog, ZReportDialog, XReportDialog
│       ├── composables/        # useApi.js, useBarcode.js
│       └── assets/style.css
│
├── pos-mobile/                 # Vue SPA — warehouse phone UI (PWA)
│   └── src/
│       ├── views/              # MobileLoginView, MobileSaleView, MobileInventoryView,
│       │                       # MobileReportsView, IncomingFormView
│       ├── stores/             # warehouse.js
│       ├── components/         # IncomingItemCard, MobileProductCard, BottomNumPad,
│       │                       # StockAdjustSheet, ProductNotFound, CartSheet,
│       │                       # PaymentSheet, ManualAddSheet
│       ├── composables/        # useConnectivity.js, useOfflineQueue.js
│       └── assets/             # style.css (shared tokens), mobile.css (overrides)
│
├── pos-mobile-flutter/         # Flutter native app — warehouse phone UI
│   └── lib/
│       ├── config/             # api_config.dart, app_theme.dart, router.dart
│       ├── models/             # product.dart, cart_item.dart, user.dart, category.dart,
│       │                       # incoming_item.dart, offline_draft.dart
│       ├── providers/          # auth_provider.dart, warehouse_provider.dart,
│       │                       # connectivity_provider.dart, offline_draft_provider.dart
│       ├── screens/            # login_screen.dart, main_shell.dart, sales_screen.dart,
│       │                       # incoming_screen.dart, inventory_screen.dart,
│       │                       # reports_screen.dart, settings_screen.dart,
│       │                       # offline_draft_screen.dart, qr_scanner_screen.dart
│       ├── services/           # api_service.dart, offline_queue_service.dart
│       ├── utils/              # format.dart (formatPrice), stock_status.dart
│       └── widgets/            # bottom_numpad.dart, stock_adjust_sheet.dart,
│                               # cart_sheet.dart, payment_sheet.dart, product_card.dart
│
└── backend/                    # Fastify — API + serves mobile SPA
    └── src/
        ├── server.js
        ├── db/
        │   ├── connection.js
        │   ├── migrate.js
        │   └── migrations/     # 001_schema.sql, 002_add_client_ref.sql,
        │                       # 003_printer_address.sql, 004_product_barcodes.sql
        ├── routes/             # products, transactions, reports, customers,
        │                       # categories, settings, auth, incoming, inventory,
        │                       # sync, notifications, status, barcode, refunds,
        │                       # audit, warehouses
        └── services/           # notificationService, statusService, cronService,
                                # auditService, printService, botService,
                                # networkService, backupService
```

Fastify serves mobile Vue SPA:
```js
fastify.register(fastifyStatic, { root: '../../pos-mobile/dist', prefix: '/mobile' })
fastify.get('/mobile/*', (req, reply) => reply.sendFile('index.html', '../../pos-mobile/dist'))
```

Build / dev commands (use pnpm):
```bash
cd backend              && pnpm dev    # node --watch src/server.js
cd pos-desktop          && pnpm dev    # vite dev on :5173
cd pos-mobile           && pnpm dev    # vite dev on :5174
cd pos-mobile           && pnpm build  # → dist served by Fastify at /mobile
cd pos-mobile-flutter   && flutter run # run on device/emulator
```

Flutter key packages: `flutter_riverpod` (state), `go_router` (nav), `mobile_scanner` (barcode), `barcode_widget` (render), `shared_preferences` (storage), `flutter_secure_storage` (tokens), `connectivity_plus`, `sentry_flutter` (monitoring).

PM2 (from repo root): `pm2 start ecosystem.config.cjs` · `pm2 logs` · `pm2 status`

---

## 3. Database Schema

```
categories        (id, name, parent_id, color, icon)
warehouses        (id, name, location, is_active, created_at)
products          (id, barcode, name, category_id, price, cost,
                   unit, image_url, is_active, low_stock_threshold, updated_at)
product_barcodes  (id, product_id, barcode, is_primary)          -- migration 004
users             (id, name, pin_hash, role, is_active)
                  -- role: 'cashier' | 'manager' | 'admin' | 'warehouse'
customers         (id, name, phone, email, loyalty_points, created_at)
warehouse_stock   (id, product_id, warehouse_id, stock_qty, updated_at)
transactions      (id, ref_no, customer_id, cashier_id, subtotal, discount, tax,
                   total, payment_method, status, refund_id, synced, created_at)
                  -- status: 'completed' | 'refunded' | 'partially_refunded' | 'voided'
transaction_items (id, transaction_id, product_id, qty, unit_price, discount, subtotal)
payments          (id, transaction_id, method, amount, change_given, reference, created_at)
z_reports         (id, ref_no, cashier_id, opened_at, closed_at, total_sales,
                   total_transactions, total_refunds, created_at)
settings          (key, value)
incoming_receipts (id, ref_no, received_by, supplier, notes, total_cost, created_at)
incoming_items    (id, receipt_id, product_id, product_name,
                   qty_received, cost_per_unit, expiry_date, subtotal)
stock_adjustments (id, product_id, adjusted_by, delta, reason, created_at)
refunds           (id, ref_no, original_txn_id, processed_by, approved_by,
                   refund_type, reason, total_refund_amount, payment_method, created_at)
refund_items      (id, refund_id, product_id, product_name, qty_returned, unit_price, subtotal)
audit_log         (id, action, actor_id, actor_name, actor_role, approver_id,
                   target_type, target_id, target_name, details JSONB,
                   ip_address, created_at)
sync_log          (id, table_name, record_id, action, synced_at, payload)
```

**Migrations:** 001–004 SQL files, auto-run on app launch via `migrate.js`.
`stock_qty` in `warehouse_stock` has **no lower bound** — negative values allowed (oversold).

---

## 4. API Endpoints

```
# Products
GET    /api/products                     list + search + filter
GET    /api/products/barcode/:code       lookup (checks product_barcodes table)
POST   /api/products                     create
PUT    /api/products/:id                 update
PATCH  /api/products/:id/stock           adjust stock (logs to stock_adjustments)
DELETE /api/products/:id                 soft delete

# Transactions
POST   /api/transactions                 create sale → deducts stock
GET    /api/transactions                 list (date filter)
GET    /api/transactions/:id             detail with items
POST   /api/transactions/:id/void        void

# Refunds
POST   /api/refunds                      process (requires manager PIN)
GET    /api/refunds                      list
GET    /api/refunds/:id                  detail
GET    /api/transactions/:id/refundable  items still refundable

# Reports
GET    /api/reports/daily                daily summary
GET    /api/reports/products             top selling
GET    /api/reports/cashiers             per-cashier breakdown
GET    /api/reports/inventory            stock levels
POST   /api/reports/z                    close shift, generate Z report
GET    /api/reports/z                    list Z reports
GET    /api/reports/z/:id                Z report detail
GET    /api/reports/x                    current shift X report (intra-day)

# Warehouses
GET    /api/warehouses                   list
POST   /api/warehouses                   create
PUT    /api/warehouses/:id               update
GET    /api/warehouses/:id/stock         stock levels for warehouse

# Incoming (mobile warehouse)
POST   /api/incoming/auth                warehouse PIN login → token
POST   /api/incoming                     confirm receipt → updates stock
GET    /api/incoming                     list receipts
GET    /api/incoming/:id                 receipt detail

# Inventory (mobile)
GET    /api/inventory/mobile             product list (id, name, barcode, stock, price, category)
GET    /api/inventory/adjustments        audit of adjustments (manager only)

# Barcode
POST   /api/barcode/print                push print cmd to desktop via WS (phone path)
GET    /api/barcode/generate             auto-generate + save barcode for product

# Audit
GET    /api/audit                        paginated (manager+ only)
                                         ?action= ?actor_id= ?from= ?to= ?target_type=

# Auth / Settings / Sync / Notifications / Status
POST   /api/auth/login
GET    /api/settings/mobile-url          returns LAN IP + /mobile URL
POST   /api/sync/push | GET /api/sync/pull | GET /api/sync/status
POST   /api/notifications/test-telegram
GET    /health                           uptime + timestamp
WS     /ws/status                        health + print_label push channel
```

---

## 5. Screen → PrimeVue Component Map (Desktop)

| Screen | Key Components |
|--------|----------------|
| **POS** | `IconField`+`InputText` (barcode), `VirtualScroller` (products), `DataTable` (cart), `Dialog`+`SelectButton`+NumPad (payment) |
| **Payment Modal** | `SelectButton` (method), `InputNumber` (tendered), `Tag` (change), `ToggleSwitch` (receipt), `Button` (confirm) |
| **Inventory** | `DataTable`, `Drawer` (CRUD form), `FileUpload`, `TreeSelect` (category), `Dialog` (stock adjust), `Tag` (stock badge) |
| **Reports** | `DatePicker`, `Chart` (line/bar), `DataTable` ×3, `Card` ×4, `Button`+`Menu` (export), ZReportDialog, XReportDialog |
| **Transactions** | `DataTable`, `Tag` (status badge), RefundDialog |
| **Customers** | `DataTable`, `Drawer`, `ProgressBar` (loyalty), expandable row (purchase history) |
| **Categories** | `DataTable`, `Drawer`, `ColorPicker` |
| **Warehouse** | `DataTable` (stock per warehouse), `Drawer` (warehouse CRUD) |
| **Settings** | Tabs, `ToggleSwitch`, `InputOtp` (PIN), `DataTable` (users), QR Card, Audit Log tab, PrinterSettingsView |
| **Login** | `Select` (cashier), `InputOtp` + PinPad buttons |
| **Refund Dialog** | `Dialog`, `DataTable` (selectable items), `InputNumber` (qty), `Select` (reason), `InputOtp` (manager PIN) |
| **Audit Log** | `DataTable`, `Tag` (action badge), `Select`+`DatePicker`+`InputText` (filters), `OverlayPanel` (details) |

---

## 6. Negative Stock

`warehouse_stock.stock_qty INTEGER` — no CHECK constraint, freely negative.

```js
// Stock status helper (shared across Vue desktop, Vue mobile, Flutter)
function stockStatus(qty) {
  if (qty < 0)  return { label: `Oversold (${qty})`, severity: 'danger', glow: true }
  if (qty === 0) return { label: 'Out of Stock',      severity: 'danger' }
  if (qty <= 5)  return { label: `Low (${qty})`,      severity: 'warn' }
  return              { label: `${qty} in stock`,     severity: 'success' }
}
```

Inventory has **Oversold Items** filter tab: `WHERE stock_qty < 0 ORDER BY stock_qty ASC`

---

## 7. Price Formatting

All prices use `formatPrice()` — no currency symbol, space as thousands separator (non-breaking space `\u00A0`).

```js
// Vue (pos-desktop, pos-mobile) — defined locally per file
function formatPrice(n) {
  const [int, dec] = parseFloat(n || 0).toFixed(2).split('.')
  return int.replace(/\B(?=(\d{3})+(?!\d))/g, '\u00A0') + '.' + dec
}
// → 1 000 000.00
```

```dart
// Flutter (pos-mobile-flutter/lib/utils/format.dart)
String formatPrice(num n) {
  return NumberFormat('#,##0.00').format(n).replaceAll(',', '\u00A0');
}
```

**Never** use `NumberFormat` / `Intl.NumberFormat` directly in templates — always go through `formatPrice`. Never show ₱ or any currency symbol anywhere in the UI.

---

## 8. Notifications — Telegram Bot

> Push alerts use outbound `sendMessage` only. No webhooks, no static IP.
> Owner dashboard bot (§17) uses long polling (`getUpdates`). No port forwarding required.

**Triggers:**
- After every sale: `stock_qty < 0` → 🚨 Oversold · `stock_qty ≤ threshold` → ⚠️ Low stock
- Daily cron (configurable `eod_time`): 📊 End-of-day summary + optional AI analysis

**Settings:** `telegram_bot_token`, `telegram_chat_id`, `low_stock_threshold`, `eod_time`, `telegram_enabled`, `claude_api_key`, `ai_summary_enabled`

**EOD AI Summary** (when `ai_summary_enabled = true`):
- Provider: Claude via `@anthropic-ai/sdk`, model `claude-haiku-4-5-20251001`
- Setting key: `claude_api_key`
- Data sent to AI: txn count, top products, payment methods, refunds, low/oversold stock, incoming items, stock adjustments, yesterday comparison
- Output appended to EOD message as `🤖 AI Анализ:` block (Russian language)

**Routes:** `POST /api/notifications/test-telegram` · `GET /api/notifications/status`

---

## 9. Touch-Friendly Input

All inputs/buttons minimum **56px** height. Primary actions (Pay, Confirm) **72px**.

```css
.p-inputtext, .p-select   { height: 56px; font-size: 18px; border-radius: 12px; }
.p-button                  { height: 56px; }
.p-button.touch-lg         { height: 72px; font-size: 20px; }
.p-select-option           { height: 52px; }
.p-toggleswitch            { width: 64px; height: 36px; }
.p-inputotp-input          { width: 64px; height: 28px; }
```

**NumPad.vue / bottom_numpad.dart** — `88×88px` keys, replaces system keyboard (`inputmode="none"`). Used for: payment amount, qty adjust, stock adjust, incoming qty/cost.
**PinPad.vue** — `80×80px` keys for PIN login. Form rules: single column only, sticky Save/Cancel footer.

---

## 10. Server Status (WebSocket)

Status bar pinned to app bottom:
```
[🟢 Server]  [🟢 Database]  [🟡 Sync: 3 pending]   14:32
```

`ws://localhost:3000/ws/status` — server pushes on change + heartbeat every 5s. Vue marks offline if 2 pings missed. Reconnect: 3s → 5s → 10s backoff.

If server **or** DB goes down → full-screen blocking overlay, cashier cannot transact.

**Status payload:**
```json
{ "server": "ok", "db": "ok", "sync_queue": 3, "last_sync": "...",
  "cloud_reachable": true, "uptime": 3620, "mobile_url": "http://192.168.1.100:3000/mobile" }
```

Desktop identifies itself: `{ type: 'identify', client: 'desktop' }` — Fastify tracks in `desktopClients` Set for barcode print broadcasting (§18).

**Pinia `statusStore`:** `server`, `db`, `sync`, `syncQueue`, `lastSync`, `uptime`, `missedPings`

---

## 11. Hardware Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| RAM | 4 GB | 8 GB |
| CPU | Dual-core 1.8 GHz | Intel i3 / Ryzen 3 2.5 GHz+ |
| Storage | 64 GB HDD | 128 GB SSD |
| Display | 1024×768 touchscreen | 1280×800 touchscreen |
| OS | Windows 10 64-bit | Windows 10/11 64-bit |

Memory: OS 1GB + Browser+Vue 200MB + Fastify 80MB + PostgreSQL 256MB ≈ 2GB actual → 4GB minimum.

---

## 12. Local PostgreSQL Setup

```sql
CREATE USER pos_user WITH PASSWORD 'strongpassword';
CREATE DATABASE market_pos OWNER pos_user;
```

**`postgresql.conf` (4 GB machine):**
```ini
shared_buffers = 512MB  work_mem = 16MB  max_connections = 20
wal_level = minimal     synchronous_commit = off
```

Connection pool: `pg.Pool` max 10. Migrations: plain SQL, auto-run on launch, tracked in `_migrations` table.
Backups: `backupService.js` → `pg_dump` → `.sql.gz`, keep 30 days, optional AWS S3. ~100 MB/year at 150 txn/day.

**backend/.env:**
```
DATABASE_URL=postgresql://pos_user:pass@localhost:5432/market_pos
PORT=3000
JWT_SECRET=change-this-in-production
NODE_ENV=production
```

---

## 13. Incoming Products — Mobile

Phone-optimized page for warehouse staff. Access: `http://[POS-IP]:3000/mobile` → Login → Incoming tab (or Flutter app).

**Bluetooth reader** pairs as keyboard. Hidden `<input>` stays focused. On Enter → barcode lookup → add card. `🟢 Reader Ready` indicator.

Per-item: Product (scan), Qty (NumPad), Cost (NumPad, pre-fills last cost), Expiry. Per-receipt: Supplier, Notes.

**Warehouse role:** Token from `/api/incoming/auth` only works on `/api/incoming/*`.

**On confirm (POST /api/incoming):**
```
BEGIN → INSERT incoming_receipts → for each item:
          INSERT incoming_items
          UPDATE warehouse_stock SET stock_qty = stock_qty + qty_received
          UPDATE products SET cost = cost_per_unit
COMMIT → broadcastStatus() → desktop reflects new stock instantly
```

Product not found → `ProductNotFound` quick-create dialog.

---

## 14. Inventory — Mobile

Same session (no re-login). Bottom nav: `[ 🛒 Sale ] [ 📦 Incoming ] [ 📋 Inventory ] [ 📊 Reports ]`.

Filter by All/Low/Oversold. BT scan → scroll to + pulse card. Quick stock adjust per card. Cannot edit price/name/delete (manager desktop only).

**Mobile Sale:** Full cart + payment flow on phone. CartSheet for review, PaymentSheet for checkout. Offline draft support — queues sale locally when disconnected.

**Stock adjust sheet:** Add/Remove toggle + NumPad qty + Reason dropdown → logged to `stock_adjustments`.

**Performance:** `VirtualScroller` (Vue) / `ListView.builder` (Flutter), debounced search 300ms, full list fetched once + client-side filter.

---

## 15. Design System — ClickUp Dark

**Fonts:** `Plus Jakarta Sans` (UI) · `JetBrains Mono` (amounts, barcodes, TXN refs)

**CSS Variables:**
```css
/* Backgrounds */
--bg-base: #1a1a27;  --bg-sidebar: #13131e;  --bg-surface: #22223a;
--bg-elevated: #1e1e32;  --bg-input: #2a2a45;  --bg-hover: #2e2e4a;

/* Borders */
--border-subtle: rgba(255,255,255,0.06);  --border-default: rgba(255,255,255,0.10);
--border-focus: rgba(123,104,238,0.60);

/* Accent — ClickUp purple */
--accent-1: #7b68ee;  --accent-2: #9d4edd;  --accent-3: #c77dff;
--accent-glow: rgba(123,104,238,0.28);

/* Semantic */
--success: #00d4aa;  --warning: #ffb02e;  --danger: #ff5c5c;
--success-bg: rgba(0,212,170,0.10);  --warning-bg: rgba(255,176,46,0.10);
--danger-bg: rgba(255,92,92,0.12);

/* Text */
--text-primary: #e2e2f5;  --text-secondary: #9898bb;
--text-muted: #55557a;  --text-accent: #b39dff;

/* Gradients */
--gradient-accent: linear-gradient(135deg, #7b68ee, #9d4edd, #c77dff);
--gradient-hero:   linear-gradient(135deg, #4e54c8, #7b68ee, #8f94fb);
--gradient-card:   linear-gradient(145deg, #252540, #1e1e32);
```

**Key usages:**
- Primary buttons → `--gradient-hero` + shadow
- Active nav → `--gradient-accent` + glow
- Amounts/TXN refs → `--gradient-hero` gradient text + mono font
- Stock badges → semantic color pairs
- Mobile bottom nav active → `--text-accent` + 2px `--gradient-accent` underline
- Desktop + mobile Vue share same `:root` tokens. Flutter mirrors them in `app_theme.dart`.

---

## 16. Warehouse QR Code

`SettingsView.vue` → Warehouse tab. Manager scans to share mobile URL with staff.

IP auto-detected via `networkService.js` (finds first non-internal IPv4). `GET /api/settings/mobile-url` → `{ url, ip }`. QR rendered client-side with `qrcode` package (fully offline). `mobile_url` included in WebSocket health payload.

---

## 17. Refunds & Returns

Full or partial. Manager PIN required. Stock auto-restocked. Cannot refund twice. Every refund logged to `audit_log`.

**Flow:** Verify manager PIN → validate `status = 'completed'` → BEGIN: INSERT refunds + refund_items, UPDATE stock, UPDATE txn status → COMMIT.

Entry: TransactionsView → `[Refund]` → RefundDialog (selectable items, qty, reason, manager PIN).

Status badges: Completed (teal) · Refunded (purple) · Partial Refund (amber) · Voided (red)

---

## 18. Audit Log

Manager/admin only. All sensitive actions recorded.

**Actions:** `login` `logout` `sale` `void` `refund` `refund_approved` `stock_adjust` `stock_incoming` `product_create` `product_edit` `product_delete` `price_override` `settings_change` `user_create` `user_edit` `user_delete` `sync_push` `sync_pull` `barcode_print`

```js
// auditService.js
export async function logAudit(pool, { action, actor, approver, target, details, ip }) {
  await pool.query(`INSERT INTO audit_log (...) VALUES ($1...$10)`,
    [action, actor.id, actor.name, actor.role, approver?.id,
     target?.type, target?.id, target?.name, JSON.stringify(details), ip])
}
// details examples:
// stock_adjust:  { "before": 12, "after": 8, "delta": -4, "reason": "Damaged" }
// product_edit:  { "field": "price", "before": 45.00, "after": 50.00 }
// refund:        { "refund_ref": "RFD-...", "amount": 188.00, "reason": "Wrong item" }
```

**Desktop UI:** SettingsView → Audit Log tab. Filterable by date range, action, user. ~20MB/year, no pruning needed.

---

## 19. Owner Dashboard Bot (Telegram)

Long polling (`getUpdates?timeout=30`) — near-instant delivery, near-zero idle CPU.

| Command | Response |
|---------|----------|
| /today | Transactions, gross/net sales, avg/txn, first/last sale |
| /week /month | Period totals |
| /sales 2026-03-10 | Specific date breakdown |
| /stock | All oversold 🚨 + low stock ⚠️ items |
| /top | Top 10 products today by qty |
| /cashiers | Per-cashier txn count + sales |
| /refunds | Today's refunds |
| /txn TXN-... | Full transaction detail |
| /status | Server/DB/sync health + last sale time + mobile URL |
| /help | Command list |

**Security:** Only Telegram user IDs in `settings.telegram_owner_ids` (JSON array) can interact.
**Integration:** Starts in Fastify `ready` hook, stops in `onClose`. Reuses `sendTelegram()` from `notificationService.js`.

---

## 20. Barcode Generation & Label Printing

Two entry points — desktop and phone. Both use `printService.js` with `node-thermal-printer`.

**Desktop path:** InventoryView → PrintLabelDialog.vue (live SVG preview) → `POST /api/barcode/print { source: 'desktop' }` → printer.

**Phone path (WebSocket bridge):**
```
POST /api/barcode/print → broadcastToDesktop({ type: 'print_label' })
  → WebSocket → status.js handler → POST /api/barcode/print { source: 'desktop', relayed: true }
```
If desktop not connected: `503 Desktop app not connected`.

**Barcode generation:**
```js
// Format: 200 + 6-digit product ID + EAN13 check digit
export function generateBarcode(productId) {
  const base = `200${String(productId).padStart(6, '0')}`
  let sum = 0
  base.split('').forEach((d, i) => sum += parseInt(d) * (i % 2 === 0 ? 1 : 3))
  return base + ((10 - sum % 10) % 10)
}
```

**Multiple barcodes** (migration 004): lookup checks both `products.barcode` and `product_barcodes.barcode`.

**Label layout (58mm):** store name · product name · CODE128 · price (no currency symbol).
**Sizes:** 58mm and 80mm thermal roll. **Audit:** `barcode_print` logged with source.

---

## 21. Process Management (PM2)

```js
// ecosystem.config.cjs
module.exports = { apps: [
  { name: 'pos-backend', script: 'src/server.js', cwd: './backend',
    watch: false, max_memory_restart: '512M', env: { NODE_ENV: 'production', PORT: 3000 } },
  { name: 'pos-desktop', script: 'npx vite preview --port 5173', cwd: './pos-desktop', watch: false }
]}
```

```bash
pm2 start ecosystem.config.cjs  # start all
pm2 restart pos-backend          # restart backend
pm2 logs pos-backend --lines 100 # tail logs
pm2 save && pm2 startup          # persist + register OS startup (Windows)
```

**Boot sequence:** PM2 starts on OS boot → Fastify :3000 + Vite preview :5173 → browser opens `http://localhost:5173` → connects `ws://localhost:3000/ws/status`.
