import { pool } from "../db/connection.js";

// The model and effort come from the settings table (seeded by migration 006 and
// editable in Settings). These constants are only a safety net if those rows are
// missing — never treat them as the configured model.
const FALLBACK_MODEL = "claude-opus-5";
const FALLBACK_EFFORT = "low";

export const EFFORT_LEVELS = ["low", "medium", "high", "xhigh", "max"];

const MAX_ITERATIONS = 8; // tool round-trips before we give up
const MAX_HISTORY = 20; // user/assistant turns kept from the client
const MAX_CHARS = 4000; // per message

async function getAiSettings() {
  const { rows } = await pool.query(
    "SELECT key, value FROM settings WHERE key IN ('claude_api_key','ai_model','ai_effort','store_name')",
  );
  const s = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return {
    apiKey: s.claude_api_key || "",
    model: s.ai_model || FALLBACK_MODEL,
    effort: EFFORT_LEVELS.includes(s.ai_effort) ? s.ai_effort : FALLBACK_EFFORT,
    storeName: s.store_name || "Магазин",
  };
}

/**
 * Reads effort support off a model's capabilities. Older models (Haiku 4.5,
 * Sonnet 4.5, Opus 4.1) reject output_config.effort with a 400, so this decides
 * whether we may send it at all.
 */
function readEffortCapability(info) {
  const e = info?.capabilities?.effort;
  if (!e?.supported) return { effort_supported: false, effort_levels: [] };
  const levels = EFFORT_LEVELS.filter((l) => e[l]?.supported);
  return {
    effort_supported: true,
    effort_levels: levels.length ? levels : EFFORT_LEVELS,
  };
}

// modelId → capability, cached for the process lifetime.
const capabilityCache = new Map();

async function getModelCapability(client, modelId) {
  if (capabilityCache.has(modelId)) return capabilityCache.get(modelId);
  let caps = { effort_supported: false, effort_levels: [] };
  try {
    caps = readEffortCapability(await client.models.retrieve(modelId));
  } catch (err) {
    // Omitting effort always works; sending it to a model that lacks support
    // does not. On a failed lookup, degrade to no effort rather than 400.
    console.error(`[ai] Capability lookup failed for ${modelId}:`, err.message);
  }
  capabilityCache.set(modelId, caps);
  return caps;
}

/** Live model list from the Anthropic API — no hardcoded catalogue. */
export async function listModels() {
  const { apiKey, model } = await getAiSettings();
  if (!apiKey) return { enabled: false, current: model, models: [] };

  const Anthropic = (await import("@anthropic-ai/sdk")).default;
  const client = new Anthropic({ apiKey });
  const page = await client.models.list({ limit: 50 });

  return {
    enabled: true,
    current: model,
    models: (page.data || []).map((m) => {
      const caps = readEffortCapability(m);
      capabilityCache.set(m.id, caps); // list already carries capabilities
      return {
        id: m.id,
        display_name: m.display_name || m.id,
        ...caps,
      };
    }),
  };
}

// ─── Date helpers ────────────────────────────────────────────────────────────

/**
 * UTC calendar date. created_at is stored as a UTC ISO string and SQLite's
 * DATE() truncates it in UTC, so day boundaries must be UTC to agree with the
 * Telegram bot and the reports screen.
 */
function isoDate(d) {
  return d.toISOString().split("T")[0];
}

function resolveRange(period, date) {
  const now = new Date();
  switch (period) {
    case "yesterday": {
      const d = new Date(now.getTime() - 86400000);
      return { from: isoDate(d), to: isoDate(d) };
    }
    case "week": {
      const d = new Date(now.getTime() - 6 * 86400000);
      return { from: isoDate(d), to: isoDate(now) };
    }
    case "month":
      return {
        from: isoDate(
          new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)),
        ),
        to: isoDate(now),
      };
    case "date": {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date || "")) {
        throw new Error("date must be provided as YYYY-MM-DD when period=date");
      }
      return { from: date, to: date };
    }
    case "today":
    default:
      return { from: isoDate(now), to: isoDate(now) };
  }
}

const PERIOD_SCHEMA = {
  period: {
    type: "string",
    enum: ["today", "yesterday", "week", "month", "date"],
    description:
      "Time range. 'week' = last 7 days, 'month' = current calendar month, 'date' = one specific day (requires date).",
  },
  date: {
    type: "string",
    description: "Specific day as YYYY-MM-DD. Only used when period='date'.",
  },
};

const num = (v) => parseFloat(v || 0);

