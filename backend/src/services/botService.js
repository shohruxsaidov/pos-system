import { pool } from "../db/connection.js";
import { sendTelegram } from "./notificationService.js";
import { getMobileUrl } from "./networkService.js";

let polling = false;
let offset = 0;
let botToken = "";
let ownerIds = [];

async function loadSettings() {
  try {
    const { rows } = await pool.query(
      "SELECT key, value FROM settings WHERE key IN ('telegram_bot_token','telegram_owner_ids','telegram_enabled')",
    );
    const s = Object.fromEntries(rows.map((r) => [r.key, r.value]));
    botToken = s.telegram_bot_token || "";
    ownerIds = JSON.parse(s.telegram_owner_ids || "[]");
    return s.telegram_enabled === "true";
  } catch (e) {
    return false;
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function handleMessage(msg) {
  const chatId = msg.chat.id;
  const userId = msg.from?.id;

  if (!ownerIds.includes(userId) && !ownerIds.includes(String(userId))) {
    return; // silently ignore unauthorized
  }

  const text = (msg.text || "").trim();
  const [cmd, ...args] = text.split(" ");

  let reply = "";

  try {
    const today = new Date().toISOString().split("T")[0];

    switch (cmd) {
      case "/today": {
        const { rows } = await pool.query(
          `
          SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total, COALESCE(AVG(total),0) as avg
          FROM transactions WHERE DATE(created_at)=$1 AND status!='voided'
        `,
          [today],
        );
        const r = rows[0];
        reply = `📅 <b>Today (${today})</b>\nTransactions: ${r.count}\nGross Sales: ${parseFloat(r.total).toFixed(2)}\nAvg/Txn: ${parseFloat(r.avg).toFixed(2)}`;
        break;
      }
      case "/week": {
        const { rows } = await pool.query(`
          SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total
          FROM transactions WHERE created_at >= NOW()-INTERVAL '7 days' AND status!='voided'
        `);
        const r = rows[0];
        reply = `📅 <b>Last 7 Days</b>\nTransactions: ${r.count}\nTotal Sales: ${parseFloat(r.total).toFixed(2)}`;
        break;
      }
      case "/month": {
        const { rows } = await pool.query(`
          SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total
          FROM transactions WHERE DATE_TRUNC('month',created_at)=DATE_TRUNC('month',NOW()) AND status!='voided'
        `);
        const r = rows[0];
        reply = `📅 <b>This Month</b>\nTransactions: ${r.count}\nTotal Sales: ${parseFloat(r.total).toFixed(2)}`;
        break;
      }
      case "/sales": {
        const date = args[0] || today;
        const { rows } = await pool.query(
          `
          SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total
          FROM transactions WHERE DATE(created_at)=$1 AND status!='voided'
        `,
          [date],
        );
        const r = rows[0];
        reply = `📅 <b>Sales on ${date}</b>\nTransactions: ${r.count}\nTotal: ${parseFloat(r.total).toFixed(2)}`;
        break;
      }
      case "/stock": {
        const { rows: oversold } = await pool.query(
          `SELECT p.name, SUM(ws.stock_qty) as stock_qty
           FROM products p
           JOIN warehouse_stock ws ON ws.product_id=p.id
           WHERE p.is_active=true
           GROUP BY p.name HAVING SUM(ws.stock_qty) < 0
           ORDER BY SUM(ws.stock_qty) ASC LIMIT 10`,
        );
        const { rows: low } = await pool.query(
          `SELECT p.name, SUM(ws.stock_qty) as stock_qty
           FROM products p
           JOIN warehouse_stock ws ON ws.product_id=p.id
           WHERE p.is_active=true
           GROUP BY p.name HAVING SUM(ws.stock_qty) >= 0 AND SUM(ws.stock_qty) <= 5
           ORDER BY SUM(ws.stock_qty) ASC LIMIT 10`,
        );
        const oversoldText = oversold.length
          ? oversold.map((p) => `🚨 ${p.name}: ${p.stock_qty}`).join("\n")
          : "None";
        const lowText = low.length
          ? low.map((p) => `⚠️ ${p.name}: ${p.stock_qty}`).join("\n")
          : "None";
        reply = `📦 <b>Stock Alerts</b>\n\n<b>Oversold:</b>\n${oversoldText}\n\n<b>Low Stock:</b>\n${lowText}`;
        break;
      }
      case "/top": {
        const { rows } = await pool.query(
          `
          SELECT p.name, SUM(ti.qty) as qty
          FROM transaction_items ti
          JOIN products p ON p.id=ti.product_id
          JOIN transactions t ON t.id=ti.transaction_id
          WHERE DATE(t.created_at)=$1 AND t.status!='voided'
          GROUP BY p.id, p.name ORDER BY qty DESC LIMIT 10
        `,
          [today],
        );
        reply =
          `🏆 <b>Top Products Today</b>\n\n` +
          (rows.length
            ? rows
                .map((r, i) => `${i + 1}. ${r.name} (${r.qty} sold)`)
                .join("\n")
            : "No sales today");
        break;
      }
      case "/cashiers": {
        const { rows } = await pool.query(
          `
          SELECT u.name, COUNT(t.id) as count, COALESCE(SUM(t.total),0) as total
          FROM transactions t JOIN users u ON u.id=t.cashier_id
          WHERE DATE(t.created_at)=$1 AND t.status!='voided'
          GROUP BY u.id, u.name ORDER BY total DESC
        `,
          [today],
        );
        reply =
          `👤 <b>Cashiers Today</b>\n\n` +
          (rows.length
            ? rows
                .map(
                  (r) =>
                    `${r.name}: ${r.count} txns · ${parseFloat(r.total).toFixed(2)}`,
                )
                .join("\n")
            : "No activity");
        break;
      }
      case "/refunds": {
        const { rows } = await pool.query(
          `
          SELECT r.ref_no, r.total_refund_amount, r.reason
          FROM refunds r WHERE DATE(r.created_at)=$1 LIMIT 10
        `,
          [today],
        );
        reply =
          `↩️ <b>Refunds Today</b>\n\n` +
          (rows.length
            ? rows
                .map(
                  (r) =>
                    `${r.ref_no}: ${parseFloat(r.total_refund_amount).toFixed(2)} — ${r.reason}`,
                )
                .join("\n")
            : "No refunds today");
        break;
      }
      case "/txn": {
        const ref = args[0];
        if (!ref) {
          reply = "Usage: /txn TXN-xxxx";
          break;
        }
        const { rows } = await pool.query(
          "SELECT t.*, u.name as cashier_name FROM transactions t LEFT JOIN users u ON u.id=t.cashier_id WHERE t.ref_no=$1",
          [ref],
        );
        if (!rows[0]) {
          reply = `Transaction ${ref} not found`;
          break;
        }
        const t = rows[0];
        const { rows: items } = await pool.query(
          "SELECT ti.*, p.name FROM transaction_items ti JOIN products p ON p.id=ti.product_id WHERE ti.transaction_id=$1",
          [t.id],
        );
        reply =
          `🧾 <b>${t.ref_no}</b>\n` +
          `Cashier: ${t.cashier_name}\n` +
          `Total: ${parseFloat(t.total).toFixed(2)}\n` +
          `Method: ${t.payment_method}\n` +
          `Status: ${t.status}\n` +
          `Date: ${new Date(t.created_at).toLocaleString()}\n\n` +
          `<b>Items:</b>\n` +
          items
            .map(
              (i) =>
                `• ${i.name} ×${i.qty} = ${parseFloat(i.subtotal).toFixed(2)}`,
            )
            .join("\n");
        break;
      }
      case "/status": {
        const { rows: dbCheck } = await pool.query("SELECT 1");
        const mobileUrl = getMobileUrl();
        const { rows: lastSale } = await pool.query(
          "SELECT created_at FROM transactions ORDER BY created_at DESC LIMIT 1",
        );
        reply = `🖥️ <b>System Status</b>\nServer: 🟢 Online\nDB: ${dbCheck.length ? "🟢 OK" : "🔴 Error"}\nUptime: ${Math.floor(process.uptime() / 60)} min\nMobile: ${mobileUrl}\nLast sale: ${lastSale[0] ? new Date(lastSale[0].created_at).toLocaleString() : "None"}`;
        break;
      }
      case "/help":
      default:
        reply = `🤖 <b>POS Bot Commands</b>\n\n/today — Today's summary\n/week — Last 7 days\n/month — This month\n/sales YYYY-MM-DD — Specific date\n/stock — Stock alerts\n/top — Top products today\n/cashiers — Per-cashier breakdown\n/refunds — Today's refunds\n/txn REF — Transaction detail\n/status — System health\n/help — This message`;
    }
  } catch (err) {
    reply = `❌ Error: ${err.message}`;
  }

  if (reply) await sendTelegram(botToken, String(chatId), reply);
}

export async function startBot() {
  const enabled = await loadSettings();
  if (!enabled || !botToken) {
    console.log("[bot] Telegram bot disabled or no token configured");
    return;
  }

  polling = true;
  console.log("[bot] Starting Telegram long-poll bot...");

  // Register commands so they appear in Telegram UI
  await fetch(`https://api.telegram.org/bot${botToken}/setMyCommands`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      commands: [
        { command: "today",    description: "Today's sales summary" },
        { command: "week",     description: "Last 7 days totals" },
        { command: "month",    description: "This month totals" },
        { command: "sales",    description: "Sales on a date: /sales YYYY-MM-DD" },
        { command: "stock",    description: "Oversold & low stock alerts" },
        { command: "top",      description: "Top 10 products today" },
        { command: "cashiers", description: "Per-cashier breakdown today" },
        { command: "refunds",  description: "Today's refunds" },
        { command: "txn",      description: "Transaction detail: /txn REF" },
        { command: "status",   description: "System health & mobile URL" },
        { command: "help",     description: "Show all commands" },
      ],
    }),
  }).catch((e) => console.error("[bot] setMyCommands failed:", e.message));

  while (polling) {
    try {
      const res = await fetch(
        `https://api.telegram.org/bot${botToken}/getUpdates?offset=${offset}&timeout=30`,
        { signal: AbortSignal.timeout(35000) },
      );
      const { result, ok } = await res.json();
      if (!ok) {
        await sleep(5000);
        continue;
      }

      for (const update of result || []) {
        offset = update.update_id + 1;
        if (update.message?.text) {
          await handleMessage(update.message).catch((e) =>
            console.error("[bot] Handler error:", e.message),
          );
        }
      }
    } catch (err) {
      if (polling) {
        console.error("[bot] Polling error:", err.message);
        await sleep(5000);
      }
    }
  }
}

export function stopBot() {
  polling = false;
}
