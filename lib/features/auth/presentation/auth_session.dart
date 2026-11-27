import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../domain/user_role.dart';

class AuthSession extends ChangeNotifier {
  UserRole? _role;
  TokenStore? _tokens;
  ApiClient? _api;
  UserRole? get role => _role;

  Future<void> restore(TokenStore tokens, ApiClient api) async {
    _tokens = tokens;
    _api = api;
    var accessToken = await tokens.access();
    if (accessToken == null) return;
    try {
      var parts = accessToken.split('.');
      if (parts.length != 3) throw const FormatException('Invalid JWT');
      var payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final expiry = (payload['exp'] as num?)?.toInt();
      if (expiry != null &&
          DateTime.now().millisecondsSinceEpoch >= expiry * 1000) {
        if (!await api.refreshSession()) return;
        accessToken = await tokens.access();
        if (accessToken == null) return;
        parts = accessToken.split('.');
        payload =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
                )
                as Map<String, dynamic>;
      }
      _role = switch ('${payload['role']}'.toUpperCase()) {
        'CUSTOMER' => UserRole.customer,
        'TECHNICIAN' => UserRole.technician,
        'ADMIN' || 'MANAGER' => UserRole.manager,
        _ => null,
      };
      if (_role == null) await tokens.clear();
    } catch (_) {
      await tokens.clear();
      _role = null;
    }
  }

  void signIn(UserRole value) {
    _role = value;
    notifyListeners();
  }

  void signOut() {
    _role = null;
    unawaited(_revokeAndClear());
    notifyListeners();
  }

  Future<void> _revokeAndClear() async {
    final token = await _tokens?.refresh();
    try {
      if (token != null) {
        await _api?.post<void>('/auth/logout', data: {'refreshToken': token});
      }
    } catch (_) {
      // Logout remains local when the API is unavailable; token removal is
      // mandatory and server sessions expire independently.
    } finally {
      await _tokens?.clear();
    }
  }
}

final authSession = AuthSession();
