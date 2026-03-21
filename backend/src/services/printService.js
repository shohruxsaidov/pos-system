import { exec } from 'child_process'
import { promisify } from 'util'
import { writeFile, unlink } from 'fs/promises'
import { tmpdir } from 'os'
import { join } from 'path'
import bwipjs from 'bwip-js'
import { ThermalPrinter, PrinterTypes, CharacterSet } from 'node-thermal-printer'
import { pool } from '../db/connection.js'

const execAsync = promisify(exec)

// Fixed Windows share name used for raw ESC/POS printing
const WINDOWS_SHARE = 'POSPrint'

// ── Settings ──────────────────────────────────────────────────────────────────

async function getStoreName() {
  const { rows } = await pool.query(`SELECT value FROM settings WHERE key = 'store_name'`)
  return rows[0]?.value || 'Store'
}

async function getPrinterConfig() {
  const { rows } = await pool.query(
    `SELECT key, value FROM settings WHERE key IN ('printer_type', 'printer_address', 'printer_paper_width')`
  )
  const map = Object.fromEntries(rows.map(r => [r.key, r.value]))
  return {
    type: map.printer_type === 'STAR' ? PrinterTypes.STAR : PrinterTypes.EPSON,
    address: map.printer_address || '',
    paperWidth: map.printer_paper_width || '58mm'
  }
}

async function getBarcodePrinterConfig() {
  const { rows } = await pool.query(
    `SELECT key, value FROM settings WHERE key IN ('barcode_printer_type', 'barcode_printer_address', 'barcode_printer_paper_width')`
  )
  const map = Object.fromEntries(rows.map(r => [r.key, r.value]))
  return {
    type: map.barcode_printer_type === 'STAR' ? PrinterTypes.STAR : PrinterTypes.EPSON,
    address: map.barcode_printer_address || '',
    paperWidth: map.barcode_printer_paper_width || '58mm'
  }
}

async function savePrinterAddress(address) {
  await pool.query(
    `INSERT INTO settings (key, value) VALUES ('printer_address', $1)
     ON CONFLICT (key) DO UPDATE SET value=$1`,
    [address]
  )
}

async function saveBarcodePrinterAddress(address) {
  await pool.query(
    `INSERT INTO settings (key, value) VALUES ('barcode_printer_address', $1)
     ON CONFLICT (key) DO UPDATE SET value=$1`,
    [address]
  )
}

// ── Windows: share printer so copy /b works ───────────────────────────────────

async function ensureWindowsPrinterShared(printerName) {
  try {
    await execAsync(
      `wmic printer where "Name='${printerName}'" set Shared=True,ShareName="${WINDOWS_SHARE}"`,
      { timeout: 5000 }
    )
  } catch { /* ignore — may already be shared */ }
}

// ── Detection ─────────────────────────────────────────────────────────────────

async function detectPrinterWindows() {
  try {
    const { stdout } = await execAsync(
      'wmic printer get Name,PortName /format:csv',
      { timeout: 5000 }
    )
    for (const line of stdout.split('\n')) {
      const parts = line.split(',')
      if (parts.length < 3) continue
      const name = parts[1]?.trim().replace(/\r/g, '')
      const portName = parts[2]?.trim().replace(/\r/g, '')
      if (portName && /^(USB|LPT|COM)\d+$/i.test(portName) && name) {
        await ensureWindowsPrinterShared(name)
        return `winshare:${name}`
      }
    }
  } catch { /* wmic not available */ }
  return null
}

async function detectPrinterUnix() {
  try {
    const { stdout } = await execAsync('lpstat -p', { timeout: 5000 })
    for (const line of stdout.trim().split('\n')) {
      const match = line.match(/^printer\s+(\S+)\s+is\s+(idle|printing|ready|enabled)/)
      if (match) return `cups:${match[1]}`
    }
  } catch { /* lpstat not available */ }

  for (const path of ['/dev/usb/lp0', '/dev/usb/lp1', '/dev/ttyUSB0']) {
    try {
      const { stdout } = await execAsync(`test -e ${path} && echo exists`, { timeout: 2000 })
      if (stdout.includes('exists')) return path
    } catch { /* skip */ }
  }
  return null
}

export async function detectPrinter() {
  const address = process.platform === 'win32'
    ? await detectPrinterWindows()
    : await detectPrinterUnix()

  if (!address) return { found: false }

  await savePrinterAddress(address)
  return { found: true, address }
}

export async function detectBarcodePrinter() {
  const address = process.platform === 'win32'
    ? await detectPrinterWindows()
    : await detectPrinterUnix()

  if (!address) return { found: false }

  await saveBarcodePrinterAddress(address)
  return { found: true, address }
}

// ── Status ────────────────────────────────────────────────────────────────────

async function checkCupsPrinter(name) {
  try {
    const { stdout } = await execAsync(`lpstat -p ${name}`, { timeout: 3000 })
    return { connected: /is idle|is printing|is ready|enabled/.test(stdout) }
  } catch {
    return { connected: false }
  }
}

