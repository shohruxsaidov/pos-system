import cron from 'node-cron'
import { pool } from '../db/connection.js'
import { sendEODSummary } from './notificationService.js'

let eodTask = null
let backupTask = null

export async function startCronJobs() {
  // Load EOD time from settings
  let eodTime = '23:00'
  try {
    const { rows } = await pool.query("SELECT value FROM settings WHERE key = 'eod_time'")
    if (rows[0]?.value) eodTime = rows[0].value
  } catch (e) {
    console.error('[cron] Failed to load EOD time:', e.message)
  }

  const [hour, minute] = eodTime.split(':').map(Number)

  // Schedule EOD summary
  if (eodTask) eodTask.stop()
  eodTask = cron.schedule(`${minute || 0} ${hour || 23} * * *`, async () => {
    console.log('[cron] Running EOD summary...')
    await sendEODSummary()
  })

  // Daily backup at 23:59
  if (backupTask) backupTask.stop()
  backupTask = cron.schedule('59 23 * * *', async () => {
    console.log('[cron] Running daily backup (pg_dump)...')
    // Backup logic would call pg_dump here in production
    // For now just log
    try {
      await pool.query(
        `INSERT INTO audit_log (action, actor_name, details) VALUES ('backup', 'system', '{"status":"scheduled"}'::jsonb)`
      )
    } catch (e) {
      console.error('[cron] Backup log failed:', e.message)
    }
  })

  console.log(`[cron] EOD summary scheduled at ${eodTime}`)
}

export function stopCronJobs() {
  if (eodTask) eodTask.stop()
  if (backupTask) backupTask.stop()
}
