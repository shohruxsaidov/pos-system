import { createReadStream } from 'fs'
import { createGzip } from 'zlib'
import { dirname, join } from 'path'
import { fileURLToPath } from 'url'
import { S3Client, HeadBucketCommand, CreateBucketCommand } from '@aws-sdk/client-s3'
import { Upload } from '@aws-sdk/lib-storage'

const __dirname = dirname(fileURLToPath(import.meta.url))

const DB_PATH = process.env.DB_PATH || join(__dirname, '../../pos.db')
const MINIO_ENDPOINT = process.env.BACKUP_ENDPOINT || 'http://46.224.27.161:9000'
const MINIO_ACCESS_KEY = process.env.BACKUP_ACCESS_KEY || 'minioadmin'
const MINIO_SECRET_KEY = process.env.BACKUP_SECRET_KEY || 'minioadmin'
const MINIO_BUCKET = process.env.BACKUP_BUCKET || 'pos-backup'

const s3 = new S3Client({
  endpoint: MINIO_ENDPOINT,
  region: 'us-east-1',
  credentials: {
    accessKeyId: MINIO_ACCESS_KEY,
    secretAccessKey: MINIO_SECRET_KEY,
  },
  forcePathStyle: true,
})

async function ensureBucket() {
  try {
    await s3.send(new HeadBucketCommand({ Bucket: MINIO_BUCKET }))
  } catch {
    await s3.send(new CreateBucketCommand({ Bucket: MINIO_BUCKET }))
    console.log(`[backup] Created bucket: ${MINIO_BUCKET}`)
  }
}

export async function runBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
  const filename = `backup-${timestamp}.db.gz`

  console.log(`[backup] Uploading ${DB_PATH} → ${MINIO_BUCKET}/${filename}`)

  const fileStream = createReadStream(DB_PATH)
  const gzip = createGzip()
  const compressed = fileStream.pipe(gzip)

  const upload = new Upload({
    client: s3,
    params: {
      Bucket: MINIO_BUCKET,
      Key: filename,
      Body: compressed,
      ContentType: 'application/gzip',
    },
  })

  await upload.done()
  console.log(`[backup] Done: ${filename}`)
  return filename
}

export async function runBackupSafe() {
  try {
    await ensureBucket()
    const filename = await runBackup()
    return { success: true, filename }
  } catch (err) {
    console.error('[backup] Backup failed:', err.message)
    return { success: false, error: err.message }
  }
}
