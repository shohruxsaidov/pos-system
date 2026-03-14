import { pool } from "../db/connection.js";
import { sendTelegram, generateAISummary } from "./notificationService.js";
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
        reply = `📅 <b>Сегодня (${today})</b>\nТранзакций: ${r.count}\nВыручка: ${parseFloat(r.total).toFixed(2)}\nСредний чек: ${parseFloat(r.avg).toFixed(2)}`;
        break;
      }
      case "/week": {
        const { rows } = await pool.query(`
          SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total
          FROM transactions WHERE created_at >= NOW()-INTERVAL '7 days' AND status!='voided'
        `);
        const r = rows[0];
        reply = `📅 <b>Последние 7 дней</b>\nТранзакций: ${r.count}\nВыручка: ${parseFloat(r.total).toFixed(2)}`;
        break;
      }
      case "/month": {
        const { rows } = await pool.query(`
          SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total
          FROM transactions WHERE DATE_TRUNC('month',created_at)=DATE_TRUNC('month',NOW()) AND status!='voided'
        `);
        const r = rows[0];
        reply = `📅 <b>Этот месяц</b>\nТранзакций: ${r.count}\nВыручка: ${parseFloat(r.total).toFixed(2)}`;
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
        reply = `📅 <b>Продажи за ${date}</b>\nТранзакций: ${r.count}\nВыручка: ${parseFloat(r.total).toFixed(2)}`;
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
          : "Нет";
        const lowText = low.length
          ? low.map((p) => `⚠️ ${p.name}: ${p.stock_qty}`).join("\n")
          : "Нет";
        reply = `📦 <b>Остатки</b>\n\n<b>В минусе:</b>\n${oversoldText}\n\n<b>Мало товара:</b>\n${lowText}`;
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
          `🏆 <b>Топ товары сегодня</b>\n\n` +
          (rows.length
            ? rows
                .map((r, i) => `${i + 1}. ${r.name} (${r.qty} шт.)`)
                .join("\n")
            : "Продаж не было");
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
          `👤 <b>Кассиры сегодня</b>\n\n` +
          (rows.length
            ? rows
                .map(
                  (r) =>
                    `${r.name}: ${r.count} чек(ов) · ${parseFloat(r.total).toFixed(2)}`,
                )
                .join("\n")
            : "Активности нет");
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
          `↩️ <b>Возвраты сегодня</b>\n\n` +
          (rows.length
            ? rows
                .map(
                  (r) =>
                    `${r.ref_no}: ${parseFloat(r.total_refund_amount).toFixed(2)} — ${r.reason}`,
                )
                .join("\n")
            : "Возвратов не было");
        break;
      }
      case "/txn": {
        const ref = args[0];
        if (!ref) {
          reply = "Использование: /txn TXN-xxxx";
          break;
        }
        const { rows } = await pool.query(
          "SELECT t.*, u.name as cashier_name FROM transactions t LEFT JOIN users u ON u.id=t.cashier_id WHERE t.ref_no=$1",
          [ref],
        );
        if (!rows[0]) {
          reply = `Транзакция ${ref} не найдена`;
          break;
        }
        const t = rows[0];
        const { rows: items } = await pool.query(
          "SELECT ti.*, p.name FROM transaction_items ti JOIN products p ON p.id=ti.product_id WHERE ti.transaction_id=$1",
          [t.id],
        );
        reply =
          `🧾 <b>${t.ref_no}</b>\n` +
          `Кассир: ${t.cashier_name}\n` +
          `Сумма: ${parseFloat(t.total).toFixed(2)}\n` +
          `Оплата: ${t.payment_method}\n` +
          `Статус: ${t.status}\n` +
          `Дата: ${new Date(t.created_at).toLocaleString()}\n\n` +
          `<b>Товары:</b>\n` +
          items
            .map(
              (i) =>
                `• ${i.name} ×${i.qty} = ${parseFloat(i.subtotal).toFixed(2)}`,
            )
            .join("\n");
        break;
      }
      case "/summary": {
        await sendTelegram(botToken, String(chatId), "⏳ Генерирую AI анализ...");

        const { rows: s } = await pool.query(
          `SELECT COUNT(*) as txn_count, COALESCE(SUM(total),0) as net_sales, COALESCE(AVG(total),0) as avg_txn
           FROM transactions WHERE DATE(created_at)=$1 AND status!='voided'`,
          [today]
        );
        const { rows: topProducts } = await pool.query(
          `SELECT p.name, SUM(ti.qty) as total_qty, SUM(ti.subtotal) as revenue
           FROM transaction_items ti
           JOIN products p ON p.id=ti.product_id
           JOIN transactions t ON t.id=ti.transaction_id
           WHERE DATE(t.created_at)=$1 AND t.status!='voided'
           GROUP BY p.id, p.name ORDER BY total_qty DESC LIMIT 5`,
          [today]
        );
        const { rows: paymentMethods } = await pool.query(
          `SELECT payment_method as method, COUNT(*) as count, COALESCE(SUM(total),0) as total
           FROM transactions WHERE DATE(created_at)=$1 AND status!='voided'
           GROUP BY payment_method`,
          [today]
        );
        const { rows: refunds } = await pool.query(
          `SELECT COUNT(*) as count, COALESCE(SUM(total_refund_amount),0) as total
           FROM refunds WHERE DATE(created_at)=$1`,
          [today]
        );
        const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0];
        const { rows: yday } = await pool.query(
          `SELECT COALESCE(SUM(total),0) as net_sales FROM transactions
           WHERE DATE(created_at)=$1 AND status!='voided'`,
          [yesterday]
        );
        const { rows: lowStock } = await pool.query(
          `SELECT p.name, SUM(ws.stock_qty) as stock_qty
           FROM products p
           JOIN warehouse_stock ws ON ws.product_id=p.id
           WHERE p.is_active=true
           GROUP BY p.id, p.name
           HAVING SUM(ws.stock_qty) > 0 AND SUM(ws.stock_qty) <= 5
           ORDER BY SUM(ws.stock_qty) ASC LIMIT 5`
        );
        const { rows: oversold } = await pool.query(
          `SELECT p.name, SUM(ws.stock_qty) as stock_qty
           FROM products p
           JOIN warehouse_stock ws ON ws.product_id=p.id
           WHERE p.is_active=true
           GROUP BY p.id, p.name
           HAVING SUM(ws.stock_qty) < 0
           ORDER BY SUM(ws.stock_qty) ASC LIMIT 5`
        );

        const { rows: storeRow } = await pool.query(
          "SELECT value FROM settings WHERE key='store_name'"
        );

        const aiText = await generateAISummary({
          date: today,
          storeName: storeRow[0]?.value || "Store",
          txnCount: parseInt(s[0].txn_count),
          netSales: parseFloat(s[0].net_sales),
          avgTxn: parseFloat(s[0].avg_txn),
          topProducts: topProducts.map(p => ({ name: p.name, qty: parseInt(p.total_qty), revenue: parseFloat(p.revenue) })),
          paymentMethods: paymentMethods.map(p => ({ method: p.method, count: parseInt(p.count), total: parseFloat(p.total) })),
          refundCount: parseInt(refunds[0].count),
          refundTotal: parseFloat(refunds[0].total),
          lowStockItems: lowStock.map(p => ({ name: p.name, stock_qty: p.stock_qty })),
          oversoldItems: oversold.map(p => ({ name: p.name, stock_qty: p.stock_qty })),
          yesterdayNetSales: parseFloat(yday[0]?.net_sales || 0),
        });

        reply = aiText
          ? `🤖 <b>AI Анализ за ${today}</b>\n\n${aiText}`
          : "❌ AI анализ недоступен — проверьте Gemini API Key и настройки.";
        break;
      }
      case "/status": {
        const { rows: dbCheck } = await pool.query("SELECT 1");
        const mobileUrl = getMobileUrl();
        const { rows: lastSale } = await pool.query(
          "SELECT created_at FROM transactions ORDER BY created_at DESC LIMIT 1",
        );
        reply = `🖥️ <b>Состояние системы</b>\nСервер: 🟢 Работает\nБД: ${dbCheck.length ? "🟢 OK" : "🔴 Ошибка"}\nАптайм: ${Math.floor(process.uptime() / 60)} мин\nМобильный: ${mobileUrl}\nПоследняя продажа: ${lastSale[0] ? new Date(lastSale[0].created_at).toLocaleString() : "Нет"}`;
        break;
      }
      case "/help":
      default:
        reply = `🤖 <b>Команды POS бота</b>\n\n/today — Итоги сегодня\n/week — Последние 7 дней\n/month — Этот месяц\n/sales YYYY-MM-DD — Конкретная дата\n/stock — Остатки товаров\n/top — Топ товары сегодня\n/cashiers — По кассирам\n/refunds — Возвраты сегодня\n/txn REF — Детали транзакции\n/status — Состояние системы\n/summary — AI анализ продаж за сегодня\n/help — Список команд`;
    }
  } catch (err) {
    reply = `❌ Ошибка: ${err.message}`;
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
        { command: "today",    description: "Итоги продаж сегодня" },
        { command: "week",     description: "Итоги за последние 7 дней" },
        { command: "month",    description: "Итоги за этот месяц" },
        { command: "sales",    description: "Продажи за дату: /sales YYYY-MM-DD" },
        { command: "stock",    description: "Остатки: минус и мало товара" },
        { command: "top",      description: "Топ-10 товаров сегодня" },
        { command: "cashiers", description: "По кассирам за сегодня" },
        { command: "refunds",  description: "Возвраты сегодня" },
        { command: "txn",      description: "Детали транзакции: /txn REF" },
        { command: "status",   description: "Состояние системы и ссылка на мобильный" },
        { command: "summary",  description: "AI анализ продаж за сегодня" },
        { command: "help",     description: "Список всех команд" },
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
