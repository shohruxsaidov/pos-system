import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _days = 30;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _salesByDay = [];
  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _incoming = [];
  Map<String, dynamic> _summary = {};

  static const _daysOptions = [
    (label: '7 дн', value: 7),
    (label: '30 дн', value: 30),
    (label: '90 дн', value: 90),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await apiService.get(
        '/api/reports/product/${widget.productId}',
        queryParams: {'days': '$_days'},
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _product = data['product'] as Map<String, dynamic>?;
        _salesByDay = List<Map<String, dynamic>>.from(data['sales_by_day'] as List? ?? []);
        _adjustments = List<Map<String, dynamic>>.from(data['adjustments'] as List? ?? []);
        _incoming = List<Map<String, dynamic>>.from(data['incoming'] as List? ?? []);
        _summary = data['summary'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${(d.year % 100).toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  Widget _stockBadge(int qty) {
    final Color color;
    final Color bg;
    final String label;
    if (qty < 0) {
      color = AppColors.danger; bg = AppColors.dangerBg;
      label = 'Дефицит ($qty)';
    } else if (qty == 0) {
      color = AppColors.danger; bg = AppColors.dangerBg;
      label = 'Нет в наличии';
    } else if (qty <= 5) {
      color = AppColors.warning; bg = AppColors.warningBg;
      label = 'Мало ($qty)';
    } else {
      color = AppColors.success; bg = AppColors.successBg;
      label = '$qty на складе';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _product?['name'] as String? ?? '...',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_product != null)
                          Row(
                            children: [
                              if (_product!['barcode'] != null) ...[
                                Text(
                                  _product!['barcode'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                              _stockBadge((_product!['stock_qty'] as num).toInt()),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
                    onPressed: _load,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Period selector ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: _daysOptions.map((opt) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _days = opt.value); _load(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: _days == opt.value ? AppColors.accent1 : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _days == opt.value ? AppColors.accent1 : AppColors.borderDefault,
                        ),
                      ),
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          color: _days == opt.value ? Colors.white : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: _days == opt.value ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent1))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: AppColors.danger)),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _load, child: const Text('Повторить')),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          children: [
                            _buildSummaryCards(),
                            const SizedBox(height: 14),
                            _buildChart(),
                            const SizedBox(height: 14),
                            _buildAdjustments(),
                            const SizedBox(height: 14),
                            _buildIncoming(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    final totalSold = (_summary['total_sold'] as num?)?.toInt() ?? 0;
    final totalRevenue = (_summary['total_revenue'] as num?)?.toDouble() ?? 0;
    final totalTxns = (_summary['total_txns'] as num?)?.toInt() ?? 0;
    final totalIncoming = (_summary['total_incoming'] as num?)?.toInt() ?? 0;
    final totalAdj = (_summary['total_adjustments'] as num?)?.toInt() ?? 0;
    final price = (_product?['price'] as num?)?.toDouble() ?? 0;
    final cost = (_product?['cost'] as num?)?.toDouble() ?? 0;

    final cards = [
      _SummaryCardData(Icons.shopping_cart_outlined, 'Продано (всего)', '$totalSold', AppColors.success),
      _SummaryCardData(Icons.account_balance_wallet_outlined, 'Выручка (всего)', formatPrice(totalRevenue), AppColors.accent1),
      _SummaryCardData(Icons.receipt_outlined, 'Транзакций', '$totalTxns', AppColors.accent3),
      _SummaryCardData(Icons.local_shipping_outlined, 'Принято (период)', '$totalIncoming', AppColors.warning),
      _SummaryCardData(Icons.tune, 'Корректировок', '$totalAdj', AppColors.danger),
      _SummaryCardData(Icons.sell_outlined, 'Цена / Себест.', '${formatPrice(price)} / ${formatPrice(cost)}', AppColors.textSecondary),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: cards.map((c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(c.icon, color: c.color, size: 18),
            const Spacer(),
            Text(
              c.value,
              style: TextStyle(
                color: c.color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(c.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      )).toList(),
    );
  }

  // ── Chart ──────────────────────────────────────────────────────────────────

  Widget _buildChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Продажи по дням',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'последние $_days дней',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_salesByDay.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Продаж за период нет',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  backgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.borderSubtle,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: _salesByDay.length > 14 ? (_salesByDay.length / 7).ceilToDouble() : 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _salesByDay.length) return const SizedBox.shrink();
                          final date = _salesByDay[i]['date'] as String? ?? '';
                          final label = date.length >= 10 ? date.substring(5) : date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(label,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 9)),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: _salesByDay.asMap().entries.map((e) {
                    final qty = (e.value['qty'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: qty,
                          color: AppColors.accent1,
                          width: _salesByDay.length > 20 ? 6 : 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _salesByDay.fold<double>(0.0, (max, r) { final v = (r['qty'] as num?)?.toDouble() ?? 0; return v > max ? v : max; }),
                            color: AppColors.bgElevated,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.bgElevated,
                      getTooltipItem: (group, _, rod, __) {
                        final d = _salesByDay[group.x];
                        final date = d['date'] as String? ?? '';
                        final qty = (d['qty'] as num?)?.toInt() ?? 0;
                        final rev = (d['revenue'] as num?)?.toDouble() ?? 0;
                        return BarTooltipItem(
                          '$date\n',
                          const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          children: [
                            TextSpan(
                              text: '$qty шт  ${formatPrice(rev)}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Adjustments ────────────────────────────────────────────────────────────

  Widget _buildAdjustments() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Корректировки склада',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _CountBadge(_adjustments.length),
            ],
          ),
          const SizedBox(height: 10),
          if (_adjustments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Корректировок нет',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          else
            ...(_adjustments.take(50).map((adj) {
              final delta = (adj['delta'] as num?)?.toInt() ?? 0;
              final isPos = delta >= 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isPos ? AppColors.successBg : AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}$delta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isPos ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adj['reason'] as String? ?? '—',
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13),
                          ),
                          Text(
                            '${adj['adjusted_by_name'] ?? '—'}  ·  ${_fmtDate(adj['created_at'] as String?)}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }

  // ── Incoming ───────────────────────────────────────────────────────────────

  Widget _buildIncoming() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Приёмка товара',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _CountBadge(_incoming.length),
            ],
          ),
          const SizedBox(height: 10),
          if (_incoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Приёмок нет',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          else
            ...(_incoming.take(50).map((inc) {
              final qty = (inc['qty_received'] as num?)?.toInt() ?? 0;
              final cost = (inc['cost_per_unit'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inc['supplier'] as String? ?? 'Поставщик не указан',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatPrice(cost),
                                style: const TextStyle(
                                  color: AppColors.textAccent,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${inc['ref_no'] ?? ''}  ·  ${inc['received_by_name'] ?? '—'}  ·  ${_fmtDate(inc['created_at'] as String?)}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                          if (inc['expiry_date'] != null)
                            Text(
                              'Годен до: ${inc['expiry_date']}',
                              style: const TextStyle(
                                  color: AppColors.warning, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SummaryCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryCardData(this.icon, this.label, this.value, this.color);
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
