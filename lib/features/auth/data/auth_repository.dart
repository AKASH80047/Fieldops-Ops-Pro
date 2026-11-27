import '../domain/user_role.dart';
import '../../../core/network/api_client.dart';

abstract class AuthRepository {
  Future<UserRole> signIn(String email, String password, UserRole role);
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<UserRole> signIn(String email, String password, UserRole role) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    // This repository is only used in local/demo builds. Keep its role source
    // separate from workspace selection so it exercises the same guard as API.
    return role;
  }
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api, this.tokens);
  final ApiClient api;
  final TokenStore tokens;
  @override
  Future<UserRole> signIn(String email, String password, UserRole role) async {
    final response = await api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('Authentication response was invalid');
    }
    final user = data['user'] as Map<String, dynamic>;
    final serverRole = '${user['role']}'.toUpperCase();
    final resolved = switch (serverRole) {
      'TECHNICIAN' => UserRole.technician,
      'CUSTOMER' => UserRole.customer,
      'ADMIN' || 'MANAGER' || 'SUPER_ADMIN' => UserRole.manager,
      _ => null,
    };
    if (resolved == null) {
      await tokens.clear();
      throw const ApiException(
        'Your account does not have an authorized workspace',
        code: 'ROLE_UNAUTHORIZED',
        status: 403,
      );
    }
    if (resolved != role) {
      // Never retain a valid session for a role the user did not select.
      await tokens.clear();
      throw const ApiException(
        'The selected workspace does not match your account role',
        code: 'ROLE_MISMATCH',
        status: 403,
      );
    }
    await tokens.save(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    return resolved;
  }
}