// ─── Tool definitions ────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "get_sales",
    description:
      "Sales totals for a period: transaction count, net sales, average ticket, refunds, and a payment-method breakdown. Use for any 'how much did we sell' question.",
    input_schema: {
      type: "object",
      properties: PERIOD_SCHEMA,
      required: ["period"],
    },
  },
  {
    name: "get_stock",
    description:
      "Current stock levels across all warehouses. filter='oversold' returns items below zero, 'low' returns 0..5, 'all' returns everything lowest-first.",
    input_schema: {
      type: "object",
      properties: {
        filter: { type: "string", enum: ["oversold", "low", "all"] },
        limit: { type: "integer", description: "Max rows, default 20." },
      },
      required: ["filter"],
    },
  },
  {
    name: "get_top_products",
    description:
      "Best-selling products for a period, ranked by quantity sold, with revenue.",
    input_schema: {
      type: "object",
      properties: {
        ...PERIOD_SCHEMA,
        limit: { type: "integer", description: "Max rows, default 10." },
      },
      required: ["period"],
    },
  },
  {
    name: "get_cashiers",
    description:
      "Per-cashier breakdown for a period: transaction count and total sales.",
    input_schema: {
      type: "object",
      properties: PERIOD_SCHEMA,
      required: ["period"],
    },
  },
  {
    name: "get_refunds",
    description:
      "Individual refunds for a period with reference number, amount, reason and who processed them.",
    input_schema: {
      type: "object",
      properties: {
        ...PERIOD_SCHEMA,
        limit: { type: "integer", description: "Max rows, default 20." },
      },
      required: ["period"],
    },
  },
  {
    name: "get_transaction",
    description:
      "Full detail of one transaction by its reference number, including line items.",
    input_schema: {
      type: "object",
      properties: {
        ref_no: { type: "string", description: "Reference, e.g. TXN-20260729-0012" },
      },
      required: ["ref_no"],
    },
  },
  {
    name: "find_product",
    description:
      "Look up products by name fragment or barcode. Returns price, cost, unit and current stock. Use before answering questions about a specific product.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Name fragment or full barcode." },
        limit: { type: "integer", description: "Max rows, default 10." },
      },
      required: ["query"],
    },
  },
];

// ─── Tool executors ──────────────────────────────────────────────────────────

const clampLimit = (v, def, max = 50) =>
  Math.min(Math.max(parseInt(v) || def, 1), max);

