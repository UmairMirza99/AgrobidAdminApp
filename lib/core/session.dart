import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// The signed-in administrator. Notifies the router when login state changes.
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onSessionExpired = () {
      user = null;
      notifyListeners();
    };
  }

  final ApiClient api;
  Map<String, dynamic>? user;
  bool ready = false;

  bool get loggedIn => user != null;
  String get name => (user?['full_name'] ?? 'Admin').toString();

  Future<void> restore() async {
    final saved = await api.store.read('user');
    final token = await api.store.read('access_token');
    if (saved != null && token != null) {
      user = jsonDecode(saved) as Map<String, dynamic>;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await api.post('/api/v1/admin/auth/login', body: {'email': email.trim(), 'password': password}) as Map<String, dynamic>;
    await api.saveTokens(data['access_token'] as String, data['refresh_token'] as String);
    user = data['user'] as Map<String, dynamic>;
    await api.store.write('user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> logout() async {
    final refresh = await api.store.read('refresh_token');
    if (refresh != null) {
      try {
        await api.post('/api/v1/auth/logout', body: {'refresh_token': refresh});
      } catch (_) {
        // The token may already be expired; signing out locally is enough.
      }
    }
    await api.store.clear();
    user = null;
    notifyListeners();
  }
}
