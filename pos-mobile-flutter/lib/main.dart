import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/api_config.dart';
import 'config/cloud_config.dart';
import 'config/app_theme.dart';
import 'config/router.dart';

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load saved API configs
  await ApiConfig.load();
  await CloudConfig.load();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://72befecd6239f2eabfeed46eaa27972c@o4507340253036544.ingest.de.sentry.io/4511127900192848';
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
      options.enableLogs = true;
    },
    appRunner: () => runApp(const ProviderScope(child: PosApp())),
  );
}

class PosApp extends ConsumerWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildRouter(ref);

    return MaterialApp.router(
      title: 'POS Мобайл',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