const EXECUTORS = {
  async get_sales({ period, date }) {
    const { from, to } = resolveRange(period, date);
    const { rows: totals } = await pool.query(
      `SELECT COUNT(*) AS txn_count, COALESCE(SUM(total),0) AS net_sales,
              COALESCE(AVG(total),0) AS avg_txn
       FROM transactions
       WHERE DATE(created_at) BETWEEN $1 AND $2 AND status != 'voided'`,
      [from, to],
    );
    const { rows: methods } = await pool.query(
      `SELECT payment_method AS method, COUNT(*) AS count, COALESCE(SUM(total),0) AS total
       FROM transactions
       WHERE DATE(created_at) BETWEEN $1 AND $2 AND status != 'voided'
       GROUP BY payment_method ORDER BY total DESC`,
      [from, to],
    );
    const { rows: refunds } = await pool.query(
      `SELECT COUNT(*) AS count, COALESCE(SUM(total_refund_amount),0) AS total
       FROM refunds WHERE DATE(created_at) BETWEEN $1 AND $2`,
      [from, to],
    );
    return {
      from,
      to,
      txn_count: parseInt(totals[0].txn_count),
      net_sales: num(totals[0].net_sales),
      avg_txn: num(totals[0].avg_txn),
      refund_count: parseInt(refunds[0].count),
      refund_total: num(refunds[0].total),
      payment_methods: methods.map((m) => ({
        method: m.method,
        count: parseInt(m.count),
        total: num(m.total),
      })),
    };
  },

  async get_stock({ filter, limit }) {
    const having =
      filter === "oversold"
        ? "HAVING SUM(ws.stock_qty) < 0"
        : filter === "low"
          ? "HAVING SUM(ws.stock_qty) >= 0 AND SUM(ws.stock_qty) <= 5"
          : "";
    const { rows } = await pool.query(
      `SELECT p.name, p.barcode, p.unit, SUM(ws.stock_qty) AS stock_qty
       FROM products p JOIN warehouse_stock ws ON ws.product_id = p.id
       WHERE p.is_active = true
       GROUP BY p.id, p.name, p.barcode, p.unit
       ${having}
       ORDER BY SUM(ws.stock_qty) ASC
       LIMIT $1`,
      [clampLimit(limit, 20)],
    );
    return {
      filter,
      count: rows.length,
      items: rows.map((r) => ({
        name: r.name,
        barcode: r.barcode,
        unit: r.unit,
        stock_qty: num(r.stock_qty),
      })),
    };
  },

  async get_top_products({ period, date, limit }) {
    const { from, to } = resolveRange(period, date);
    const { rows } = await pool.query(
      `SELECT p.name, SUM(ti.qty) AS qty, SUM(ti.subtotal) AS revenue
       FROM transaction_items ti
       JOIN products p ON p.id = ti.product_id
       JOIN transactions t ON t.id = ti.transaction_id
       WHERE DATE(t.created_at) BETWEEN $1 AND $2 AND t.status != 'voided'
       GROUP BY p.id, p.name ORDER BY qty DESC LIMIT $3`,
      [from, to, clampLimit(limit, 10)],
    );
    return {
      from,
      to,
      products: rows.map((r) => ({
        name: r.name,
        qty: num(r.qty),
        revenue: num(r.revenue),
      })),
    };
  },

  async get_cashiers({ period, date }) {
    const { from, to } = resolveRange(period, date);
    const { rows } = await pool.query(
      `SELECT u.name, COUNT(t.id) AS count, COALESCE(SUM(t.total),0) AS total
       FROM transactions t JOIN users u ON u.id = t.cashier_id
       WHERE DATE(t.created_at) BETWEEN $1 AND $2 AND t.status != 'voided'
       GROUP BY u.id, u.name ORDER BY total DESC`,
      [from, to],
    );
    return {
      from,
      to,
      cashiers: rows.map((r) => ({
        name: r.name,
        txn_count: parseInt(r.count),
        total: num(r.total),
      })),
    };
  },

  async get_refunds({ period, date, limit }) {
    const { from, to } = resolveRange(period, date);
    const { rows } = await pool.query(
      `SELECT r.ref_no, r.total_refund_amount, r.reason, r.refund_type,
              r.created_at, u.name AS processed_by
       FROM refunds r LEFT JOIN users u ON u.id = r.processed_by
       WHERE DATE(r.created_at) BETWEEN $1 AND $2
       ORDER BY r.created_at DESC LIMIT $3`,
      [from, to, clampLimit(limit, 20)],
    );
    return {
      from,
      to,
      refunds: rows.map((r) => ({
        ref_no: r.ref_no,
        amount: num(r.total_refund_amount),
        reason: r.reason,
        type: r.refund_type,
        processed_by: r.processed_by,
        created_at: r.created_at,
      })),
    };
  },

  async get_transaction({ ref_no }) {
    const { rows } = await pool.query(
      `SELECT t.*, u.name AS cashier_name, c.name AS customer_name
       FROM transactions t
       LEFT JOIN users u ON u.id = t.cashier_id
       LEFT JOIN customers c ON c.id = t.customer_id
       WHERE t.ref_no = $1`,
      [ref_no],
    );
    if (!rows[0]) return { found: false, ref_no };
    const t = rows[0];
    const { rows: items } = await pool.query(
      `SELECT p.name, ti.qty, ti.unit_price, ti.discount, ti.subtotal
       FROM transaction_items ti JOIN products p ON p.id = ti.product_id
       WHERE ti.transaction_id = $1`,
      [t.id],
    );
    return {
      found: true,
      ref_no: t.ref_no,
      cashier: t.cashier_name,
      customer: t.customer_name,
      subtotal: num(t.subtotal),
      discount: num(t.discount),
      total: num(t.total),
      payment_method: t.payment_method,
      status: t.status,
      created_at: t.created_at,
      items: items.map((i) => ({
        name: i.name,
        qty: num(i.qty),
        unit_price: num(i.unit_price),
        discount: num(i.discount),
        subtotal: num(i.subtotal),
      })),
    };
  },

  async find_product({ query, limit }) {
    const { rows } = await pool.query(
      // Stock via subquery, barcode via EXISTS — joining both tables would
      // multiply stock_qty by the number of alternate barcodes.
      `SELECT p.name, p.barcode, p.price, p.cost, p.unit,
              COALESCE((SELECT SUM(ws.stock_qty) FROM warehouse_stock ws
                        WHERE ws.product_id = p.id), 0) AS stock_qty
       FROM products p
       WHERE p.is_active = true
         AND (p.name ILIKE $1
              OR p.barcode = $2
              OR EXISTS (SELECT 1 FROM product_barcodes pb
                         WHERE pb.product_id = p.id AND pb.barcode = $2))
       ORDER BY p.name LIMIT $3`,
      [`%${query}%`, query, clampLimit(limit, 10)],
    );
    return {
      query,
      products: rows.map((r) => ({
        name: r.name,
        barcode: r.barcode,
        price: num(r.price),
        cost: num(r.cost),
        unit: r.unit,
        stock_qty: num(r.stock_qty),
      })),
    };
  },
};

