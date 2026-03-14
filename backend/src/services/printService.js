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
