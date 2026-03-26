import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/settings_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/sales',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isLoggingIn = state.matchedLocation == '/login';
      if (!auth.isLoggedIn && !isLoggingIn) return '/login';
      if (auth.isLoggedIn && isLoggingIn) return '/sales';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/incoming',
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
}
