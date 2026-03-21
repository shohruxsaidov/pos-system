import { readdir, readFile } from 'fs/promises'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'
import { db } from './connection.js'
import argon from 'argon2'

const __dirname = dirname(fileURLToPath(import.meta.url))

export async function runMigrations() {
  // Create migrations tracking table
  db.exec(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      filename  TEXT UNIQUE NOT NULL,
      applied_at TEXT DEFAULT (datetime('now'))
    )
  `)

  const migrationsDir = join(__dirname, 'migrations')
  const files = await readdir(migrationsDir)
  const sqlFiles = files.filter(f => f.endsWith('.sql')).sort()

  for (const filename of sqlFiles) {
    const existing = db.prepare('SELECT id FROM _migrations WHERE filename = ?').get([filename])
    if (existing) {
      console.log(`[migrate] Skipping ${filename} (already applied)`)
      continue
    }

    console.log(`[migrate] Applying ${filename}...`)
    const sql = await readFile(join(migrationsDir, filename), 'utf8')

    const applyMigration = db.transaction(() => {
      db.exec(sql)
      db.prepare('INSERT INTO _migrations (filename) VALUES (?)').run([filename])
    })

    try {
      applyMigration()
      console.log(`[migrate] Applied ${filename}`)
    } catch (err) {
      throw new Error(`Migration ${filename} failed: ${err.message}`)
    }
  }

  console.log('[migrate] All migrations complete')
  await seedDefaultUsers()
}

async function seedDefaultUsers() {
  const { count } = db.prepare('SELECT COUNT(*) as count FROM users').get()
  if (count > 0) return

  console.log('[migrate] Seeding default users...')

  const defaultUsers = [
    { name: 'Admin',     pin: '1234', role: 'admin' },
    { name: 'Manager',   pin: '5678', role: 'manager' },
    { name: 'Cashier 1', pin: '1234', role: 'cashier' },
    { name: 'Warehouse', pin: '9999', role: 'warehouse' },
  ]

  db.prepare('INSERT OR IGNORE INTO warehouses (id, name) VALUES (1, ?)').run(['Main Warehouse'])

  const insertUser = db.prepare(
    'INSERT INTO users (name, pin_hash, role, is_active, warehouse_id) VALUES (?, ?, ?, 1, ?)'
  )

  for (const u of defaultUsers) {
    const hash = await argon.hash(u.pin)
    const warehouseId = u.role !== 'admin' ? 1 : null
    insertUser.run([u.name, hash, u.role, warehouseId])
    console.log(`[migrate] Created user: ${u.name} (${u.role}) PIN: ${u.pin}`)
  }
}
