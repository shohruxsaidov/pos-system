/**
 * Money arithmetic helpers.
 *
 * Binary floats cannot hold most decimal amounts exactly, so the naive forms
 * drift in two ways that matter at the till:
 *
 *   4000 / 75000 * 75000  === 4000.0000000000005   (derived qty round-trip)
 *   Math.round(1.005 * 100) / 100 === 1            (1.005 * 100 is 100.4999…)
 *
 * Every cart / receipt figure goes through `roundMoney`, which corrects both.
 */

/** Round to whole cents, half away from zero. */
export function roundMoney(n) {
  const x = Number(n)
  if (!Number.isFinite(x)) return 0
  // toPrecision(12) discards the binary noise (≈1e-10 at POS magnitudes, and
  // 12 significant digits still covers amounts up to 10 000 000 000.00) so the
  // midpoint reads back as the value the cashier actually typed.
  const cents = Number((x * 100).toPrecision(12))
  return (cents < 0 ? -Math.round(-cents) : Math.round(cents)) / 100
}

/** Sum amounts, rounding once at the end rather than per term. */
export function sumMoney(values) {
  return roundMoney(values.reduce((s, v) => s + (Number(v) || 0), 0))
}

/**
 * Charge for one cart / transaction line.
 *
 * `amount` is set when the cashier enters a sum instead of a quantity ("sell
 * 4 000 worth of rice"). It is authoritative: qty is then a derived, non-round
 * weight whose product with unit_price only approximates the sum that was
 * asked for. It is honoured only while it still matches that product to within
 * a cent — editing qty afterwards clears it, and a stale value falls back to
 * the ordinary calculation.
 */
export function lineTotal(item) {
  const gross = (Number(item.unit_price) || 0) * (Number(item.qty) || 0)
  const amount = Number(item.amount)
  const useAmount = item.amount != null &&
    Number.isFinite(amount) &&
    Math.abs(amount - gross) <= 0.01
  return roundMoney((useAmount ? amount : gross) - (Number(item.discount) || 0))
}
