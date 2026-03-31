import 'dotenv/config'
import Fastify from 'fastify'
import fjwt from '@fastify/jwt'
import { runMigrations } from './db/migrate.js'
import syncRoutes from './routes/sync.js'
import healthRoutes from './routes/health.js'
import reportsRoutes from './routes/reports.js'

const fastify = Fastify({ logger: true })

fastify.register(fjwt, { secret: process.env.JWT_SECRET || 'change-this-jwt-secret' })

fastify.register(healthRoutes)
fastify.register(syncRoutes)
fastify.register(reportsRoutes)

const start = async () => {
  try {
    await runMigrations()
    await fastify.listen({ port: Number(process.env.PORT) || 3001, host: '0.0.0.0' })
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}

start()
