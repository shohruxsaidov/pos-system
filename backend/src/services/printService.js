import bwipjs from 'bwip-js'
import { ThermalPrinter, PrinterTypes, CharacterSet } from 'node-thermal-printer'
import { pool } from '../db/connection.js'

async function getStoreName() {
  const { rows } = await pool.query(`SELECT value FROM settings WHERE key = 'store_name'`)
  return rows[0]?.value || 'Store'
}

function createUsbPrinter() {
  return new ThermalPrinter({
    type: PrinterTypes.EPSON,
    interface: 'usb',
    characterSet: CharacterSet.PC852_LATIN2
  })
}

export async function getPrinterStatus() {
  try {
    const printer = createUsbPrinter()
    const connected = await printer.isPrinterConnected()
    return { connected }
  } catch {
    return { connected: false }
  }
}

export async function printReceipt(txnId) {
  const storeName = await getStoreName()
  const printer = createUsbPrinter()

  const connected = await printer.isPrinterConnected()
  if (!connected) throw new Error('USB printer not connected')

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

  const line = '-'.repeat(32)
  const date = new Date(txn.created_at).toLocaleString('ru-RU')

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
    const name = (item.product_name || '').substring(0, 24)
    const price = Number(item.unit_price).toFixed(2)
    const subtotal = Number(item.subtotal).toFixed(2)
    printer.println(name)
    printer.println(`  ${price} x${item.qty}`.padEnd(24) + subtotal.padStart(8))
  }

  printer.println(line)
  if (txn.discount > 0) {
    printer.println('Скидка:'.padEnd(24) + `-${Number(txn.discount).toFixed(2)}`.padStart(8))
  }
  printer.bold(true)
  printer.println('ИТОГО:'.padEnd(24) + `${Number(txn.total).toFixed(2)}`.padStart(8))
  printer.bold(false)
  printer.println(line)

  if (payment) {
    const methodName = payment.method === 'cash' ? 'Наличные' : 'Карта'
    printer.println(`${methodName}:`.padEnd(24) + `${Number(payment.amount).toFixed(2)}`.padStart(8))
    if (payment.change_given > 0) {
      printer.println('Сдача:'.padEnd(24) + `${Number(payment.change_given).toFixed(2)}`.padStart(8))
    }
  }

  printer.println(line)
  printer.alignCenter()
  printer.println('Спасибо за покупку!')
  printer.cut()

  await printer.execute()
}

export async function printLabel({ barcode, product_name, price, copies = 1, size = '58mm' }) {
  const storeName = await getStoreName()
  const printer = createUsbPrinter()

  const connected = await printer.isPrinterConnected()
  if (!connected) throw new Error('USB printer not connected')

  const scale = size === '80mm' ? 3 : 2

  const barcodeBuffer = await bwipjs.toBuffer({
    bcid: 'code128',
    text: barcode,
    scale,
    height: 12,
    includetext: true,
    textxalign: 'center'
  })

  const safeCount = Math.min(Math.max(1, parseInt(copies, 10) || 1), 50)

  for (let i = 0; i < safeCount; i++) {
    printer.alignCenter()
    printer.println(storeName)
    printer.bold(true)
    printer.setTextSize(1, 1)
    printer.println(product_name || '')
    printer.bold(false)
    printer.setTextNormal()
    await printer.printImage(barcodeBuffer)
    printer.bold(true)
    printer.setTextSize(1, 1)
    printer.println(price !== undefined ? `\u20B1${Number(price).toFixed(2)}` : '')
    printer.bold(false)
    printer.setTextNormal()
    printer.cut()
  }

  await printer.execute()
}
