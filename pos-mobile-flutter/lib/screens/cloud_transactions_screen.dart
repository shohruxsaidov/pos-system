import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../config/cloud_config.dart';
import '../services/cloud_api_service.dart';
import '../utils/format.dart';
import 'cloud_login_screen.dart';

class CloudTransactionsScreen extends StatefulWidget {
  const CloudTransactionsScreen({super.key});

  @override
  State<CloudTransactionsScreen> createState() => _CloudTransactionsScreenState();
}

enum _TxnPeriod { day, week, month, range }

class _CloudTransactionsScreenState extends State<CloudTransactionsScreen> {
  DateTime _date = DateTime.now();
  _TxnPeriod _period = _TxnPeriod.day;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  List<Map<String, dynamic>> _transactions = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  final _dateFmt = DateFormat('yyyy-MM-dd');

  String _toIso(DateTime d, {bool endOfDay = false}) {
    final local = endOfDay
        ? DateTime(d.year, d.month, d.day, 23, 59, 59, 999)
        : DateTime(d.year, d.month, d.day);
    return local.toUtc().toIso8601String().replaceFirst(RegExp(r'\.000Z$'), 'Z');
  }

  ({String from, String to}) get _dateRange {
    if (_period == _TxnPeriod.week) {
      final dayOfWeek = (_date.weekday - 1) % 7;
      final monday = _date.subtract(Duration(days: dayOfWeek));
      final sunday = monday.add(const Duration(days: 6));
      return (from: _toIso(monday), to: _toIso(sunday, endOfDay: true));
    } else if (_period == _TxnPeriod.month) {
      final firstDay = DateTime(_date.year, _date.month, 1);
      final lastDay  = DateTime(_date.year, _date.month + 1, 0);
      return (from: _toIso(firstDay), to: _toIso(lastDay, endOfDay: true));
    } else if (_period == _TxnPeriod.range) {
      final s = _rangeStart ?? _date;
      final e = _rangeEnd   ?? _date;
      return (from: _toIso(s), to: _toIso(e, endOfDay: true));
    }
    return (from: _toIso(_date), to: _toIso(_date, endOfDay: true));
  }

  String get _dateLabel {
    if (_period == _TxnPeriod.day) return _dateFmt.format(_date);
    if (_period == _TxnPeriod.week) {
      final dayOfWeek = (_date.weekday - 1) % 7;
      final monday = _date.subtract(Duration(days: dayOfWeek));
      final sunday = monday.add(const Duration(days: 6));
      return '${_dateFmt.format(monday)} — ${_dateFmt.format(sunday)}';
    }
    if (_period == _TxnPeriod.month) {
      return DateFormat('MMMM yyyy').format(_date);
    }
    if (_period == _TxnPeriod.range && _rangeStart != null) {
      final s = _rangeStart!;
      final e = _rangeEnd ?? _rangeStart!;
      if (_dateFmt.format(s) == _dateFmt.format(e)) return _dateFmt.format(s);
      return '${_dateFmt.format(s)} — ${_dateFmt.format(e)}';
    }
    return _dateFmt.format(_date);
  }

