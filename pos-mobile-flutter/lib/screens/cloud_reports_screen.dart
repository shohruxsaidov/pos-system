import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../config/cloud_config.dart';
import '../services/cloud_api_service.dart';
import '../utils/format.dart';
import 'cloud_login_screen.dart';

class CloudReportsScreen extends StatefulWidget {
  const CloudReportsScreen({super.key});

  @override
  State<CloudReportsScreen> createState() => _CloudReportsScreenState();
}

class _CloudReportsScreenState extends State<CloudReportsScreen> {
  DateTime _from = DateTime.now();
  DateTime _to   = DateTime.now();

  Map<String, dynamic>? _daily;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cashiers = [];
  bool _loading = false;
  String? _error;

  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    if (CloudConfig.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final from = _dateFmt.format(_from);
    final to   = _dateFmt.format(_to);
    try {
      final results = await Future.wait([
        cloudApiService.get('/api/reports/daily',    queryParams: {'from': from, 'to': to}),
        cloudApiService.get('/api/reports/products', queryParams: {'from': from, 'to': to, 'limit': '15'}),
        cloudApiService.get('/api/reports/cashiers', queryParams: {'from': from, 'to': to}),
      ]);
      setState(() {
        _daily    = results[0] as Map<String, dynamic>?;
        _products = List<Map<String, dynamic>>.from(results[1] as List? ?? []);
        _cashiers = List<Map<String, dynamic>>.from(results[2] as List? ?? []);
        _loading  = false;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      // Token expired → clear and force re-login
      if (msg.contains('Unauthorized')) {
        await CloudConfig.clear();
        setState(() { _loading = false; });
      } else {
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent1,
            onPrimary: Colors.white,
            surface: AppColors.bgSurface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _load();
    }
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CloudLoginScreen()),
    );
    if (ok == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudConfig.isConfigured) {
      return _buildNotConnected();
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnected() {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 64),
                const SizedBox(height: 16),
                const Text('Облако не подключено', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Подключитесь к облачному серверу для просмотра отчётов', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _openLogin,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Подключиться', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent1,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgSidebar,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined, color: AppColors.accent1, size: 20),
          const SizedBox(width: 8),
          const Text('Облако', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range, color: AppColors.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _from == _to
                        ? _displayFmt.format(_from)
                        : '${_displayFmt.format(_from)} – ${_displayFmt.format(_to)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loading ? null : _load,
            child: const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent1));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Повторить', style: TextStyle(color: AppColors.accent1))),
            ],
          ),
        ),
      );
    }
    if (_daily == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 20),
        if ((_daily!['payment_methods'] as List?)?.isNotEmpty == true) ...[
          _buildSectionTitle('Способы оплаты'),
          const SizedBox(height: 10),
          _buildPaymentMethods(),
          const SizedBox(height: 20),
        ],
        if (_products.isNotEmpty) ...[
          _buildSectionTitle('Топ товаров'),
          const SizedBox(height: 10),
          ..._products.asMap().entries.map((e) => _ProductRow(rank: e.key + 1, item: e.value)),
          const SizedBox(height: 20),
        ],
        if (_cashiers.isNotEmpty) ...[
          _buildSectionTitle('По кассирам'),
          const SizedBox(height: 10),
          ..._cashiers.map((c) => _CashierRow(item: c)),
        ],
        // Disconnect option at bottom
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: () async {
            await CloudConfig.clear();
            setState(() { _daily = null; _products = []; _cashiers = []; });
          },
          icon: const Icon(Icons.cloud_off, size: 16, color: AppColors.textMuted),
          label: const Text('Отключить облако', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 8),
        Text(CloudConfig.url ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final d = _daily!;
    final count  = int.tryParse(d['transaction_count'].toString()) ?? 0;
    final total  = double.tryParse(d['total_sales'].toString()) ?? 0;
    final avg    = double.tryParse(d['avg_per_transaction'].toString()) ?? 0;
    final disc   = double.tryParse(d['total_discount'].toString()) ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _StatCard(label: 'Продажи', value: formatPrice(total), icon: Icons.attach_money),
        _StatCard(label: 'Транзакции', value: '$count', icon: Icons.receipt_long),
        _StatCard(label: 'Средний чек', value: formatPrice(avg), icon: Icons.bar_chart),
        _StatCard(label: 'Скидки', value: formatPrice(disc), icon: Icons.local_offer_outlined),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    final methods = List<Map<String, dynamic>>.from(_daily!['payment_methods'] as List);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: methods.asMap().entries.map((e) {
          final m = e.value;
          final isLast = e.key == methods.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Text(m['method']?.toString().toUpperCase() ?? '—', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${m['count']} чеков', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 16),
                Text(formatPrice(double.tryParse(m['total'].toString()) ?? 0),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'JetBrainsMono')),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) =>
      Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.accent1, size: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'JetBrainsMono')),
              Text(label,  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  const _ProductRow({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final revenue = double.tryParse(item['total_revenue'].toString()) ?? 0;
    final qty     = double.tryParse(item['total_qty'].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$rank', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(child: Text(item['product_name']?.toString() ?? '—', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
          Text('${qty % 1 == 0 ? qty.toInt() : qty} шт', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          Text(formatPrice(revenue), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}

class _CashierRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CashierRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(item['total_sales'].toString()) ?? 0;
    final count = int.tryParse(item['transaction_count'].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(item['cashier_name']?.toString() ?? '—', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          Text('$count чеков', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          Text(formatPrice(total), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}
