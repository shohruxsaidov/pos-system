import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../utils/format.dart';
import '../services/api_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _daily;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _cashiers = [];
  bool _loading = false;
  String? _error;

  final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final dateStr = _dateFmt.format(_date);
    try {
      final results = await Future.wait([
        apiService.get('/api/reports/daily', queryParams: {'date': dateStr}),
        apiService.get('/api/reports/products',
            queryParams: {'from': dateStr, 'to': dateStr, 'limit': '10'}),
        apiService
            .get('/api/reports/cashiers', queryParams: {'date': dateStr}),
      ]);

      setState(() {
        _daily = results[0].data as Map<String, dynamic>?;
        _topProducts = List<Map<String, dynamic>>.from(
            results[1].data as List? ?? []);
        _cashiers = List<Map<String, dynamic>>.from(
            results[2].data as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки отчётов';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent1,
            surface: AppColors.bgElevated,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Date picker header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Отчёты',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: AppColors.accent1, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd, yyyy').format(_date),
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: AppColors.textSecondary),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent1))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style: const TextStyle(
                                      color: AppColors.danger)),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: _load,
                                  child: const Text('Повторить')),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            // Summary cards
                            if (_daily != null) ...[
                              _buildSummaryCards(),
                              const SizedBox(height: 16),
                            ],

                            // Payment breakdown
                            if (_daily?['by_method'] != null) ...[
                              _sectionTitle('Способы оплаты'),
                              const SizedBox(height: 8),
                              _buildPaymentMethods(),
                              const SizedBox(height: 16),
                            ],

                            // Top products
                            if (_topProducts.isNotEmpty) ...[
                              _sectionTitle('Топ товаров'),
                              const SizedBox(height: 8),
                              ..._topProducts.asMap().entries.map(
                                    (e) => _ProductRow(
                                        rank: e.key + 1,
                                        product: e.value),
                                  ),
                              const SizedBox(height: 16),
                            ],

                            // Cashiers
                            if (_cashiers.isNotEmpty) ...[
                              _sectionTitle('Кассиры'),
                              const SizedBox(height: 8),
                              ..._cashiers.map(
                                    (c) => _CashierRow(cashier: c),
                                  ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }

  Widget _buildSummaryCards() {
    final summary = _daily!['summary'] as Map<String, dynamic>? ?? {};
    final txnCount = summary['transaction_count'] ?? 0;
    final netSales = (summary['net_sales'] as num?)?.toDouble() ?? 0;
    final totalDiscount = (summary['total_discounts'] as num?)?.toDouble() ?? 0;
    final refundsMap = _daily!['refunds'] as Map<String, dynamic>? ?? {};
    final refunds = (refundsMap['total'] as num?)?.toDouble() ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
            label: 'Транзакции',
            value: '$txnCount',
            icon: Icons.receipt_long,
            color: AppColors.accent1),
        _StatCard(
            label: 'Чистые продажи',
            value: formatPrice(netSales),
            icon: Icons.trending_up,
            color: AppColors.success),
        _StatCard(
            label: 'Скидки',
            value: formatPrice(totalDiscount),
            icon: Icons.discount,
            color: AppColors.warning),
        _StatCard(
            label: 'Возвраты',
            value: formatPrice(refunds),
            icon: Icons.undo,
            color: AppColors.danger),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    final methods = _daily!['by_method'] as List? ?? [];
    return Column(
      children: methods.map<Widget>((m) {
        final amount = (m['total'] as num?)?.toDouble() ?? 0;
        final count = m['count'] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.payment,
                  color: AppColors.accent1, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (m['method'] ?? '').toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text('$count тр.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 12),
              Text(
                formatPrice(amount),
                style: const TextStyle(
                    color: AppColors.textAccent,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> product;

  const _ProductRow({required this.rank, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppColors.accentGlow
                  : AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                    color: rank <= 3
                        ? AppColors.accent1
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(product['name'] as String? ?? '',
                style:
                    const TextStyle(color: AppColors.textPrimary)),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${product['total_qty'] ?? 0} прод.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              formatPrice(
                  (product['total_revenue'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(
                  color: AppColors.textAccent,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashierRow extends StatelessWidget {
  final Map<String, dynamic> cashier;

  const _CashierRow({required this.cashier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentGlow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                ((cashier['cashier_name'] as String?) ?? '?')[0]
                    .toUpperCase(),
                style: const TextStyle(
                    color: AppColors.accent1,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cashier['cashier_name'] as String? ?? 'Неизвестен',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  '${cashier['transaction_count'] ?? 0} транзакций',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatPrice(
                (cashier['total_sales'] as num?)?.toDouble() ?? 0),
            style: const TextStyle(
                color: AppColors.textAccent,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
