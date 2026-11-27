import 'package:dio/dio.dart';
import 'package:field_ops_pro/core/network/api_client.dart';
import 'package:field_ops_pro/features/auth/data/auth_repository.dart';
import 'package:field_ops_pro/features/auth/domain/user_role.dart';
import 'package:field_ops_pro/features/auth/presentation/auth_bloc.dart';
import 'package:field_ops_pro/features/auth/presentation/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  test('mock authentication returns the selected role', () async {
    final role = await MockAuthRepository().signIn(
      'demo@fieldops.io',
      'password',
      UserRole.manager,
    );
    expect(role, UserRole.manager);
  });

  test('auth bloc emits loading then authenticated', () async {
    final bloc = AuthBloc(MockAuthRepository());
    expectLater(
      bloc.stream,
      emitsInOrder([isA<AuthLoading>(), isA<Authenticated>()]),
    );
    bloc.add(
      const SignInRequested(
        'demo@fieldops.io',
        'password',
        UserRole.technician,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await bloc.close();
  });

  test('mock session clears on logout', () {
    authSession.signIn(UserRole.customer);
    expect(authSession.role, UserRole.customer);
    authSession.signOut();
    expect(authSession.role, isNull);
  });

  test('API authentication clears tokens on selected role mismatch', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final tokens = TokenStore(storage);
    final dio = Dio();
    final api = ApiClient(dio, tokens);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'accessToken': 'access-token',
                'refreshToken': 'refresh-token',
                'user': {'role': 'TECHNICIAN'},
              },
            },
          ),
        ),
      ),
    );

    await expectLater(
      ApiAuthRepository(
        api,
        tokens,
      ).signIn('demo@fieldops.io', 'password', UserRole.customer),
      throwsA(isA<ApiException>()),
    );
    expect(await tokens.access(), isNull);
    expect(await tokens.refresh(), isNull);
  });
}
