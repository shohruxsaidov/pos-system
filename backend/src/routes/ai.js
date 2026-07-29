import {
  runAssistant,
  getAssistantStatus,
  listModels,
} from "../services/aiService.js";
import { logAudit } from "../services/auditService.js";

const MANAGER_ROLES = ["manager", "admin"];

export default async function aiRoutes(fastify) {
  // GET /api/ai/status — lets the UI hide the assistant when no key is set
  fastify.get(
    "/api/ai/status",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!MANAGER_ROLES.includes(req.user.role)) {
        return reply.code(403).send({ error: "Manager or admin access required" });
      }
      return getAssistantStatus();
    },
  );

  // GET /api/ai/models — live catalogue from the Anthropic Models API, so the
  // Settings picker never ships a stale hardcoded model list.
  fastify.get(
    "/api/ai/models",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!MANAGER_ROLES.includes(req.user.role)) {
        return reply.code(403).send({ error: "Manager or admin access required" });
      }
      try {
        return await listModels();
      } catch (err) {
        req.log.error({ err }, "[ai] Model list failed");
        return reply
          .code(502)
          .send({ error: `Не удалось получить список моделей: ${err.message}` });
      }
    },
  );

  // POST /api/ai/chat — { messages: [{ role: 'user'|'assistant', content }] }
  fastify.post(
    "/api/ai/chat",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!MANAGER_ROLES.includes(req.user.role)) {
        return reply.code(403).send({ error: "Manager or admin access required" });
      }

      const { messages } = req.body || {};
      if (!Array.isArray(messages) || messages.length === 0) {
        return reply.code(400).send({ error: "messages array required" });
      }
      if (messages.length > 40) {
        return reply.code(400).send({ error: "Too many messages" });
      }
      for (const m of messages) {
        if (!m || (m.role !== "user" && m.role !== "assistant")) {
          return reply.code(400).send({ error: "Invalid message role" });
        }
        if (typeof m.content !== "string" || !m.content.trim()) {
          return reply.code(400).send({ error: "Message content must be a non-empty string" });
        }
      }
      if (messages[messages.length - 1].role !== "user") {
        return reply.code(400).send({ error: "Last message must be from the user" });
      }

      let result;
      try {
        result = await runAssistant({ messages, user: req.user });
      } catch (err) {
        req.log.error({ err }, "[ai] Assistant call failed");
        return reply.code(502).send({ error: `Ошибка AI: ${err.message}` });
      }

      if (!result.ok) {
        const errors = {
          no_api_key: [503, "Claude API ключ не настроен — добавьте его в Настройках."],
          refused: [200, "Не могу ответить на этот запрос."],
          max_iterations: [200, "Запрос оказался слишком сложным. Попробуйте спросить конкретнее."],
        };
        const [code, message] = errors[result.code] || [502, "AI недоступен."];
        if (code === 200) {
          return { reply: message, tools_used: result.tools_used || [] };
        }
        return reply.code(code).send({ error: message });
      }

      await logAudit({
        action: "ai_query",
        actor: req.user,
        details: {
          question: messages[messages.length - 1].content.slice(0, 500),
          tools_used: result.tools_used,
          usage: result.usage,
        },
        ip: req.ip,
      });

      return {
        reply: result.reply,
        tools_used: result.tools_used,
        usage: result.usage,
      };
    },
  );
}
