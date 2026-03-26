# Offline POS System — Market Edition
Stack: Node.js + Fastify · Vue 3 + PrimeVue 4 · PostgreSQL · PWA

---

## 1. Architecture

Two separate frontends, one shared backend.

MONOBLOCK (Browser)                    PHONE (WiFi)
─────────────────────                  ─────────────────────
pos-desktop/ (Vue SPA)                 pos-mobile/ (Vue SPA)
Chrome/Edge browser                    Chrome/Safari browser
     │                                      │
     └──────────► backend/ (Fastify :3000) ◄┘
                       │
                  PostgreSQL (local)
                       │ (when online)
                  Cloud / HQ DB (sync)

Rules:
- pos-desktop — plain Vue SPA (no Tauri), cashier UI, opened in browser at http://localhost:5173
- pos-mobile — separate Vue SPA, served by Fastify at /mobile
- backend — API at /api/* + serves mobile SPA static files at /mobile
- Phone accesses http://[POS-IP]:3000/mobile over local WiFi
- Both apps are PWAs (vite-plugin-pwa) for installability and offline support

---

## 2. Project Structure

pos/
├── ecosystem.config.cjs    # PM2 process config (backend + pos-desktop dev server)
├── pos-desktop/            # Vue SPA — monoblock cashier UI
│   └── src/
│       ├── views/          # HomeView, LoginView, POSView, InventoryView, ReportsView,
│       │                   # SettingsView, PrinterSettingsView, TransactionsView,
│       │                   # CustomersView, CategoriesView, WarehouseView
│       ├── stores/         # cart.js, session.js, status.js (WebSocket)
│       ├── components/     # NumPad, PinPad, PaymentModal, StatusBar, PrintLabelDialog,
│       │                   # RefundDialog, ZReportDialog, XReportDialog, ReportTemplate
│       ├── composables/    # useApi.js, useBarcode.js
│       ├── router/index.js
│       └── assets/style.css
│
├── pos-mobile/             # Separate Vue SPA — warehouse phone UI
│   └── src/
│       ├── views/          # MobileLoginView, MobileSaleView, MobileInventoryView,
│       │                   # MobileReportsView, IncomingFormView
│       ├── stores/         # warehouse.js
│       ├── components/     # IncomingItemCard, MobileProductCard, BottomNumPad,
│       │                   # StockAdjustSheet, ProductNotFound, CartSheet,
│       │                   # PaymentSheet, ManualAddSheet
│       ├── composables/    # useConnectivity.js, useOfflineQueue.js
│       └── assets/         # style.css (shared tokens), mobile.css (overrides)
│
└── backend/                # Fastify — API + serves mobile SPA
    └── src/
        ├── server.js
        ├── db/
        │   ├── connection.js
        │   ├── migrate.js
        │   └── migrations/  # 001_schema.sql, 002_add_client_ref.sql,
        │                    # 003_printer_address.sql, 004_product_barcodes.sql
        ├── routes/           # products, transactions, reports, customers,
        │                     # categories, settings, auth, incoming, inventory,
        │                     # sync, notifications, status, barcode, refunds,
        │                     # audit, warehouses
        └── services/         # notificationService, statusService, cronService,
                              # auditService, printService, botService,
                              # networkService, backupService

Fastify serves mobile SPA:
fastify.register(fastifyStatic, { root: '../../pos-mobile/dist', prefix: '/mobile' })
fastify.get('/mobile/*', (req, reply) =>
  reply.sendFile('index.html', '../../pos-mobile/dist'))

Build / dev commands (use pnpm):
cd backend     && pnpm dev          # node --watch src/server.js
cd pos-desktop && pnpm dev          # vite dev on :5173
cd pos-mobile  && pnpm dev          # vite dev on :5174
cd pos-mobile  && pnpm build        # → dist served by Fastify at /mobile
cd pos-desktop && pnpm build        # → dist for production

PM2 (from repo root):
pm2 start ecosystem.config.cjs     # start backend + pos-desktop
pm2 logs                            # tail logs

---

## 3. Database Schema

categories        (id, name, parent_id, color, icon)
warehouses        (id, name, location, is_active, created_at)
products          (id, barcode, name, category_id, price, cost,
                   unit, image_url, is_active, updated_at)
product_barcodes  (id, product_id, barcode, is_primary)
                  -- migration 004: multiple barcodes per product
users             (id, name, pin_hash, role, is_active)
                  -- role: 'cashier' | 'manager' | 'admin' | 'warehouse'
customers         (id, name, phone, email, loyalty_points, created_at)
warehouse_stock   (id, product_id, warehouse_id, stock_qty, updated_at)
transactions      (id, ref_no, customer_id, cashier_id, subtotal,
                   discount, tax, total, payment_method,
                   status, refund_id, synced, created_at)
                  -- status: 'completed' | 'refunded' | 'partially_refunded' | 'voided'
transaction_items (id, transaction_id, product_id, qty, unit_price, discount, subtotal)
payments          (id, transaction_id, method, amount, change_given, reference, created_at)
z_reports         (id, ref_no, cashier_id, opened_at, closed_at, total_sales,
                   total_transactions, total_refunds, created_at)
sync_log          (id, table_name, record_id, action, synced_at, payload)
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

**Migrations:** 001–004 SQL files, auto-run on app launch via migrate.js.
`stock_qty` in warehouse_stock has **no lower bound** — negative values allowed (oversold).

---

## 4. API Endpoints

# Products
GET    /api/products                   list + search + filter
GET    /api/products/barcode/:code     barcode lookup (checks product_barcodes table)
POST   /api/products                   create
PUT    /api/products/:id               update
PATCH  /api/products/:id/stock         adjust stock (logs to stock_adjustments)
DELETE /api/products/:id               soft delete

# Transactions
POST   /api/transactions               create sale → deducts stock
GET    /api/transactions               list (date filter)
GET    /api/transactions/:id           detail with items
POST   /api/transactions/:id/void      void

# Refunds
POST   /api/refunds                    process refund (requires manager PIN)
GET    /api/refunds                    list
GET    /api/refunds/:id                detail
GET    /api/transactions/:id/refundable  items still refundable

# Reports
GET    /api/reports/daily              daily summary
GET    /api/reports/products           top selling
GET    /api/reports/cashiers           per-cashier breakdown
GET    /api/reports/inventory          stock levels

# Z/X Reports
POST   /api/reports/z                  close shift, generate Z report
GET    /api/reports/z                  list Z reports
GET    /api/reports/z/:id              Z report detail
GET    /api/reports/x                  current shift X report (intra-day)

# Warehouses
GET    /api/warehouses                 list warehouses
POST   /api/warehouses                 create warehouse
PUT    /api/warehouses/:id             update
GET    /api/warehouses/:id/stock       stock levels for warehouse

# Incoming (mobile warehouse)
POST   /api/incoming/auth              warehouse PIN login → token
POST   /api/incoming                   confirm receipt → updates stock
GET    /api/incoming                   list receipts
GET    /api/incoming/:id               receipt detail

# Inventory (mobile)
GET    /api/inventory/mobile           product list (id, name, barcode, stock, price, category)
GET    /api/inventory/adjustments      audit of adjustments (manager only)

# Barcode
POST   /api/barcode/print              push print cmd to desktop via WS (phone path)
GET    /api/barcode/generate           auto-generate + save barcode for product

# Audit
GET    /api/audit                      paginated (manager+ only)
                                       ?action= ?actor_id= ?from= ?to= ?target_type=

# Auth / Settings / Sync / Notifications / Status
POST   /api/auth/login
GET    /api/settings/mobile-url        returns LAN IP + /mobile URL
POST   /api/sync/push | GET /api/sync/pull | GET /api/sync/status
POST   /api/notifications/test-telegram
GET    /health                         uptime + timestamp
WS     /ws/status                      health + print_label push channel

---

## 5. Screen → PrimeVue Component Map

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

warehouse_stock.stock_qty INTEGER — no CHECK constraint, freely negative.

-- Deduct on sale — no validation
UPDATE warehouse_stock SET stock_qty = stock_qty - $1
WHERE product_id = $2 AND warehouse_id = $3

```js
// Vue stock status helper
function stockStatus(qty) {
  if (qty < 0)  return { label: `Oversold (${qty})`, severity: 'danger', glow: true }
  if (qty === 0) return { label: 'Out of Stock',      severity: 'danger' }
  if (qty <= 5)  return { label: `Low (${qty})`,      severity: 'warn' }
  return              { label: `${qty} in stock`,     severity: 'success' }
}
```

Inventory has **Oversold Items** filter tab: `WHERE stock_qty < 0 ORDER BY stock_qty ASC`

---

## 7. Notifications — Telegram Bot

> **No webhooks. No static IP needed.** Push alerts use outbound `sendMessage` only.
> The owner dashboard bot (§18) uses long polling (`getUpdates`). No port forwarding required.

**Triggers:**
- After every sale: `stock_qty < 0` → 🚨 Oversold alert · `stock_qty ≤ threshold` → ⚠️ Low stock alert
- Daily cron (configurable time): 📊 End-of-day summary

**Settings stored in DB:** `telegram_bot_token`, `telegram_chat_id`, `low_stock_threshold`, `eod_time`, `telegram_enabled`

**Message templates:**
```
⚠️ Low Stock Alert          🚨 Oversold Alert           📊 End of Day
Product: Rice 5kg           Product: Oil 1L             Transactions: 142
Stock:   3 units            Stock:   -2 (OVERSOLD)      Net Sales: 27,250
Branch:  Main Market        Action needed: receive       Top: Routes (8 sold)
```

**Routes:** `POST /api/notifications/test-telegram` · `GET /api/notifications/status`

---

## 8. Touch-Friendly Input

All inputs/buttons minimum **56px** height. Primary actions (Pay, Confirm) **72px**.

```css
.p-inputtext, .p-select   { height: 56px; font-size: 18px; border-radius: 12px; }
.p-button                  { height: 56px; }
.p-button.touch-lg         { height: 72px; font-size: 20px; }
.p-select-option           { height: 52px; }
.p-toggleswitch            { width: 64px; height: 36px; }
.p-inputotp-input          { width: 64px; height: 28px; }
```

**NumPad.vue** — `88×88px` keys, replaces system keyboard on all number inputs (`inputmode="none"`). Used for: payment amount, qty adjust, stock adjust, incoming qty/cost.
**PinPad.vue** — `80×80px` keys for PIN login.
**Form rules:** Single column only. Drawers always have sticky Save/Cancel footer.

---

## 9. Server Status (WebSocket)

Status bar pinned to app bottom — always visible:
```
[🟢 Server]  [🟢 Database]  [🟡 Sync: 3 pending]   14:32
```

`ws://localhost:3000/ws/status` — server pushes on change + heartbeat every 5s.
Vue marks server offline if 2 pings missed. Reconnect: 3s → 5s → 10s backoff.

If server **or** DB goes down → full-screen blocking overlay, cashier cannot transact.

**Status payload:**
```json
{ "server": "ok", "db": "ok", "sync_queue": 3, "last_sync": "...",
  "cloud_reachable": true, "uptime": 3620, "mobile_url": "http://192.168.1.100:3000/mobile" }
```

Desktop identifies itself on connect: `{ type: 'identify', client: 'desktop' }` — Fastify tracks these in `desktopClients` Set for broadcasting (barcode print §19).

**Pinia `statusStore`:** `server`, `db`, `sync`, `syncQueue`, `lastSync`, `uptime`, `missedPings`

---

## 10. Hardware Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| RAM | 4 GB | 8 GB |
| CPU | Dual-core 1.8 GHz | Intel i3 / Ryzen 3 2.5 GHz+ |
| Storage | 64 GB HDD | 128 GB SSD |
| Display | 1024×768 touchscreen | 1280×800 touchscreen |
| OS | Windows 10 64-bit | Windows 10/11 64-bit |
| USB | 2 ports | 4 ports |

Memory: OS 1GB + Browser+Vue 200MB + Fastify 80MB + PostgreSQL 256MB = ~2GB actual → 4GB minimum.

---

## 11. Local PostgreSQL Setup

Runs entirely on the POS machine. Fastify connects via DATABASE_URL env var.

```sql
-- One-time setup
CREATE USER pos_user WITH PASSWORD 'strongpassword';
CREATE DATABASE market_pos OWNER pos_user;
```

**`postgresql.conf` (4 GB machine):**
```ini
shared_buffers       = 512MB
work_mem             = 16MB
max_connections      = 20
wal_level            = minimal
synchronous_commit   = off    # safe for local POS, faster writes
log_min_duration_statement = 1000
```

**Connection pool:** `pg.Pool` max 10. **Migrations:** plain SQL, auto-run on launch, tracked in `_migrations` table.

**Backups:** `backupService.js` → `pg_dump` → `.sql.gz`, keep 30 days. Also supports AWS S3 backup upload. Path configurable (can point to USB).

**Data estimate:** ~100 MB/year at 150 transactions/day.

---

## 12. Incoming Products — Mobile

Phone-optimized page for warehouse staff to receive stock via Bluetooth barcode reader.
Access: `http://[POS-IP]:3000/mobile` → Login → Incoming tab.

**Bluetooth reader** pairs to phone as a keyboard. Hidden `<input>` stays focused at all times. On `keydown Enter` → lookup barcode → add card to list. `🟢 Reader Ready` indicator shows focus state.

**Per-item fields:** Product (from scan), Qty (NumPad integer), Cost (NumPad decimal, pre-fills last cost), Expiry date (DatePicker month/year). Per-receipt: Supplier, Notes.

**Warehouse role:** Separate `warehouse` role in `users` table. Token from `/api/incoming/auth` only works on `/api/incoming/*` — cannot access POS routes.

**On confirm (POST /api/incoming):**
```
BEGIN transaction
  INSERT incoming_receipts → receipt_id
  for each item:
    INSERT incoming_items
    UPDATE warehouse_stock SET stock_qty = stock_qty + qty_received
    UPDATE products SET cost = cost_per_unit
COMMIT → broadcastStatus() → desktop reflects new stock instantly
```

Product not found on scan → `Dialog` quick-create form (ProductNotFound component).

---

## 13. Inventory — Mobile

Same warehouse session (no second login). Bottom nav tab: `[ 🛒 Sale ] [ 📦 Incoming ] [ 📋 Inventory ] [ 📊 Reports ]`.

**Features:** View all products, filter by All/Low/Oversold, BT scan → scroll to + pulse card, Quick stock adjust per card. Cannot edit price/name/delete (manager desktop only).

**Mobile Sale (MobileSaleView):** Full cart + payment flow on phone. Barcode scan to add items, CartSheet for cart review, PaymentSheet for checkout.

**Stock adjust bottom sheet:**
- Add or Remove toggle + NumPad qty
- Reason dropdown: Receiving correction / Damaged / Count correction / Return to supplier / Other
- Logged to `stock_adjustments` table for full audit trail

**Performance:** `VirtualScroller`, debounced search 300ms, full list fetched once + client-side filter, pull-to-refresh.

---

## 14. Design System — ClickUp Dark

**Fonts:** `Plus Jakarta Sans` (UI) · `JetBrains Mono` (amounts, barcodes, TXN refs)

**CSS Variables:**
```css
/* Backgrounds */
--bg-base:        #1a1a27;   /* app shell */
--bg-sidebar:     #13131e;   /* sidebar */
--bg-surface:     #22223a;   /* cards */
--bg-elevated:    #1e1e32;   /* modals, drawers, bottom sheets */
--bg-input:       #2a2a45;   /* inputs, selects */
--bg-hover:       #2e2e4a;

