import pg from 'pg'
import 'dotenv/config'

const { Pool } = pg

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://pos_user:strongpassword@localhost:5432/market_pos',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
})

pool.on('error', (err) => {
  console.error('Unexpected error on idle PostgreSQL client:', err)
})

export async function testConnection() {
  try {
    const client = await pool.connect()
    await client.query('SELECT NOW()')
    client.release()
    return true
  } catch (err) {
    console.error('Database connection failed:', err.message)
    return false
  }
}
