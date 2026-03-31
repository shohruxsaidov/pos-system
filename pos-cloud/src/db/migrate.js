import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { pool } from './connection.js'

const __dirname = dirname(fileURLToPath(import.meta.url))

export async function runMigrations() {
  const sql = readFileSync(join(__dirname, 'migrations/001_schema.sql'), 'utf8')
  await pool.query(sql)
  console.log('[db] Migrations applied')
}
