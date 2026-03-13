import { readdir, readFile } from "fs/promises";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { pool } from "./connection.js";
import argon from "argon2";

const __dirname = dirname(fileURLToPath(import.meta.url));

export async function runMigrations() {
  const client = await pool.connect();
  try {
    // Create migrations tracking table
    await client.query(`
      CREATE TABLE IF NOT EXISTS _migrations (
        id SERIAL PRIMARY KEY,
        filename TEXT UNIQUE NOT NULL,
        applied_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);

    const migrationsDir = join(__dirname, "migrations");
    const files = await readdir(migrationsDir);
    const sqlFiles = files.filter((f) => f.endsWith(".sql")).sort();

    for (const filename of sqlFiles) {
      const { rows } = await client.query(
        "SELECT id FROM _migrations WHERE filename = $1",
        [filename],
      );
      if (rows.length > 0) {
        console.log(`[migrate] Skipping ${filename} (already applied)`);
        continue;
      }

      console.log(`[migrate] Applying ${filename}...`);
      const sql = await readFile(join(migrationsDir, filename), "utf8");

      await client.query("BEGIN");
      try {
        await client.query(sql);
        await client.query("INSERT INTO _migrations (filename) VALUES ($1)", [
          filename,
        ]);
        await client.query("COMMIT");
        console.log(`[migrate] Applied ${filename}`);
      } catch (err) {
        await client.query("ROLLBACK");
        throw new Error(`Migration ${filename} failed: ${err.message}`);
      }
    }

    console.log("[migrate] All migrations complete");

    // Seed default users if none exist
    await seedDefaultUsers(client);
  } finally {
    client.release();
  }
}

async function seedDefaultUsers(client) {
  const { rows } = await client.query("SELECT COUNT(*) FROM users");
  if (parseInt(rows[0].count) > 0) return;

  console.log("[migrate] Seeding default users...");

  const defaultUsers = [
    { name: "Admin", pin: "1234", role: "admin" },
    { name: "Manager", pin: "5678", role: "manager" },
    { name: "Cashier 1", pin: "1234", role: "cashier" },
    { name: "Warehouse", pin: "9999", role: "warehouse" },
  ];

  // Ensure warehouse 1 exists before seeding users
  await client.query(
    "INSERT INTO warehouses (id, name) VALUES (1, 'Main Warehouse') ON CONFLICT (id) DO NOTHING"
  );

  for (const u of defaultUsers) {
    const hash = await argon.hash(u.pin);
    const result = await argon.verify(hash, u.pin);
    console.log(`Hashing PIN for ${u.name}:(verification: ${result})`);
    const warehouseId = u.role !== 'admin' ? 1 : null;
    await client.query(
      "INSERT INTO users (name, pin_hash, role, is_active, warehouse_id) VALUES ($1,$2,$3,true,$4)",
      [u.name, hash, u.role, warehouseId],
    );
    console.log(`[migrate] Created user: ${u.name} (${u.role}) PIN: ${u.pin}`);
  }
}
