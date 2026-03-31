import cron from 'node-cron'
import { pool } from '../db/connection.js'
import { sendEODSummary } from './notificationService.js'
import { runBackupSafe } from './backupService.js'
import { pushToCloud } from './syncService.js'

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
    console.log('[cron] Running daily backup...')
    const result = await runBackupSafe()
    try {
      await pool.query(
        `INSERT INTO audit_log (action, actor_name, details) VALUES ('backup', 'system', $1::jsonb)`,
        [JSON.stringify(result)]
      )
    } catch (e) {
      console.error('[cron] Backup audit log failed:', e.message)
    }
  })

  console.log(`[cron] EOD summary scheduled at ${eodTime}`)

  // Push unsynced transactions to cloud every 5 minutes
  if (process.env.CLOUD_API_URL) {
    // Initial push after 30s (let DB settle on startup)
    setTimeout(async () => {
      try { await pushToCloud() } catch (e) { console.error('[sync] Initial push failed:', e.message) }
    }, 30_000)

    setInterval(async () => {
      try { await pushToCloud() } catch (e) { console.error('[sync] Scheduled push failed:', e.message) }
    }, 5 * 60 * 1000)

    console.log('[cron] Cloud sync scheduled every 5 minutes')
  }
}

export function stopCronJobs() {
  if (eodTask) eodTask.stop()
  if (backupTask) backupTask.stop()
}
