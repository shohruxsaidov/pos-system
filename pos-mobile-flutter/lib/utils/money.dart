/// Money arithmetic helpers — the Dart twin of `pos-desktop/src/utils/money.js`.
///
/// Doubles cannot hold most decimal amounts exactly, so the naive forms drift
/// in two ways that matter at the till:
///
///   4000 / 75000 * 75000  == 4000.0000000000005   (derived qty round-trip)
///   (1.005 * 100).round() / 100 == 1.0            (1.005 * 100 is 100.4999…)
///
/// Every charged figure goes through [roundMoney], which corrects both.
library;

/// Rounds to whole cents. Dart's [num.round] already breaks ties away from
/// zero; the work here is stripping the binary noise before it does.
double roundMoney(num n) {
  final x = n.toDouble();
  if (!x.isFinite) return 0;
  // 12 significant digits discards the ≈1e-10 error at POS magnitudes while
  // still covering amounts up to 10 000 000 000.00, so the midpoint reads back
  // as the value that was actually typed.
  final cents = double.parse((x * 100).toStringAsPrecision(12));
  return cents.round() / 100;
}

/// Sums amounts, rounding once at the end rather than per term.
double sumMoney(Iterable<num> values) =>
    roundMoney(values.fold<double>(0, (s, v) => s + v.toDouble()));

/// Charge for one line, where [amount] is a sum the user entered directly
/// instead of a quantity ("receive 4 000 worth of rice").
///
/// The entered sum wins: qty is then a derived, non-round weight whose product
/// with the unit price only approximates it. The sum is honoured only while it
/// still matches that product to within a cent, so a stale value left behind by
/// a later qty edit falls back to the ordinary calculation.
double lineTotal({
  required double unitPrice,
  required double qty,
  double? amount,
  double discount = 0,
}) {
  final gross = unitPrice * qty;
  final useAmount =
      amount != null && amount.isFinite && (amount - gross).abs() <= 0.01;
  return roundMoney((useAmount ? amount : gross) - discount);
}