  @override
  void initState() {
    super.initState();
    if (CloudConfig.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final range = _dateRange;
    try {
      final data = await cloudApiService.get('/api/transactions', queryParams: {
        'from': range.from, 'to': range.to, 'page': '1', 'limit': '30',
      });
      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(
              (data as Map<String, dynamic>)['transactions'] as List? ?? []);
          _total   = (data['total'] as num?)?.toInt() ?? 0;
          _page    = 1;
          _loading = false;
        });
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('Unauthorized')) {
        await CloudConfig.clear();
        if (mounted) setState(() => _loading = false);
      } else {
        if (mounted) setState(() { _error = msg; _loading = false; });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final range = _dateRange;
    try {
      final data = await cloudApiService.get('/api/transactions', queryParams: {
        'from': range.from, 'to': range.to, 'page': '${_page + 1}', 'limit': '30',
      });
      if (mounted) {
        setState(() {
          _transactions.addAll(List<Map<String, dynamic>>.from(
              (data as Map<String, dynamic>)['transactions'] as List? ?? []));
          _page++;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
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
            onPrimary: Colors.white,
            surface: AppColors.bgSurface,
            onSurface: AppColors.textPrimary,
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (_rangeStart != null && _rangeEnd != null)
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : null,
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
      setState(() { _rangeStart = picked.start; _rangeEnd = picked.end; });
      _load();
    }
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CloudLoginScreen()),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _showDetail(String refNo) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _TransactionDetailSheet(refNo: refNo),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudConfig.isConfigured) return _buildNotConnected();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildPeriodChips(),
            Expanded(child: _buildBody()),
          ],
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_back, color: AppColors.textMuted, size: 22),
            ),
          ),
          const Icon(Icons.receipt_long, color: AppColors.accent1, size: 20),
          const SizedBox(width: 8),
          const Text('Транзакции',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _period == _TxnPeriod.range ? _pickDateRange : _pickDate,
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
                  const Icon(Icons.calendar_today,
                      color: AppColors.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text(_dateLabel,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12)),
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

  Widget _buildPeriodChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _PeriodTab(
            label: 'День',
            selected: _period == _TxnPeriod.day,
            onTap: () { setState(() => _period = _TxnPeriod.day); _load(); },
          ),
          const SizedBox(width: 8),
          _PeriodTab(
            label: 'Неделя',
            selected: _period == _TxnPeriod.week,
            onTap: () { setState(() => _period = _TxnPeriod.week); _load(); },
          ),
          const SizedBox(width: 8),
          _PeriodTab(
            label: 'Месяц',
            selected: _period == _TxnPeriod.month,
            onTap: () { setState(() => _period = _TxnPeriod.month); _load(); },
          ),
          const SizedBox(width: 8),
          _PeriodTab(
            label: 'Диапазон',
            selected: _period == _TxnPeriod.range,
            onTap: () {
              setState(() => _period = _TxnPeriod.range);
              _pickDateRange();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnected() {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 64),
                const SizedBox(height: 16),
                const Text('Облако не подключено',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text(
                    'Подключитесь к облачному серверу для просмотра транзакций',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _openLogin,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Подключиться',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent1,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent1));
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
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: _load,
                  child: const Text('Повторить',
                      style: TextStyle(color: AppColors.accent1))),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('Нет транзакций за этот период',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Всего: $_total транзакций',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        ..._transactions.map((t) => _TransactionRow(
              item: t,
              onTap: () => _showDetail(t['ref_no'].toString()),
            )),
        if (_transactions.length < _total) ...[
          const SizedBox(height: 12),
          _loadingMore
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        color: AppColors.accent1, strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _loadMore,
                  child: const Text('Загрузить ещё',
                      style: TextStyle(color: AppColors.accent1)),
                ),
        ],
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: () async {
            await CloudConfig.clear();
            setState(() { _transactions = []; _total = 0; });
          },
          icon: const Icon(Icons.cloud_off,
              size: 16, color: AppColors.textMuted),
          label: const Text('Отключить облако',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 8),
        Text(CloudConfig.url ?? '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  const _TransactionRow({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final refNo   = item['ref_no']?.toString() ?? '—';
    final total   = double.tryParse(item['total'].toString()) ?? 0;
    final method  = item['payment_method']?.toString() ?? '';
    final cashier = item['cashier_name']?.toString() ?? '—';
    final rawDate = item['created_at']?.toString();
    String timeStr = '';
    if (rawDate != null) {
      try {
        timeStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(rawDate).toLocal());
      } catch (_) {}
    }

    Color methodBg;
    Color methodFg;
    switch (method.toLowerCase()) {
      case 'cash':
        methodBg = AppColors.successBg;
        methodFg = AppColors.success;
        break;
      case 'card':
        methodBg = AppColors.accentGlow;
        methodFg = AppColors.accent1;
        break;
      default:
        methodBg = const Color(0x1A9898BB);
        methodFg = AppColors.textMuted;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(refNo,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'JetBrainsMono')),
                  const SizedBox(height: 2),
                  Text(cashier,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(total),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'JetBrainsMono')),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeStr.isNotEmpty) ...[
                      Text(timeStr,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: methodBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        method.toUpperCase(),
                        style: TextStyle(
                            color: methodFg,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetailSheet extends StatefulWidget {
  final String refNo;
  const _TransactionDetailSheet({required this.refNo});

  @override
  State<_TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<_TransactionDetailSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await cloudApiService.get('/api/transactions/${widget.refNo}');
      if (mounted) setState(() { _data = data as Map<String, dynamic>; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppColors.accent1, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.refNo,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'JetBrainsMono'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderSubtle, height: 1),
              Expanded(child: _buildContent(controller, bottomPad)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController controller, double bottomPad) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent1));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
      );
    }
    if (_data == null) return const SizedBox();

    final d = _data!;
    final total    = double.tryParse(d['total'].toString()) ?? 0;
    final subtotal = double.tryParse(d['subtotal'].toString()) ?? 0;
    final discount = double.tryParse(d['discount'].toString()) ?? 0;
    final tax      = double.tryParse(d['tax'].toString()) ?? 0;
    final method   = d['payment_method']?.toString() ?? '';
    final cashier  = d['cashier_name']?.toString() ?? '—';
    final rawDate  = d['created_at']?.toString();
    String dateStr = '';
    if (rawDate != null) {
      try {
        dateStr = DateFormat('dd.MM.yyyy HH:mm')
            .format(DateTime.parse(rawDate).toLocal());
      } catch (_) {}
    }
    final items = List<Map<String, dynamic>>.from(d['items'] as List? ?? []);

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 16),
      children: [
        // Meta row
        _MetaRow(label: 'Кассир', value: cashier),
        _MetaRow(label: 'Дата', value: dateStr),
        _MetaRow(label: 'Оплата', value: method.toUpperCase()),
        const SizedBox(height: 16),
        // Items header
        const Text('Товары',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // Items list
        ...items.map((item) {
          final name     = item['product_name']?.toString() ?? '—';
          final qty      = double.tryParse(item['qty'].toString()) ?? 0;
          final price    = double.tryParse(item['unit_price'].toString()) ?? 0;
          final itemDisc = double.tryParse(item['discount'].toString()) ?? 0;
          final itemSub  = double.tryParse(item['subtotal'].toString()) ?? 0;
          final qtyStr   = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '$qtyStr × ${formatPrice(price)}${itemDisc > 0 ? '  −${formatPrice(itemDisc)}' : ''}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(formatPrice(itemSub),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'JetBrainsMono')),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        const Divider(color: AppColors.borderSubtle),
        const SizedBox(height: 8),
        // Totals
        if (discount > 0) _TotalRow(label: 'Скидка', value: '−${formatPrice(discount)}', muted: true),
        if (tax > 0) _TotalRow(label: 'Налог', value: formatPrice(tax), muted: true),
        if (subtotal != total) _TotalRow(label: 'Подытог', value: formatPrice(subtotal), muted: true),
        _TotalRow(label: 'Итого', value: formatPrice(total), bold: true),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final bool bold;
  const _TotalRow({required this.label, required this.value, this.muted = false, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: muted ? AppColors.textMuted : AppColors.textSecondary,
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent1 : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent1 : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
