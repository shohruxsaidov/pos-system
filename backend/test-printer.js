// Quick printer test — run with: node test-printer.js
import { ThermalPrinter, PrinterTypes, CharacterSet } from 'node-thermal-printer'
import { open, unlink, writeFile } from 'fs/promises'
import { exec } from 'child_process'
import { promisify } from 'util'
import { tmpdir } from 'os'
import { join } from 'path'

const execAsync = promisify(exec)
const DEVICE = '//./USB001'
const tmpBin = join(tmpdir(), `pos-test-${Date.now()}.bin`)

// Build ESC/POS bytes to a temp file (this always works)
async function buildBytes(outPath) {
  const p = new ThermalPrinter({ type: PrinterTypes.EPSON, interface: outPath, characterSet: CharacterSet.PC852_LATIN2 })
  p.alignCenter()
  p.bold(true)
  p.println('=== TEST PRINT ===')
  p.bold(false)
  p.println(new Date().toLocaleString())
  p.println('Direct write test')
  p.cut()
  // Write bytes using the file interface (bypasses isPrinterConnected check)
  const buf = p.getBuffer()
  await writeFile(outPath, buf)
}

// ── Approach 1: fs.open + write directly to \\.\USB001 ────────────────────────
console.log('[1] Direct fs.open write to', DEVICE)
try {
  await buildBytes(tmpBin)
  const { readFile } = await import('fs/promises')
  const bytes = await readFile(tmpBin)

  const fd = await open(DEVICE, 'w')
  await fd.write(bytes)
  await fd.close()
  console.log('    SUCCESS — check printer!')
} catch (e) {
  console.log('    FAILED:', e.message, e.code)
}

// ── Approach 2: cmd copy /b to device path ─────────────────────────────────────
console.log('\n[2] cmd copy /b to device path \\\\.\\ USB001')
try {
  await buildBytes(tmpBin)
  const { stdout, stderr } = await execAsync(
    `cmd /c copy /b "${tmpBin}" \\\\.\\USB001`,
    { timeout: 8000 }
  )
  console.log('    stdout:', stdout.trim())
  if (stderr) console.log('    stderr:', stderr.trim())
  console.log('    SUCCESS — check printer!')
} catch (e) {
  console.log('    FAILED:', e.message?.split('\n')[0])
}

// ── Approach 3: share printer via wmic then copy /b ────────────────────────────
console.log('\n[3] Share printer + copy /b \\\\localhost\\POS')
try {
  await execAsync(`wmic printer where "Name='POSPrinter POS-80C'" set Shared=True,ShareName="POS"`, { timeout: 5000 })
  await buildBytes(tmpBin)
  const { stdout } = await execAsync(`cmd /c copy /b "${tmpBin}" "\\\\localhost\\POS"`, { timeout: 8000 })
  console.log('    stdout:', stdout.trim())
  console.log('    SUCCESS — check printer!')
  // unshare after printing
  await execAsync(`wmic printer where "Name='POSPrinter POS-80C'" set Shared=False`, { timeout: 5000 }).catch(() => {})
} catch (e) {
  console.log('    FAILED:', e.message?.split('\n')[0])
}

await unlink(tmpBin).catch(() => {})
