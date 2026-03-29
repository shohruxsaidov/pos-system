import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'config/router.dart';

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load saved API config
  await ApiConfig.load();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://d109233c3a72a805572e74936358c071@o4511127905763328.ingest.de.sentry.io/4511127907139664';
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
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