// ─── Assistant loop ──────────────────────────────────────────────────────────

function systemPrompt({ storeName, user }) {
  const now = new Date();
  return [
    `Ты — ассистент владельца магазина «${storeName}» в POS-системе.`,
    `Сегодня ${isoDate(now)}. Собеседник: ${user.name} (роль: ${user.role}).`,
    "",
    "Правила:",
    "- Отвечай всегда по-русски, коротко и по делу. Обычно 1–4 предложения.",
    "- Никогда не выдумывай цифры. Любые данные о продажах, остатках, кассирах и товарах бери только через инструменты.",
    "- Если вопрос требует нескольких срезов данных — вызывай несколько инструментов, затем дай единый ответ.",
    "- Суммы пиши числом без символа валюты, разряды через пробел: 1 250 000.00",
    "- Отрицательный остаток означает, что товар продан в минус — это проблема, отмечай её.",
    "- Если данных нет, так и скажи. Не заполняй пробелы догадками.",
    "- Не выводи сырой JSON и не описывай, какие инструменты ты вызвал — сразу давай результат.",
    "- Если вопрос не про магазин, вежливо верни разговор к работе магазина.",
  ].join("\n");
}

function textOf(res) {
  return (res.content || [])
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("\n")
    .trim();
}

/**
 * Runs the tool-use loop against Claude and returns the final Russian answer.
 * `messages` is plain {role, content} text history from the client — tool_use
 * blocks live only inside this call and are not round-tripped to the client.
 */
export async function runAssistant({ messages, user }) {
  const { apiKey, model, effort, storeName } = await getAiSettings();
  if (!apiKey) {
    return { ok: false, code: "no_api_key" };
  }

  const Anthropic = (await import("@anthropic-ai/sdk")).default;
  const client = new Anthropic({ apiKey });

  const convo = messages.slice(-MAX_HISTORY).map((m) => ({
    role: m.role,
    content: String(m.content).slice(0, MAX_CHARS),
  }));

  const toolsUsed = [];
  let inputTokens = 0;
  let outputTokens = 0;

  // Only send effort to models that accept it — others 400 on the parameter.
  const caps = await getModelCapability(client, model);
  const effortToUse =
    caps.effort_supported && caps.effort_levels.includes(effort) ? effort : null;

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    const res = await client.messages.create({
      model,
      max_tokens: 8000,
      ...(effortToUse ? { output_config: { effort: effortToUse } } : {}),
      system: systemPrompt({ storeName, user }),
      tools: TOOLS,
      messages: convo,
    });

    inputTokens += res.usage?.input_tokens || 0;
    outputTokens += res.usage?.output_tokens || 0;

    if (res.stop_reason === "refusal") {
      return { ok: false, code: "refused" };
    }

    if (res.stop_reason !== "tool_use") {
      return {
        ok: true,
        reply: textOf(res) || "Не удалось сформировать ответ.",
        tools_used: toolsUsed,
        usage: { input_tokens: inputTokens, output_tokens: outputTokens },
      };
    }

    // Echo the assistant turn back verbatim — thinking blocks must survive.
    convo.push({ role: "assistant", content: res.content });

    const results = [];
    for (const block of res.content) {
      if (block.type !== "tool_use") continue;
      toolsUsed.push(block.name);
      let output;
      let isError = false;
      try {
        const executor = EXECUTORS[block.name];
        if (!executor) throw new Error(`Unknown tool: ${block.name}`);
        output = await executor(block.input || {});
      } catch (err) {
        console.error(`[ai] Tool ${block.name} failed:`, err.message);
        output = { error: err.message };
        isError = true;
      }
      results.push({
        type: "tool_result",
        tool_use_id: block.id,
        content: JSON.stringify(output),
        is_error: isError,
      });
    }
    convo.push({ role: "user", content: results });
  }

  return { ok: false, code: "max_iterations", tools_used: toolsUsed };
}

export async function getAssistantStatus() {
  const { apiKey, model, effort } = await getAiSettings();
  return { enabled: !!apiKey, model, effort, effort_levels: EFFORT_LEVELS };
}
