import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  Timer? _timer;

  ConnectivityNotifier() : super(true) {
    _probe();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _probe());
  }

  Future<void> _probe() async {
    final online = await apiService.checkHealth();
    state = online;
  }

  Future<void> probe() => _probe();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>(
  (ref) => ConnectivityNotifier(),
);
