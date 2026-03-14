import { pool } from "../db/connection.js";

async function getSettings() {
  const { rows } = await pool.query("SELECT key, value FROM settings");
  return Object.fromEntries(rows.map((r) => [r.key, r.value]));
}

export async function sendTelegram(token, chatId, message) {
  if (!token || !chatId) return false;
  try {
    const url = `https://api.telegram.org/bot${token}/sendMessage`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: "HTML",
      }),
      signal: AbortSignal.timeout(10000),
    });
    const data = await res.json();
    if (!data.ok) {
      console.error("[telegram] Send failed:", data.description);
      return false;
    }
    return true;
  } catch (err) {
    console.error("[telegram] Error sending message:", err.message);
    return false;
  }
}

export async function sendLowStockAlert(product) {
  try {
    const settings = await getSettings();
    if (settings.telegram_enabled !== "true") return;
    const token = settings.telegram_bot_token;
    const chatId = settings.telegram_chat_id;
    const storeName = settings.store_name || "Store";

    const message = `⚠️ <b>Мало товара</b>\n\nТовар: ${product.name}\nОстаток: ${product.stock_qty} шт.\nМагазин: ${storeName}\n\nТребуется: заказать товар`;
    await sendTelegram(token, chatId, message);
  } catch (err) {
    console.error("[notify] Low stock alert failed:", err.message);
  }
}

export async function sendOversoldAlert(product) {
  try {
    const settings = await getSettings();
    if (settings.telegram_enabled !== "true") return;
    const token = settings.telegram_bot_token;
    const chatId = settings.telegram_chat_id;
    const storeName = settings.store_name || "Store";

    const message = `🚨 <b>Товар продан в минус</b>\n\nТовар: ${product.name}\nОстаток: ${product.stock_qty} (МИНУС)\nМагазин: ${storeName}\n\nТребуется: принять товар`;
    await sendTelegram(token, chatId, message);
  } catch (err) {
    console.error("[notify] Oversold alert failed:", err.message);
  }
}

export async function generateAISummary(data) {
  try {
    const settings = await getSettings();
    const apiKey = settings.anthropic_api_key;
    if (!apiKey) return null;

    const Anthropic = (await import("@anthropic-ai/sdk")).default;
    const client = new Anthropic({ apiKey });

    const msg = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 300,
      system: "You are a retail market analyst. Give concise, practical daily summaries in Russian. Focus on trends, anomalies, and one actionable tip.",
      messages: [{
        role: "user",
        content: `Analyze this POS daily data and give a brief market summary in Russian (3-5 sentences, practical insights):\n${JSON.stringify(data, null, 2)}`
      }],
    });

    return msg.content[0]?.text || null;
  } catch (err) {
    console.error("[ai-summary] Failed:", err.message);
    return null;
  }
}

export async function sendEODSummary() {
  try {
    const settings = await getSettings();
    if (settings.telegram_enabled !== "true") return;
    const token = settings.telegram_bot_token;
    const chatId = settings.telegram_chat_id;
    const storeName = settings.store_name || "Store";

    const today = new Date().toISOString().split("T")[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0];

    const { rows: summary } = await pool.query(
      `SELECT
        COUNT(*) as txn_count,
        COALESCE(SUM(total), 0) as net_sales,
        COALESCE(AVG(total), 0) as avg_txn
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided'`,
      [today],
    );

    const { rows: topProducts } = await pool.query(
      `SELECT p.name, SUM(ti.qty) as total_qty, SUM(ti.subtotal) as revenue
      FROM transaction_items ti
      JOIN products p ON p.id = ti.product_id
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE DATE(t.created_at) = $1 AND t.status != 'voided'
      GROUP BY p.id, p.name
      ORDER BY total_qty DESC
      LIMIT 5`,
      [today],
    );

    const { rows: paymentMethods } = await pool.query(
      `SELECT payment_method as method, COUNT(*) as count, COALESCE(SUM(total), 0) as total
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided'
      GROUP BY payment_method`,
      [today],
    );

    const { rows: refunds } = await pool.query(
      `SELECT COUNT(*) as count, COALESCE(SUM(total_refund_amount), 0) as total
      FROM refunds
      WHERE DATE(created_at) = $1`,
      [today],
    );

    const { rows: yesterdaySummary } = await pool.query(
      `SELECT COALESCE(SUM(total), 0) as net_sales
      FROM transactions
      WHERE DATE(created_at) = $1 AND status != 'voided'`,
      [yesterday],
    );

    const { rows: lowStock } = await pool.query(
      `SELECT name, stock_qty FROM products
      WHERE is_active = true AND stock_qty > 0 AND stock_qty <= $1
      ORDER BY stock_qty ASC LIMIT 5`,
      [parseInt(settings.low_stock_threshold) || 5],
    );

    const { rows: oversold } = await pool.query(
      `SELECT name, stock_qty FROM products
      WHERE is_active = true AND stock_qty < 0
      ORDER BY stock_qty ASC LIMIT 5`,
    );

    const s = summary[0];
    const r = refunds[0];
    const topList = topProducts
      .map((p, i) => `${i + 1}. ${p.name} (${p.total_qty} шт.)`)
      .join("\n");

    const paymentLines = paymentMethods
      .map((p) => {
        const icon = p.method === "cash" ? "💵" : p.method === "card" ? "💳" : "💰";
        return `  ${icon} ${p.method}: ${p.count} (${parseFloat(p.total).toFixed(2)})`;
      })
      .join("\n");

    let message =
      `📊 <b>Итог дня</b>\n\n` +
      `Магазин: ${storeName}\nДата: ${today}\n\n` +
      `Транзакций: ${s.txn_count}\n` +
      `Выручка: ${parseFloat(s.net_sales).toFixed(2)}\n` +
      `Средний чек: ${parseFloat(s.avg_txn).toFixed(2)}\n`;

    if (parseInt(r.count) > 0) {
      message += `Возвратов: ${r.count} (−${parseFloat(r.total).toFixed(2)})\n`;
    }

    if (paymentLines) {
      message += `\n<b>Оплата:</b>\n${paymentLines}\n`;
    }

    message += `\n<b>Топ товары:</b>\n${topList || "Продаж не было"}`;

    if (settings.ai_summary_enabled === "true") {
      const aiData = {
        date: today,
        storeName,
        txnCount: parseInt(s.txn_count),
        netSales: parseFloat(s.net_sales),
        avgTxn: parseFloat(s.avg_txn),
        topProducts: topProducts.map((p) => ({ name: p.name, qty: parseInt(p.total_qty), revenue: parseFloat(p.revenue) })),
        paymentMethods: paymentMethods.map((p) => ({ method: p.method, count: parseInt(p.count), total: parseFloat(p.total) })),
        refundCount: parseInt(r.count),
        refundTotal: parseFloat(r.total),
        lowStockItems: lowStock.map((p) => ({ name: p.name, stock_qty: p.stock_qty })),
        oversoldItems: oversold.map((p) => ({ name: p.name, stock_qty: p.stock_qty })),
        yesterdayNetSales: parseFloat(yesterdaySummary[0]?.net_sales || 0),
      };

      const aiText = await generateAISummary(aiData);
      if (aiText) {
        message += `\n\n🤖 <b>AI Анализ:</b>\n${aiText}`;
      }
    }

    await sendTelegram(token, chatId, message);
  } catch (err) {
    console.error("[notify] EOD summary failed:", err.message);
  }
}
