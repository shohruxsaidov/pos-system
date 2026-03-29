import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../services/api_service.dart';

class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() {
    _probe();
    final timer = Timer.periodic(const Duration(seconds: 5), (_) => _probe());
    ref.onDispose(timer.cancel);
    return true;
  }

  Future<void> _probe() async {
    final online = await apiService.checkHealth();
    if (online != state) {
      if (online) {
        Sentry.logger.info('Server connection restored');
        Sentry.metrics.count('connectivity.restored', 1);
      } else {
        Sentry.logger.warn('Server connection lost — app is offline');
        Sentry.metrics.count('connectivity.lost', 1);
      }
    }
    state = online;
  }

  Future<void> probe() => _probe();
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);
