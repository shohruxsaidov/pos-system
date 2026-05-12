# pos-cloud

Cloud sync and reporting server for the offline POS system. Local POS instances push completed transactions here; managers access aggregated reports via JWT-protected API.

**Stack:** Node.js · Fastify · PostgreSQL

---

## Environment Variables

Create a `.env` file (never commit it):

```env
DATABASE_URL=postgresql://user:password@host:5432/pos_cloud
PORT=3001
API_KEY=strong-random-secret          # used by local POS to push transactions
JWT_SECRET=strong-random-secret       # used to sign report tokens
REPORTS_PASSWORD=strong-password      # exchanged for a JWT on /api/reports/login
```

---

## Docker

### Build

```bash
docker build -t pos-cloud .
```

### Run

```bash
docker run -d \
  --name pos-cloud \
  -p 3001:3001 \
  --env-file .env \
  pos-cloud
```

### Check logs

```bash
docker logs -f pos-cloud
```

### Stop / remove

```bash
docker stop pos-cloud && docker rm pos-cloud
```

---

## API

### Health

```
GET /health
```

Returns server and database status. No auth required.

```json
{ "status": "ok", "db": "ok", "uptime": 3620 }
```

---

### Sync — receive transactions

```
POST /api/sync/receive
X-Api-Key: <API_KEY>
```

Sent by the local POS after a sale. Idempotent — duplicate `ref_no` values are silently skipped.

**Request body:**

```json
{
  "transactions": [
    {
      "ref_no": "TXN-20260512-001",
      "cashier_id": 1,
      "cashier_name": "Shohrux",
      "warehouse_id": 1,
      "customer_id": null,
      "subtotal": 50000,
      "discount": 0,
      "tax": 0,
      "total": 50000,
      "payment_method": "cash",
      "status": "completed",
      "created_at": "2026-05-12T10:30:00Z",
      "items": [
        {
          "product_id": 5,
          "product_name": "Milk 1L",
          "qty": 2,
          "unit_price": 15000,
          "discount": 0,
          "subtotal": 30000,
          "cost_at_sale": 12000
        }
      ],
      "payment": {
        "method": "cash",
        "amount": 60000,
        "change_given": 10000,
        "reference": null
      }
    }
  ]
}
```

**Response:**

```json
{ "received": 1, "skipped": 0 }
```

---

### Reports

#### Login

```
POST /api/reports/login
```

```json
{ "password": "<REPORTS_PASSWORD>" }
```

Returns a JWT valid for 7 days:

```json
{ "token": "eyJ..." }
```

Use this token as `Authorization: Bearer <token>` on all report endpoints.

---

#### Daily summary

```
GET /api/reports/daily?from=2026-05-01&to=2026-05-12
Authorization: Bearer <token>
```

```json
{
  "transaction_count": "142",
  "total_sales": "7150000",
  "avg_per_transaction": "50352.11",
  "subtotal": "7150000",
  "total_discount": "0",
  "total_tax": "0",
  "payment_methods": [
    { "method": "cash", "count": "120", "total": "5900000" },
    { "method": "card", "count": "22",  "total": "1250000" }
  ]
}
```

#### Top products

```
GET /api/reports/products?from=2026-05-01&to=2026-05-12&limit=20
Authorization: Bearer <token>
```

#### Per-cashier breakdown

```
GET /api/reports/cashiers?from=2026-05-01&to=2026-05-12
Authorization: Bearer <token>
```

---

## Database

Migrations run automatically on startup. The PostgreSQL user needs `CREATE TABLE` privileges on first launch.

```sql
CREATE USER pos_cloud_user WITH PASSWORD 'strongpassword';
CREATE DATABASE pos_cloud OWNER pos_cloud_user;
```
