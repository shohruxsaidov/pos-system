// Pure localStorage helpers — no Vue dependencies

const QUEUE_KEY = 'pos_sale_queue'
const PRODUCTS_KEY = 'pos_products_cache'
const CACHE_TTL = 8 * 60 * 60 * 1000 // 8 hours

export function generateClientRef() {
  const ts = Date.now()
  const rand = String(Math.floor(Math.random() * 10000)).padStart(4, '0')
  return `OFFLINE-${ts}-${rand}`
}

function readQueue() {
  try {
    return JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]')
  } catch {
    return []
  }
}

function writeQueue(q) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(q))
}

export function getQueue() {
  return readQueue()
}

export function enqueue(payload) {
  const q = readQueue()
  q.push(payload)
  writeQueue(q)
}

export function dequeue(clientRef) {
  const q = readQueue().filter(item => item.client_ref !== clientRef)
  writeQueue(q)
}

export function saveProductsCache(products) {
  localStorage.setItem(PRODUCTS_KEY, JSON.stringify({
    data: products,
    ts: Date.now()
  }))
}

export function loadProductsCache() {
  try {
    const raw = localStorage.getItem(PRODUCTS_KEY)
    if (!raw) return null
    const { data, ts } = JSON.parse(raw)
    if (Date.now() - ts > CACHE_TTL) return null
    return data
  } catch {
    return null
  }
}

export function patchProductStock(productId, delta, products) {
  const p = products.find(x => x.id === productId)
  if (p) p.stock_qty = (p.stock_qty ?? 0) + delta
}
