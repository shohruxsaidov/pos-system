import { exec } from 'child_process'
import { promisify } from 'util'
import { writeFile, unlink } from 'fs/promises'
import { tmpdir } from 'os'
import { join } from 'path'
import bwipjs from 'bwip-js'
import { ThermalPrinter, PrinterTypes, CharacterSet } from 'node-thermal-printer'
import { pool } from '../db/connection.js'

const execAsync = promisify(exec)

// ── Settings ─────────────────────────────────────────────────────────────────

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

async function savePrinterAddress(address) {
  await pool.query(
    `INSERT INTO settings (key, value) VALUES ('printer_address', $1)
     ON CONFLICT (key) DO UPDATE SET value=$1`,
    [address]
  )
}

// ── Detection ─────────────────────────────────────────────────────────────────

async function detectPrinterWindows() {
  try {
    const { stdout } = await execAsync(
      'wmic printer get Name,PortName /format:csv',
      { timeout: 5000 }
    )
    for (const line of stdout.trim().split('\n').slice(1)) {
      const parts = line.split(',')
      const portName = parts[2]?.trim()
      if (portName && /^(USB|LPT|COM)\d+$/i.test(portName)) {
        return `//./${portName}`
      }
    }
  } catch { /* wmic not available */ }

  // Fallback: try raw paths
  const { ThermalPrinter: TP } = await import('node-thermal-printer')
  for (const addr of ['//./USB001', '//./USB002', '//./USB003', '//./LPT1']) {
    try {
      const p = new TP({ type: PrinterTypes.EPSON, interface: addr, characterSet: CharacterSet.PC852_LATIN2 })
      if (await p.isPrinterConnected()) return addr
    } catch { /* skip */ }
  }
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

  // Fallback: check device files
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

// ── Status ────────────────────────────────────────────────────────────────────

async function checkCupsPrinter(name) {
  try {
    const { stdout } = await execAsync(`lpstat -p ${name}`, { timeout: 3000 })
    return { connected: /is idle|is printing|is ready|enabled/.test(stdout) }
  } catch {
    return { connected: false }
  }
}

async function checkRawPrinter(address, type) {
  try {
    const printer = new ThermalPrinter({ type, interface: address, characterSet: CharacterSet.PC852_LATIN2 })
    return { connected: await printer.isPrinterConnected() }
  } catch {
    return { connected: false }
  }
}

export async function getPrinterStatus() {
  try {
    const config = await getPrinterConfig()
    if (!config.address) return { connected: false, reason: 'not_configured' }

    if (config.address.startsWith('cups:')) {
      return checkCupsPrinter(config.address.replace('cups:', ''))
    }

    return checkRawPrinter(config.address, config.type)
  } catch {
    return { connected: false }
  }
}

// ── Printer factory ───────────────────────────────────────────────────────────

async function createPrinter() {
  const config = await getPrinterConfig()
  if (!config.address) throw new Error('Printer not configured')

  if (config.address.startsWith('cups:')) {
    // CUPS printing is done via lp command — return a wrapper
    return null // handled separately in print functions
  }

  return new ThermalPrinter({
    type: config.type,
    interface: config.address,
    characterSet: CharacterSet.PC852_LATIN2
  })
}

// ── CUPS raw ESC/POS via lp ───────────────────────────────────────────────────

async function printRawViaCups(printerName, buildFn) {
  // Build ESC/POS bytes using a temp printer that writes to a temp file
  const tmpPath = join(tmpdir(), `pos-print-${Date.now()}.bin`)
  const printer = new ThermalPrinter({
    type: PrinterTypes.EPSON,
    interface: tmpPath,
    characterSet: CharacterSet.PC852_LATIN2
  })
  buildFn(printer)
  await printer.execute()
  await execAsync(`lp -d ${printerName} -o raw ${tmpPath}`, { timeout: 10000 })
  await unlink(tmpPath).catch(() => {})
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
  const date = new Date(txn.created_at).toLocaleString('ru-RU')

  function build(printer) {
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

    const colWidth = lineWidth - 8
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
  }

  if (config.address.startsWith('cups:')) {
    await printRawViaCups(config.address.replace('cups:', ''), build)
    return
  }

  const printer = new ThermalPrinter({ type: config.type, interface: config.address, characterSet: CharacterSet.PC852_LATIN2 })
  if (!await printer.isPrinterConnected()) throw new Error('Printer not connected')
  build(printer)
  await printer.execute()
}

// ── Test page ─────────────────────────────────────────────────────────────────

export async function printTestPage() {
  const config = await getPrinterConfig()
  if (!config.address) throw new Error('Printer not configured')

  const storeName = await getStoreName()
  const lineWidth = config.paperWidth === '80mm' ? 48 : 32
  const line = '-'.repeat(lineWidth)
  const now = new Date().toLocaleString('ru-RU')

  function build(printer) {
    printer.alignCenter()
    printer.bold(true)
    printer.println(storeName)
    printer.bold(false)
    printer.println(line)
    printer.println('TEST PAGE')
    printer.println(now)
    printer.println(line)
    printer.alignLeft()
    printer.println(`Type:  ${config.type === 'STAR' ? 'STAR' : 'EPSON'}`)
    printer.println(`Port:  ${config.address}`)
    printer.println(`Width: ${config.paperWidth}`)
    printer.println(line)
    printer.alignCenter()
    printer.println('Printer OK')
    printer.cut()
  }

  if (config.address.startsWith('cups:')) {
    await printRawViaCups(config.address.replace('cups:', ''), build)
    return
  }

  const printer = new ThermalPrinter({ type: config.type, interface: config.address, characterSet: CharacterSet.PC852_LATIN2 })
  if (!await printer.isPrinterConnected()) throw new Error('Printer not connected')
  build(printer)
  await printer.execute()
}

// ── Label printing ────────────────────────────────────────────────────────────

export async function printLabel({ barcode, product_name, price, copies = 1, size }) {
  const config = await getPrinterConfig()
  if (!config.address) throw new Error('Printer not configured')

  const storeName = await getStoreName()
  const paperWidth = size || config.paperWidth
  const scale = paperWidth === '80mm' ? 3 : 2
  const safeCount = Math.min(Math.max(1, parseInt(copies, 10) || 1), 50)

  const barcodeBuffer = await bwipjs.toBuffer({
    bcid: 'code128', text: barcode, scale, height: 12,
    includetext: true, textxalign: 'center'
  })

  // printImage() requires a file path — write PNG to a temp file
  const imgPath = join(tmpdir(), `pos-barcode-${Date.now()}.png`)
  await writeFile(imgPath, barcodeBuffer)

  try {
    async function build(printer) {
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
    }

    if (config.address.startsWith('cups:')) {
      const tmpPath = join(tmpdir(), `pos-label-${Date.now()}.bin`)
      const printer = new ThermalPrinter({ type: PrinterTypes.EPSON, interface: tmpPath, characterSet: CharacterSet.PC852_LATIN2 })
      await build(printer)
      await printer.execute()
      await execAsync(`lp -d ${config.address.replace('cups:', '')} -o raw ${tmpPath}`, { timeout: 10000 })
      await unlink(tmpPath).catch(() => {})
      return
    }

    const printer = new ThermalPrinter({ type: config.type, interface: config.address, characterSet: CharacterSet.PC852_LATIN2 })
    if (!await printer.isPrinterConnected()) throw new Error('Printer not connected')
    await build(printer)
    await printer.execute()
  } finally {
    await unlink(imgPath).catch(() => {})
  }
}