async function checkWindowsPrinterByName(printerName) {
  try {
    const { stdout } = await execAsync(
      `wmic printer where "Name='${printerName}'" get PrinterStatus /format:value`,
      { timeout: 5000 }
    )
    const match = stdout.match(/PrinterStatus=(\d+)/i)
    if (match && parseInt(match[1]) >= 1) return { connected: true }
  } catch { /* skip */ }
  return { connected: false }
}

async function checkRawPrinter(address, type) {
  try {
    const printer = new ThermalPrinter({ type, interface: address, characterSet: CharacterSet.PC852_LATIN2 })
    const connected = await printer.isPrinterConnected()
    if (connected) return { connected: true }
  } catch { /* fall through */ }

  if (process.platform === 'win32' && /^\/\/\.\/(USB|LPT|COM)/i.test(address)) {
    try {
      const portName = address.replace('//./','')
      const { stdout } = await execAsync(
        `wmic printer where "PortName='${portName}'" get PrinterStatus /format:value`,
        { timeout: 5000 }
      )
      const match = stdout.match(/PrinterStatus=(\d+)/i)
      if (match && parseInt(match[1]) >= 1) return { connected: true }
    } catch { /* skip */ }
  }

  return { connected: false }
}

export async function getPrinterStatus() {
  try {
    const config = await getPrinterConfig()
    if (!config.address) return { connected: false, reason: 'not_configured' }

    if (config.address.startsWith('cups:'))
      return checkCupsPrinter(config.address.replace('cups:', ''))

    if (config.address.startsWith('winshare:'))
      return checkWindowsPrinterByName(config.address.replace('winshare:', ''))

    return checkRawPrinter(config.address, config.type)
  } catch {
    return { connected: false }
  }
}

// ── Unified send-to-printer ───────────────────────────────────────────────────
// buildFn(printer) adds content to the ThermalPrinter instance.
// Can be sync or async (label printing uses await printer.printImage).

async function sendToPrinter(config, buildFn) {
  if (config.address.startsWith('cups:')) {
    return printRawViaCups(config.address.replace('cups:', ''), buildFn)
  }
  if (config.address.startsWith('winshare:')) {
    return printViaWindowsShare(config.address.replace('winshare:', ''), buildFn)
  }

  // Raw file / device path (Linux/Mac direct device, or legacy Windows path)
  const printer = new ThermalPrinter({ type: config.type, interface: config.address, characterSet: CharacterSet.PC852_LATIN2 })
  await buildFn(printer)
  await printer.execute()
}

// ── CUPS: write ESC/POS to temp file, send via lp ────────────────────────────

async function printRawViaCups(printerName, buildFn) {
  const tmpPath = join(tmpdir(), `pos-print-${Date.now()}.bin`)
  try {
    const printer = new ThermalPrinter({ type: PrinterTypes.EPSON, interface: tmpPath, characterSet: CharacterSet.PC852_LATIN2 })
    await buildFn(printer)
    await printer.execute()
    await execAsync(`lp -d ${printerName} -o raw ${tmpPath}`, { timeout: 10000 })
  } finally {
    await unlink(tmpPath).catch(() => {})
  }
}

// ── Windows: write ESC/POS to temp file, send via shared printer ──────────────

async function printViaWindowsShare(printerName, buildFn) {
  const tmpPath = join(tmpdir(), `pos-print-${Date.now()}.bin`)
  try {
    const printer = new ThermalPrinter({ type: PrinterTypes.EPSON, interface: tmpPath, characterSet: CharacterSet.PC852_LATIN2 })
    await buildFn(printer)
    await printer.execute()
    await ensureWindowsPrinterShared(printerName)
    await execAsync(`cmd /c copy /b "${tmpPath}" "\\\\localhost\\${WINDOWS_SHARE}"`, { timeout: 10000 })
  } finally {
    await unlink(tmpPath).catch(() => {})
  }
}

// ── Receipt printing ──────────────────────────────────────────────────────────

