import JsBarcode from 'jsbarcode'

export function renderBarcode(svgEl, barcode) {
  if (!svgEl || !barcode) return
  JsBarcode(svgEl, barcode, {
    format: 'CODE128',
    width: 2,
    height: 48,
    displayValue: true,
    fontSize: 11,
    lineColor: '#e2e2f5',
    background: 'transparent'
  })
}

export function generateBarcode(productId) {
  const base = `200${String(productId).padStart(6, '0')}`
  let sum = 0
  base.split('').forEach((d, i) => {
    sum += parseInt(d) * (i % 2 === 0 ? 1 : 3)
  })
  const checkDigit = (10 - (sum % 10)) % 10
  return base + checkDigit
}
