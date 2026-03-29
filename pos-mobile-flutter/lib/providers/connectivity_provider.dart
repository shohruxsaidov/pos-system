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
        Sentry.logger.fmt.info('Server connection restored');
      } else {
        Sentry.logger.fmt.warning('Server connection lost — app is offline');
      }
    }
    state = online;
  }

  Future<void> probe() => _probe();
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);
