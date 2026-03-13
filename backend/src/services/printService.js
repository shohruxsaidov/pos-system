import bwipjs from 'bwip-js'
import { ThermalPrinter, PrinterTypes, CharacterSet } from 'node-thermal-printer'
import { pool } from '../db/connection.js'

async function getPrinterConfig() {
  const { rows } = await pool.query(
    `SELECT key, value FROM settings
     WHERE key IN ('store_name','printer_interface','printer_ip','printer_port',
                   'printer_serial_path','printer_serial_baud')`
  )
  const cfg = Object.fromEntries(rows.map(r => [r.key, r.value]))
  return {
    storeName:   cfg.store_name          || 'Store',
    iface:       cfg.printer_interface   || 'tcp',
    ip:          cfg.printer_ip          || '192.168.1.100',
    port:        parseInt(cfg.printer_port || '9100', 10),
    serialPath:  cfg.printer_serial_path || 'COM3',
    serialBaud:  parseInt(cfg.printer_serial_baud || '9600', 10)
  }
}

function buildInterfaceString(cfg) {
  if (cfg.iface === 'serial') {
    return `serial://${cfg.serialPath}?baudRate=${cfg.serialBaud}`
  }
  return `tcp://${cfg.ip}:${cfg.port}`
}

export async function getPrinterStatus() {
  const cfg = await getPrinterConfig()
  const printer = new ThermalPrinter({
    type:      PrinterTypes.EPSON,
    interface: buildInterfaceString(cfg),
    characterSet: CharacterSet.PC852_LATIN2
  })
  const connected = await printer.isPrinterConnected()
  return { connected, interface: buildInterfaceString(cfg) }
}

export async function printLabel({ barcode, product_name, price, copies = 1, size = '58mm' }) {
  const cfg = await getPrinterConfig()

  const printer = new ThermalPrinter({
    type:      PrinterTypes.EPSON,
    interface: buildInterfaceString(cfg),
    characterSet: CharacterSet.PC852_LATIN2
  })

  const connected = await printer.isPrinterConnected()
  if (!connected) {
    throw new Error('Printer not connected')
  }

  const scale = size === '80mm' ? 3 : 2

  const barcodeBuffer = await bwipjs.toBuffer({
    bcid:        'code128',
    text:        barcode,
    scale,
    height:      12,
    includetext: true,
    textxalign:  'center'
  })

  const safeCount = Math.min(Math.max(1, parseInt(copies, 10) || 1), 50)

  for (let i = 0; i < safeCount; i++) {
    printer.alignCenter()
    printer.println(cfg.storeName)
    printer.bold(true)
    printer.setTextSize(1, 1)
    printer.println(product_name || '')
    printer.bold(false)
    printer.setTextNormal()
    await printer.printImage(barcodeBuffer)
    printer.bold(true)
    printer.setTextSize(1, 1)
    printer.println(`${price !== undefined ? `\u20B1${Number(price).toFixed(2)}` : ''}`)
    printer.bold(false)
    printer.setTextNormal()
    printer.cut()
  }

  await printer.execute()
}