/* Borders */
--border-subtle:  rgba(255,255,255,0.06);
--border-default: rgba(255,255,255,0.10);
--border-focus:   rgba(123,104,238,0.60);

/* Accent — ClickUp purple gradient */
--accent-1: #7b68ee;  --accent-2: #9d4edd;  --accent-3: #c77dff;
--accent-glow: rgba(123,104,238,0.28);

/* Hero CTA gradient */
--hero-1: #4e54c8;  --hero-2: #7b68ee;  --hero-3: #8f94fb;

/* Semantic */
--success: #00d4aa;  --success-bg: rgba(0,212,170,0.10);
--warning: #ffb02e;  --warning-bg: rgba(255,176,46,0.10);
--danger:  #ff5c5c;  --danger-bg:  rgba(255,92,92,0.12);

/* Text */
--text-primary: #e2e2f5;  --text-secondary: #9898bb;
--text-muted:   #55557a;  --text-accent:    #b39dff;

/* Gradients */
--gradient-accent:  linear-gradient(135deg, #7b68ee, #9d4edd, #c77dff);
--gradient-hero:    linear-gradient(135deg, #4e54c8, #7b68ee, #8f94fb);
--gradient-card:    linear-gradient(145deg, #252540, #1e1e32);
--gradient-mesh:    /* 3-layer radial purple glow — body background */
  radial-gradient(ellipse 70% 40% at 50% 0%,  rgba(78,84,200,0.18)  0%, transparent 65%),
  radial-gradient(ellipse 40% 25% at 85% 15%, rgba(157,78,221,0.12) 0%, transparent 55%),
  radial-gradient(ellipse 30% 20% at 10% 80%, rgba(123,104,238,0.08) 0%, transparent 50%);
```

**Key usages:**
- Primary buttons (Pay/Confirm/Save) → `--gradient-hero` + `--shadow-accent`
- Active nav pill → `--gradient-accent` + glow
- Cards → `--gradient-card` border `--border-subtle`, hover border `rgba(123,104,238,0.40)`
- Amounts/TXN refs → `--gradient-hero` gradient text + `--font-mono`
- Stock badges → semantic `--success/warning/danger` bg+border pairs
- NumPad confirm key → `--gradient-hero` · delete key → `--danger-bg`
- Status bar pills → semantic colors + pulse glow animation on warn/error
- Mobile bottom nav active tab → `--text-accent` + 2px `--gradient-accent` underline
- Desktop + mobile share same `:root` tokens — one source of truth

---

## 15. Warehouse QR Code

In `SettingsView.vue` → Warehouse tab. Manager scans to share mobile URL with staff — no typing.

**IP auto-detection** (no config needed):
```js
// networkService.js
import os from 'os'
export function getMobileUrl() {
  for (const ifaces of Object.values(os.networkInterfaces())) {
    const iface = ifaces.find(i => i.family === 'IPv4' && !i.internal)
    if (iface) return `http://${iface.address}:3000/mobile`
  }
  return 'http://localhost:3000/mobile'
}
```

`GET /api/settings/mobile-url` → `{ url, ip }`

**QR generation:** `qrcode` npm package, renders to `<canvas>` client-side — fully offline.
```js
await QRCode.toCanvas(canvas, url, {
  width: 220, margin: 2,
  color: { dark: '#e2e2f5', light: '#22223a' }  // dark-themed QR
})
```

**Refresh button** — re-fetches IP if router reassigned. **Print button** — opens clean print dialog (QR + URL only, no app chrome). `mobile_url` also included in WebSocket health payload so status bar always shows current IP.

---

## 16. Refunds & Returns

**Rules:** Full or partial. Manager PIN required to authorize. Stock auto-restocked. Refund method matches original. Cannot refund twice. Every refund logged to `audit_log`.

**Tables:** `refunds` (migration 001) + `refund_items`
```sql
refunds      (id, ref_no, original_txn_id, processed_by, approved_by,
              refund_type, reason, total_refund_amount, payment_method, created_at)
refund_items (id, refund_id, product_id, product_name, qty_returned, unit_price, subtotal)
transactions -- status TEXT DEFAULT 'completed', refund_id INTEGER
```

**Flow (POST /api/refunds):**
```
Verify manager PIN → validate txn status = 'completed'
  → BEGIN: INSERT refunds + refund_items
           UPDATE warehouse_stock SET stock_qty = stock_qty + qty_returned (per item)
           UPDATE transactions SET status = 'refunded' | 'partially_refunded'
           logAudit(...)
  → COMMIT
```

**Entry point:** TransactionsView → transaction row → `[Refund]` button → RefundDialog with selectable items, qty per item, reason dropdown, manager PIN field.

**Status badges:** Completed (teal) · Refunded (purple) · Partial Refund (amber) · Voided (red)

---

## 17. Audit Log

Every sensitive action recorded. Manager/admin only.

**Logged actions:** `login` `logout` `sale` `void` `refund` `refund_approved` `stock_adjust` `stock_incoming` `product_create` `product_edit` `product_delete` `price_override` `settings_change` `user_create` `user_edit` `user_delete` `sync_push` `sync_pull` `barcode_print`

**Table:**
```sql
audit_log (id, action, actor_id, actor_name, actor_role, approver_id,
           target_type, target_id, target_name, details JSONB, ip_address, created_at)
-- Indexes on: action, actor_id, created_at DESC, (target_type, target_id)
```

**details JSONB examples:**
```js
// stock_adjust:   { "before": 12, "after": 8, "delta": -4, "reason": "Damaged" }
// product_edit:   { "field": "price", "before": 45.00, "after": 50.00 }
// refund:         { "refund_ref": "RFD-...", "amount": 188.00, "reason": "Wrong item" }
```

**Reusable logger:**
```js
// auditService.js
export async function logAudit(pool, { action, actor, approver, target, details, ip }) {
  await pool.query(`INSERT INTO audit_log (...) VALUES ($1...$10)`,
    [action, actor.id, actor.name, actor.role, approver?.id,
     target?.type, target?.id, target?.name, JSON.stringify(details), ip])
}
```

**Desktop UI:** SettingsView.vue → Audit Log tab. Filterable by date range, action type, user. Action badges color-coded: sale=teal, refund/void=amber, price_override=red, stock=purple. Row expand → full JSONB details. Grows ~20MB/year, no pruning needed.

---

## 18. Owner Dashboard Bot (Telegram)

Owner queries POS from Telegram. Uses **long polling** — no static IP, no webhook, no port forwarding.

**Polling loop:**
```js
// botService.js
async function startPolling() {
  while (polling) {
    try {
      const res = await fetch(
        `https://api.telegram.org/bot${token}/getUpdates?offset=${offset}&timeout=30`,
        { signal: AbortSignal.timeout(35_000) }
      )
      const { result } = await res.json()
      for (const update of result) {
        offset = update.update_id + 1
        if (update.message?.text) await handleMessage(update.message)
      }
    } catch { await sleep(5000) }  // retry on network error
  }
}
```

`timeout=30` = Telegram holds connection up to 30s waiting for messages → near-instant delivery, near-zero CPU when idle.

**Commands:**

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

**Security:** Only Telegram user IDs in `settings.telegram_owner_ids` (JSON array) can interact — all others silently ignored.

**Integration:** Starts in Fastify ready hook, stops in onClose. Reuses `sendTelegram()` from notificationService.js and same DB pool as reports.

---

## 19. Barcode Generation & Label Printing

Two entry points — desktop browser and phone. Both use `printService.js` with `node-thermal-printer`.

### Desktop Path (direct network print)
```
InventoryView → [⊞ Generate] or [🖨 Print Label]
  → PrintLabelDialog.vue (live JsBarcode SVG preview)
  → POST /api/barcode/print { source: 'desktop', ... }
  → printService.js → node-thermal-printer → USB/network label printer
```

### Phone Path (WebSocket bridge)
```
MobileInventory → [🖨] → print bottom sheet (SVG preview, copies, size)
  → POST /api/barcode/print
  → Fastify broadcastToDesktop({ type: 'print_label', payload })
  → WebSocket → pos-desktop status.js onmessage handler
  → POST /api/barcode/print { source: 'desktop', relayed: true }
  → printService.js → node-thermal-printer → USB/network label printer
```

If desktop not connected: `503 Desktop app not connected` → phone shows error toast.

### Multiple Barcodes (migration 004)
Products can have multiple barcodes in `product_barcodes` table. Barcode lookup checks both `products.barcode` and `product_barcodes.barcode`. Print dialog lets user select which barcode to print when a product has multiple.

### Barcode Generation — JsBarcode (client-side, offline)
```js
// composables/useBarcode.js — shared in both apps
import JsBarcode from 'jsbarcode'

export function renderBarcode(svgEl, barcode) {
  JsBarcode(svgEl, barcode, {
    format: 'CODE128', width: 2, height: 48,
    displayValue: true, fontSize: 11,
    lineColor: '#e2e2f5', background: 'transparent'
  })
}

// Auto-generate for products with no barcode
// Format: 200 + 6-digit product ID + EAN13 check digit
export function generateBarcode(productId) {
  const base = `200${String(productId).padStart(6, '0')}`
  let sum = 0
  base.split('').forEach((d, i) => sum += parseInt(d) * (i % 2 === 0 ? 1 : 3))
  return base + ((10 - sum % 10) % 10)
}
```

Generated barcodes saved back: `UPDATE products SET barcode = $1 WHERE id = $2 AND barcode IS NULL`

### broadcastToDesktop (statusService.js)
```js
const desktopClients = new Set()
// Desktop sends { type: 'identify', client: 'desktop' } on WS connect
ws.on('message', msg => {
  if (JSON.parse(msg).client === 'desktop') desktopClients.add(ws)
})
ws.on('close', () => desktopClients.delete(ws))
export function broadcastToDesktop(message) {
  if (!desktopClients.size) return false
  desktopClients.forEach(c => c.send(JSON.stringify(message)))
  return true
}
```

### Label Layout (58mm)
```
┌──────────────────────────┐
│  Main Market Store       │  ← store name from settings
│  Rice 5kg                │  ← product name (bold)
│  ▐██▌▐█▌▐███▌▐█▌▐██▌    │  ← CODE128
│  8 9 9 1 2 3 4 5 6 7 8  │
│  45.00                   │  ← price (no currency symbol)
└──────────────────────────┘
```

**Packages:** `jsbarcode` (both apps) · `node-thermal-printer` (backend)
**Label sizes:** 58mm and 80mm thermal roll
**Desktop UI:** `[⊞ Generate]` + `[🖨 Print Label]` per row + bulk print selected
**Mobile UI:** `[🖨]` icon per card → bottom sheet with SVG preview, copies, size
**Audit:** `barcode_print` logged with source (desktop/mobile)

---

## 20. Process Management (PM2)

The backend and pos-desktop dev server are managed via **PM2** using `ecosystem.config.cjs` at the repo root.

### ecosystem.config.cjs
```js
module.exports = {
  apps: [
    {
      name: 'pos-backend',
      script: 'src/server.js',
      cwd: './backend',
      watch: false,
      max_memory_restart: '512M',
      env: { NODE_ENV: 'production', PORT: 3000 }
    },
    {
      name: 'pos-desktop',
      script: 'npx vite preview --port 5173',
      cwd: './pos-desktop',
      watch: false
    }
  ]
}
```

### Common PM2 Commands
```bash
pm2 start ecosystem.config.cjs   # start all
pm2 stop all                      # stop all
pm2 restart pos-backend           # restart backend
pm2 logs pos-backend              # tail logs
pm2 status                        # list processes
pm2 save                          # persist process list
pm2 startup                       # generate OS startup script
```

### Windows Startup (Production)
```bash
# Install PM2 globally
pnpm add -g pm2

# Save process list and enable startup
pm2 start ecosystem.config.cjs
pm2 save
pm2 startup
# Follow the printed command to register the startup script
```

### Viewing Logs
```powershell
# PM2 log files (default: ~/.pm2/logs/)
pm2 logs pos-backend --lines 100
pm2 logs pos-desktop --lines 50
```

### Environment Variables (.env)
PM2 can load `.env` from the `cwd`. Alternatively use `env` block in ecosystem.config.cjs or `dotenv` in server.js:
```js
// server.js — top of file
import 'dotenv/config'   // reads backend/.env automatically
```

**backend/.env:**
```
DATABASE_URL=postgresql://pos_user:pass@localhost:5432/market_pos
PORT=3000
JWT_SECRET=change-this-in-production
NODE_ENV=production
```

### Boot Sequence
```
Windows starts
  └── PM2 service starts (registered via pm2 startup)
        └── pos-backend: Fastify + PostgreSQL ready on :3000
        └── pos-desktop: Vite preview serving on :5173
  └── User opens browser → http://localhost:5173
        └── Connects to ws://localhost:3000/ws/status → 🟢 Online
```

| Detail | Value |
|--------|-------|
| Tool | PM2 (ecosystem.config.cjs) |
| Backend | `pos-backend`, port 3000 |
| Desktop | `pos-desktop`, port 5173 |
| Start type | OS startup via `pm2 startup` |
| Crash restart | Automatic (PM2 default) |
| Logs | `~/.pm2/logs/` |
| Env vars | `backend/.env` via dotenv |
