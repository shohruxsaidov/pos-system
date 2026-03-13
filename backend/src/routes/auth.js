import argon from "argon2";
import { pool } from "../db/connection.js";
import { logAudit } from "../services/auditService.js";

export default async function authRoutes(fastify) {
  fastify.post("/api/auth/login", async (req, reply) => {
    const { user_id, pin } = req.body || {};
    if (!user_id || !pin) {
      return reply.code(400).send({ error: "user_id and pin required" });
    }

    const { rows } = await pool.query(
      "SELECT * FROM users WHERE id=$1 AND is_active=true",
      [user_id],
    );
    const user = rows[0];
    if (!user) return reply.code(401).send({ error: "User not found" });

    const valid = await argon.verify(user.pin_hash, String(pin));
    if (!valid) return reply.code(401).send({ error: "Invalid PIN" });

    const token = fastify.jwt.sign(
      { id: user.id, name: user.name, role: user.role, warehouse_id: user.warehouse_id },
      { expiresIn: "12h" },
    );

    await logAudit({
      action: "login",
      actor: { id: user.id, name: user.name, role: user.role },
      ip: req.ip,
    });

    return { token, user: { id: user.id, name: user.name, role: user.role, warehouse_id: user.warehouse_id } };
  });

  fastify.get("/api/auth/users", async (req, reply) => {
    const { rows } = await pool.query(
      "SELECT id, name, role FROM users WHERE is_active=true ORDER BY name",
    );
    return rows;
  });
}
