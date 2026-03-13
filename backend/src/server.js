import 'dotenv/config'
import { dirname, join } from 'path'
import { fileURLToPath } from 'url'
import Fastify from 'fastify'
import cors from '@fastify/cors'
import jwt from '@fastify/jwt'
import websocket from '@fastify/websocket'
import staticFiles from '@fastify/static'
import multipart from '@fastify/multipart'

import { runMigrations } from './db/migrate.js'
import { testConnection } from './db/connection.js'
import { setFastify, broadcastStatus } from './services/statusService.js'
import { startCronJobs } from './services/cronService.js'
import { startBot, stopBot } from './services/botService.js'

// Route imports
import authRoutes from './routes/auth.js'
import productRoutes from './routes/products.js'
import transactionRoutes from './routes/transactions.js'
import refundRoutes from './routes/refunds.js'
import reportRoutes from './routes/reports.js'
import customerRoutes from './routes/customers.js'
import categoryRoutes from './routes/categories.js'
import settingsRoutes from './routes/settings.js'
import incomingRoutes from './routes/incoming.js'
import inventoryRoutes from './routes/inventory.js'
import barcodeRoutes from './routes/barcode.js'
import auditRoutes from './routes/audit.js'
import syncRoutes from './routes/sync.js'
import notificationRoutes from './routes/notifications.js'
import statusRoutes from './routes/status.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const PORT = parseInt(process.env.PORT || '3000')
const JWT_SECRET = process.env.JWT_SECRET || 'pos-secret-key-change-in-production'

const fastify = Fastify({
  logger: {
    level: process.env.NODE_ENV === 'production' ? 'warn' : 'info'
  },
  trustProxy: true
})

// CORS
await fastify.register(cors, {
  origin: true,
  credentials: true
})

// JWT
await fastify.register(jwt, { secret: JWT_SECRET })

// Decorator for authentication
fastify.decorate('authenticate', async function (req, reply) {
  try {
    await req.jwtVerify()
  } catch (err) {
    reply.code(401).send({ error: 'Unauthorized' })
  }
})

// WebSocket support
await fastify.register(websocket)

// Multipart for file uploads
await fastify.register(multipart, {
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB
})

// Serve mobile SPA
const mobileDist = join(__dirname, '../../pos-mobile/dist')
try {
  await fastify.register(staticFiles, {
    root: mobileDist,
    prefix: '/mobile',
    decorateReply: false
  })
  fastify.get('/mobile/*', (req, reply) => {
    reply.sendFile('index.html', mobileDist)
  })
} catch (e) {
  fastify.log.warn('pos-mobile/dist not found — run: cd pos-mobile && npm run build')
}

// Register all routes
await fastify.register(authRoutes)
await fastify.register(productRoutes)
await fastify.register(transactionRoutes)
await fastify.register(refundRoutes)
await fastify.register(reportRoutes)
await fastify.register(customerRoutes)
await fastify.register(categoryRoutes)
await fastify.register(settingsRoutes)
await fastify.register(incomingRoutes)
await fastify.register(inventoryRoutes)
await fastify.register(barcodeRoutes)
await fastify.register(auditRoutes)
await fastify.register(syncRoutes)
await fastify.register(notificationRoutes)
await fastify.register(statusRoutes)

// Health check
fastify.get('/health', async () => ({
  status: 'ok',
  uptime: process.uptime(),
  timestamp: new Date().toISOString()
}))

// Startup
fastify.addHook('onReady', async () => {
  // Heartbeat broadcast every 5 seconds
  setInterval(() => {
    broadcastStatus().catch(() => {})
  }, 5000)

  // Start Telegram bot (async, non-blocking)
  startBot().catch(err => fastify.log.error('Bot error:', err))

  // Start cron jobs
  await startCronJobs()
})

fastify.addHook('onClose', async () => {
  stopBot()
})

// Main startup
async function start() {
  try {
    // Test DB connection
    const dbOk = await testConnection()
    if (!dbOk) {
      console.error('[server] Cannot connect to database. Check DATABASE_URL in .env')
      process.exit(1)
    }

    // Run migrations
    await runMigrations()

    setFastify(fastify)

    await fastify.listen({ port: PORT, host: '0.0.0.0' })
    console.log(`[server] POS Backend running at http://0.0.0.0:${PORT}`)
    console.log(`[server] Mobile UI: http://0.0.0.0:${PORT}/mobile`)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}

start()
