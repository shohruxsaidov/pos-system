import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/offline_draft_screen.dart';
import '../screens/settings_screen.dart';

Page<void> _fadePage(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

Page<void> _slidePage(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/sales',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isLoggingIn = loc == '/login';
      final isOfflineDrafts = loc == '/drafts';
      if (!auth.isLoggedIn && !isLoggingIn && !isOfflineDrafts) return '/login';
      if (auth.isLoggedIn && isLoggingIn) return '/sales';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, __) => _fadePage(const LoginScreen()),
      ),
      GoRoute(
        path: '/sales',
        pageBuilder: (_, __) => _fadePage(const MainShell()),
      ),
      GoRoute(
        path: '/incoming',
        pageBuilder: (_, __) => _fadePage(const MainShell()),
      ),
      GoRoute(
        path: '/inventory',
        pageBuilder: (_, __) => _fadePage(const MainShell()),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (_, __) => _fadePage(const MainShell()),
      ),
      GoRoute(
        path: '/drafts',
        pageBuilder: (_, __) => _slidePage(const OfflineDraftScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, __) => _slidePage(const SettingsScreen()),
      ),
    ],
  );
}