export async function printReceipt(txnId) {
  const config = await getPrinterConfig()
  if (!config.address) throw new Error('Printer not configured')

  const storeName = await getStoreName()

  const { rows: txnRows } = await pool.query(`
    SELECT t.*, u.name as cashier_name, c.name as customer_name
    FROM transactions t
    LEFT JOIN users u ON u.id = t.cashier_id
    LEFT JOIN customers c ON c.id = t.customer_id
    WHERE t.id = $1
  `, [txnId])
  if (!txnRows[0]) throw new Error('Transaction not found')
  const txn = txnRows[0]

  const { rows: items } = await pool.query(`
    SELECT ti.*, p.name as product_name
    FROM transaction_items ti
    LEFT JOIN products p ON p.id = ti.product_id
    WHERE ti.transaction_id = $1
  `, [txnId])

  const { rows: payments } = await pool.query(
    'SELECT * FROM payments WHERE transaction_id = $1', [txnId]
  )
  const payment = payments[0]

  const lineWidth = config.paperWidth === '80mm' ? 48 : 32
  const line = '-'.repeat(lineWidth)
  const colWidth = lineWidth - 8
  const date = new Date(txn.created_at).toLocaleString('ru-RU')

  await sendToPrinter(config, async (printer) => {
    printer.alignCenter()
    printer.bold(true)
    printer.println(storeName)
    printer.bold(false)
    printer.println(line)
    printer.alignLeft()
    printer.println(txn.ref_no)
    printer.println(date)
    if (txn.cashier_name) printer.println(`Кассир: ${txn.cashier_name}`)
    if (txn.customer_name) printer.println(`Клиент: ${txn.customer_name}`)
    printer.println(line)

    for (const item of items) {
      const name = (item.product_name || '').substring(0, lineWidth)
      const price = Number(item.unit_price).toFixed(2)
      const subtotal = Number(item.subtotal).toFixed(2)
      printer.println(name)
      printer.println(`  ${price} x${item.qty}`.padEnd(colWidth) + subtotal.padStart(8))
    }

    printer.println(line)
    if (txn.discount > 0) {
      printer.println('Скидка:'.padEnd(colWidth) + `-${Number(txn.discount).toFixed(2)}`.padStart(8))
    }
    printer.bold(true)
    printer.println('ИТОГО:'.padEnd(colWidth) + `${Number(txn.total).toFixed(2)}`.padStart(8))
    printer.bold(false)
    printer.println(line)

    if (payment) {
      const methodName = payment.method === 'cash' ? 'Наличные' : 'Карта'
      printer.println(`${methodName}:`.padEnd(colWidth) + `${Number(payment.amount).toFixed(2)}`.padStart(8))
      if (payment.change_given > 0) {
        printer.println('Сдача:'.padEnd(colWidth) + `${Number(payment.change_given).toFixed(2)}`.padStart(8))
      }
    }

    printer.println(line)
    printer.alignCenter()
    printer.println('Спасибо за покупку!')
    printer.cut()
  })
}

// ── Test page ─────────────────────────────────────────────────────────────────

export async function printTestPage() {
  const config = await getPrinterConfig()
  if (!config.address) throw new Error('Printer not configured')

  const storeName = await getStoreName()
  const lineWidth = config.paperWidth === '80mm' ? 48 : 32
  const line = '-'.repeat(lineWidth)
  const now = new Date().toLocaleString('ru-RU')

  await sendToPrinter(config, async (printer) => {
    printer.alignCenter()
    printer.bold(true)
    printer.println(storeName)
    printer.bold(false)
    printer.println(line)
    printer.println('TEST PAGE')
    printer.println(now)
    printer.println(line)
    printer.alignLeft()
    printer.println(`Type:  EPSON`)
    printer.println(`Port:  ${config.address}`)
    printer.println(`Width: ${config.paperWidth}`)
    printer.println(line)
    printer.alignCenter()
    printer.println('Printer OK')
    printer.cut()
  })
}

// ── Barcode test page ─────────────────────────────────────────────────────────

export async function printBarcodeTestPage() {
  const config = await getBarcodePrinterConfig()
  if (!config.address) throw new Error('Barcode printer not configured')

  const storeName = await getStoreName()
  const lineWidth = config.paperWidth === '80mm' ? 48 : 32
  const line = '-'.repeat(lineWidth)
  const now = new Date().toLocaleString('ru-RU')

  await sendToPrinter(config, async (printer) => {
    printer.alignCenter()
    printer.bold(true)
    printer.println(storeName)
    printer.bold(false)
    printer.println(line)
    printer.println('BARCODE PRINTER TEST')
    printer.println(now)
    printer.println(line)
    printer.alignLeft()
    printer.println(`Type:  EPSON`)
    printer.println(`Port:  ${config.address}`)
    printer.println(`Width: ${config.paperWidth}`)
    printer.println(line)
    printer.alignCenter()
    printer.println('Barcode Printer OK')
    printer.cut()
  })
}

// ── Label printing ────────────────────────────────────────────────────────────

export async function printLabel({ barcode, product_name, price, copies = 1, size }) {
  const config = await getBarcodePrinterConfig()
  if (!config.address) throw new Error('Barcode printer not configured')

  const storeName = await getStoreName()
  const paperWidth = size || config.paperWidth
  const scale = paperWidth === '80mm' ? 3 : 2
  const safeCount = Math.min(Math.max(1, parseInt(copies, 10) || 1), 50)

  const barcodeBuffer = await bwipjs.toBuffer({
    bcid: 'code128', text: barcode, scale, height: 12,
    includetext: true, textxalign: 'center'
  })

  const imgPath = join(tmpdir(), `pos-barcode-${Date.now()}.png`)
  await writeFile(imgPath, barcodeBuffer)

  try {
    await sendToPrinter(config, async (printer) => {
      for (let i = 0; i < safeCount; i++) {
        printer.alignCenter()
        printer.println(storeName)
        printer.bold(true)
        printer.setTextSize(1, 1)
        printer.println(product_name || '')
        printer.bold(false)
        printer.setTextNormal()
        await printer.printImage(imgPath)
        printer.bold(true)
        printer.setTextSize(1, 1)
        printer.println(price !== undefined ? `${Number(price).toFixed(2)}` : '')
        printer.bold(false)
        printer.setTextNormal()
        printer.cut()
      }
    })
  } finally {
    await unlink(imgPath).catch(() => {})
  }
}
