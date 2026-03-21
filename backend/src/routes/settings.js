import argon from "argon2";
import { pool } from "../db/connection.js";
import { logAudit } from "../services/auditService.js";
import { getMobileUrl, getLocalIP } from "../services/networkService.js";
import { detectPrinter, printTestPage, detectBarcodePrinter, printBarcodeTestPage } from "../services/printService.js";

export default async function settingsRoutes(fastify) {
  // GET /api/settings
  fastify.get(
    "/api/settings",
    { onRequest: [fastify.authenticate] },
    async () => {
      const { rows } = await pool.query(
        "SELECT key, value FROM settings ORDER BY key",
      );
      return Object.fromEntries(rows.map((r) => [r.key, r.value]));
    },
  );

  // PUT /api/settings
  fastify.put(
    "/api/settings",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (req.user.role === "cashier") {
        return reply.code(403).send({ error: "Insufficient permissions" });
      }
      const updates = req.body;
      for (const [key, value] of Object.entries(updates)) {
        await pool.query(
          "INSERT INTO settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO UPDATE SET value=$2",
          [key, String(value)],
        );
      }
      await logAudit({
        action: "settings_change",
        actor: req.user,
        details: { keys: Object.keys(updates) },
        ip: req.ip,
      });
      return { success: true };
    },
  );

  // GET /api/settings/mobile-url
  fastify.get("/api/settings/mobile-url", async () => {
    return { url: getMobileUrl(), ip: getLocalIP() };
  });

  // POST /api/settings/printer-detect
  fastify.post(
    "/api/settings/printer-detect",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const result = await detectPrinter();
      if (!result.found) {
        return reply.code(404).send({ error: "Принтер не найден" });
      }
      return result;
    }
  );

  // POST /api/settings/printer-test
  fastify.post(
    "/api/settings/printer-test",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      try {
        await printTestPage()
        return { success: true }
      } catch (e) {
        return reply.code(500).send({ error: e.message })
      }
    }
  );

  // POST /api/settings/barcode-printer-detect
  fastify.post(
    "/api/settings/barcode-printer-detect",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      const result = await detectBarcodePrinter();
      if (!result.found) {
        return reply.code(404).send({ error: "Принтер не найден" });
      }
      return result;
    }
  );

  // POST /api/settings/barcode-printer-test
  fastify.post(
    "/api/settings/barcode-printer-test",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      try {
        await printBarcodeTestPage();
        return { success: true };
      } catch (e) {
        return reply.code(500).send({ error: e.message });
      }
    }
  );

  // GET /api/settings/users
  fastify.get(
    "/api/settings/users",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!["manager", "admin"].includes(req.user.role)) {
        return reply.code(403).send({ error: "Insufficient permissions" });
      }
      const { rows } = await pool.query(
        "SELECT id, name, role, is_active, warehouse_id FROM users ORDER BY name",
      );
      return rows;
    },
  );

  // POST /api/settings/users
  fastify.post(
    "/api/settings/users",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!["manager", "admin"].includes(req.user.role)) {
        return reply.code(403).send({ error: "Insufficient permissions" });
      }
      const { name, pin, role, warehouse_id } = req.body;
      if (!name || !pin || !role) {
        return reply.code(400).send({ error: "name, pin, role required" });
      }
      const pin_hash = await argon.hash(String(pin));
      const { rows } = await pool.query(
        "INSERT INTO users (name, pin_hash, role, warehouse_id) VALUES ($1,$2,$3,$4) RETURNING id, name, role, is_active, warehouse_id",
        [name, pin_hash, role, warehouse_id || null],
      );
      await logAudit({
        action: "user_create",
        actor: req.user,
        target: { type: "user", id: rows[0].id, name: rows[0].name },
        ip: req.ip,
      });
      return reply.code(201).send(rows[0]);
    },
  );

  // PUT /api/settings/users/:id
  fastify.put(
    "/api/settings/users/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (!["manager", "admin"].includes(req.user.role)) {
        return reply.code(403).send({ error: "Insufficient permissions" });
      }
      const { name, pin, role, is_active, warehouse_id } = req.body;
      const { rows: existing } = await pool.query(
        "SELECT * FROM users WHERE id=$1",
        [req.params.id],
      );
      if (!existing[0])
        return reply.code(404).send({ error: "User not found" });

      let pin_hash = existing[0].pin_hash;
      if (pin) pin_hash = await argon.hash(String(pin));

      const { rows } = await pool.query(
        "UPDATE users SET name=$1, pin_hash=$2, role=$3, is_active=$4, warehouse_id=$5 WHERE id=$6 RETURNING id, name, role, is_active, warehouse_id",
        [
          name ?? existing[0].name,
          pin_hash,
          role ?? existing[0].role,
          is_active ?? existing[0].is_active,
          warehouse_id !== undefined ? (warehouse_id || null) : existing[0].warehouse_id,
          req.params.id,
        ],
      );
      await logAudit({
        action: "user_edit",
        actor: req.user,
        target: { type: "user", id: rows[0].id, name: rows[0].name },
        ip: req.ip,
      });
      return rows[0];
    },
  );

  // DELETE /api/settings/users/:id
  fastify.delete(
    "/api/settings/users/:id",
    { onRequest: [fastify.authenticate] },
    async (req, reply) => {
      if (req.user.role !== "admin") {
        return reply.code(403).send({ error: "Admin only" });
      }
      if (parseInt(req.params.id) === req.user.id) {
        return reply.code(400).send({ error: "Cannot delete yourself" });
      }
      const { rows } = await pool.query(
        "UPDATE users SET is_active=false WHERE id=$1 RETURNING id, name",
        [req.params.id],
      );
      if (!rows[0]) return reply.code(404).send({ error: "User not found" });
      await logAudit({
        action: "user_delete",
        actor: req.user,
        target: { type: "user", id: rows[0].id, name: rows[0].name },
        ip: req.ip,
      });
      return { success: true };
    },
  );
}
