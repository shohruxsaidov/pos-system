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
    const apiKey = settings.claude_api_key;
    if (!apiKey) return null;

    const Anthropic = (await import("@anthropic-ai/sdk")).default;
    const client = new Anthropic({ apiKey });

    const message = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system: "You are a retail market analyst. Give concise, practical daily summaries in Russian. Focus on trends, anomalies, and one actionable tip.",
      messages: [
        {
          role: "user",
          content: `Analyze this POS daily data and give a brief market summary in Russian (3-5 sentences, practical insights):\n${JSON.stringify(data, null, 2)}`,
        },
      ],
    });

    return message.content[0]?.text || null;
  } catch (err) {
    console.error("[ai-summary] Failed:", err.message);
    return null;
  }
}

export async function sendStartupNotification() {
  try {
    const settings = await getSettings();
    if (settings.telegram_enabled !== "true") return;
    const token = settings.telegram_bot_token;
    const chatId = settings.telegram_chat_id;
    const storeName = settings.store_name || "Store";
    const time = new Date().toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });

    const message = `🟢 <b>Система запущена</b>\n\nМагазин: ${storeName}\nВремя: ${time}`;
    await sendTelegram(token, chatId, message);
  } catch (err) {
    console.error("[notify] Startup notification failed:", err.message);
  }
}

export async function sendShutdownNotification() {
  try {
    const settings = await getSettings();
    if (settings.telegram_enabled !== "true") return;
    const token = settings.telegram_bot_token;
    const chatId = settings.telegram_chat_id;
    const storeName = settings.store_name || "Store";
    const time = new Date().toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });

    const message = `🔴 <b>Система остановлена</b>\n\nМагазин: ${storeName}\nВремя: ${time}`;
    await sendTelegram(token, chatId, message);
  } catch (err) {
    console.error("[notify] Shutdown notification failed:", err.message);
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
      `SELECT p.name, SUM(ws.stock_qty) as stock_qty
      FROM products p JOIN warehouse_stock ws ON ws.product_id = p.id
      WHERE p.is_active = true
      GROUP BY p.id, p.name, p.low_stock_threshold
      HAVING SUM(ws.stock_qty) > 0 AND SUM(ws.stock_qty) <= p.low_stock_threshold
      ORDER BY SUM(ws.stock_qty) ASC LIMIT 5`
    );

    const { rows: oversold } = await pool.query(
      `SELECT p.name, SUM(ws.stock_qty) as stock_qty
      FROM products p JOIN warehouse_stock ws ON ws.product_id = p.id
      WHERE p.is_active = true
      GROUP BY p.id, p.name HAVING SUM(ws.stock_qty) < 0
      ORDER BY SUM(ws.stock_qty) ASC LIMIT 5`,
    );

    const { rows: incomingItems } = await pool.query(
      `SELECT ii.product_name, SUM(ii.qty_received) as qty_received
      FROM incoming_items ii
      JOIN incoming_receipts ir ON ir.id = ii.receipt_id
      WHERE DATE(ir.created_at) = $1
      GROUP BY ii.product_name
      ORDER BY qty_received DESC
      LIMIT 10`,
      [today],
    );

    const { rows: stockAdjustments } = await pool.query(
      `SELECT p.name, sa.delta, sa.reason
      FROM stock_adjustments sa
      JOIN products p ON p.id = sa.product_id
      WHERE DATE(sa.created_at) = $1
      ORDER BY sa.created_at DESC
      LIMIT 10`,
      [today],
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
        topProducts: topProducts.map((p) => ({ name: p.name, qty: parseInt(p.total_qty) })),
        paymentMethods: paymentMethods.map((p) => ({ method: p.method, count: parseInt(p.count) })),
        refundCount: parseInt(r.count),
        lowStockItems: lowStock.map((p) => ({ name: p.name, stock_qty: parseInt(p.stock_qty) })),
        oversoldItems: oversold.map((p) => ({ name: p.name, stock_qty: parseInt(p.stock_qty) })),
        incomingItems: incomingItems.map((p) => ({ name: p.product_name, qty_received: parseInt(p.qty_received) })),
        stockAdjustments: stockAdjustments.map((a) => ({ name: a.name, delta: parseInt(a.delta), reason: a.reason })),
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
