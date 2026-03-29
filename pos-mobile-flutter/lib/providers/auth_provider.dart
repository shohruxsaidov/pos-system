import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

const _tokenKey = 'pos_token';
const _userKey = 'pos_user';

class AuthState {
  final User? user;
  final String? token;

  const AuthState({this.user, this.token});

  bool get isLoggedIn => user != null && token != null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (token != null && userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      apiService.setToken(token);
      state = AuthState(user: user, token: token);
      Sentry.logger.fmt.info('Session restored for user %s (role: %s)', [user.name, user.role]);
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final res = await apiService.get('/api/auth/users');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<void> login(int userId, String pin) async {
    try {
      final res = await apiService.post('/api/auth/login', data: {
        'user_id': userId,
        'pin': pin,
      });
      final token = res.data['token'] as String;
      final user = User.fromJson(res.data['user']);
      apiService.setToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));

      state = AuthState(user: user, token: token);
      Sentry.logger.fmt.info('Login successful: %s (role: %s)', [user.name, user.role]);
    } catch (e, st) {
      Sentry.logger.fmt.warning('Login failed for user_id %d: %s', [userId, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> logout() async {
    final name = state.user?.name ?? 'unknown';
    apiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    state = const AuthState();
    Sentry.logger.fmt.info('User logged out: %s', [name]);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
