import Database from 'better-sqlite3'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import 'dotenv/config'

const __dirname = dirname(fileURLToPath(import.meta.url))
const dbPath = process.env.DB_PATH || join(__dirname, '../../pos.db')

export const db = new Database(dbPath)
db.pragma('journal_mode = WAL')
db.pragma('foreign_keys = ON')
db.pragma('busy_timeout = 5000')

// Serialize a parameter value for SQLite
function serializeParam(v) {
  if (v === null || v === undefined) return null
  if (v instanceof Date) return v.toISOString()
  if (typeof v === 'boolean') return v ? 1 : 0
  return v
}

// Attempt to JSON-parse string values that look like objects/arrays
function parseJsonValues(row) {
  if (!row || typeof row !== 'object') return row
  const result = {}
  for (const [key, value] of Object.entries(row)) {
    if (typeof value === 'string') {
      const t = value.trim()
      if (t.startsWith('{') || t.startsWith('[')) {
        try { result[key] = JSON.parse(value); continue } catch {}
      }
    }
    result[key] = value
  }
  return result
}

// Convert a PostgreSQL-style query to SQLite
function convertQuery(sql, params = []) {
  const newParams = []
  let converted = sql
    // $1, $2... → ? (with param expansion to handle repeated $N)
    .replace(/\$(\d+)/g, (_, n) => {
      newParams.push(serializeParam(params[parseInt(n, 10) - 1]))
      return '?'
    })
    // PostgreSQL-only constructs → SQLite equivalents
    .replace(/\bNOW\(\)/gi, "datetime('now')")
    .replace(/\bILIKE\b/gi, 'LIKE')
    .replace(/::(\w+)/g, '')
    .replace(/\bIS NOT DISTINCT FROM\b/gi, 'IS')
    .replace(/\bIS DISTINCT FROM\b/gi, 'IS NOT')
    .replace(/EXTRACT\s*\(\s*HOUR\s+FROM\s+(\w+)\)/gi, (_, col) => `CAST(strftime('%H', ${col}) AS INTEGER)`)

  return { sql: converted, params: newParams }
}

function execQuery(sql, params = []) {
  const { sql: sqliteSQL, params: sqliteParams } = convertQuery(sql, params)
  const upper = sqliteSQL.trim().toUpperCase()
  const hasReturning = /\bRETURNING\b/i.test(sqliteSQL)
  const isRead = upper.startsWith('SELECT') || upper.startsWith('WITH') || upper.startsWith('PRAGMA')

  const stmt = db.prepare(sqliteSQL)

  if (isRead || hasReturning) {
    const rows = stmt.all(sqliteParams).map(parseJsonValues)
    return { rows, rowCount: rows.length }
  } else {
    const info = stmt.run(sqliteParams)
    return { rows: [], rowCount: info.changes }
  }
}

// pg-compatible pool interface — routes use pool.query() and pool.connect() unchanged
export const pool = {
  query: async (sql, params = []) => execQuery(sql, params),

  connect: async () => ({
    query: async (sql, params = []) => {
      const trimmed = sql.trim().toUpperCase()
      if (trimmed === 'BEGIN')    { db.exec('BEGIN');    return { rows: [] } }
      if (trimmed === 'COMMIT')   { db.exec('COMMIT');   return { rows: [] } }
      if (trimmed === 'ROLLBACK') { db.exec('ROLLBACK'); return { rows: [] } }
      return execQuery(sql, params)
    },
    release: () => {}
  })
}

export async function testConnection() {
  try {
    db.prepare('SELECT 1').get()
    return true
  } catch (err) {
    console.error('Database connection failed:', err.message)
    return false
  }
}
