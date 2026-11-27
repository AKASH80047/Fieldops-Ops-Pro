import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1',
  );
  static const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  static void validateForRelease() {
    if (kReleaseMode && !useMocks && !baseUrl.startsWith('https://')) {
      throw StateError('Production API_BASE_URL must use HTTPS.');
    }
  }
}

class TokenStore {
  TokenStore(this.storage);
  final FlutterSecureStorage storage;
  static const accessKey = 'fieldops_access_token',
      refreshKey = 'fieldops_refresh_token';
  Future<String?> access() => storage.read(key: accessKey);
  Future<String?> refresh() => storage.read(key: refreshKey);
  Future<void> save(String access, String refresh) async {
    await storage.write(key: accessKey, value: access);
    await storage.write(key: refreshKey, value: refresh);
  }

  Future<void> clear() async {
    await storage.delete(key: accessKey);
    await storage.delete(key: refreshKey);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;
  factory ApiException.fromDio(DioException e) {
    final body = e.response?.data;
    final value = body is Map ? body['error'] : null;
    return ApiException(
      value is Map
          ? '${value['message'] ?? 'Request failed'}'
          : e.message ?? 'Network request failed',
      code: value is Map ? '${value['code']}' : null,
      status: e.response?.statusCode,
    );
  }
}

class ApiClient {
  ApiClient(this.dio, this.tokens) {
    dio.options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    );
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (o, h) async {
          final token = await tokens.access();
          if (token != null) o.headers['Authorization'] = 'Bearer $token';
          h.next(o);
        },
        onError: _onError,
      ),
    );
  }
  final Dio dio;
  final TokenStore tokens;
  Completer<bool>? refreshing;
  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    if (e.response?.statusCode != 401 ||
        e.requestOptions.extra['retried'] == true ||
        e.requestOptions.path.contains('/auth/refresh-token')) {
      h.next(e);
      return;
    }
    final ok = await _refresh();
    if (!ok) {
      await tokens.clear();
      h.next(e);
      return;
    }
    try {
      final r = e.requestOptions;
      r.extra['retried'] = true;
      r.headers['Authorization'] = 'Bearer ${await tokens.access()}';
      h.resolve(await dio.fetch(r));
    } on DioException catch (x) {
      h.next(x);
    }
  }

  Future<bool> _refresh() async {
    if (refreshing != null) return refreshing!.future;
    refreshing = Completer<bool>();
    try {
      final token = await tokens.refresh();
      if (token == null) {
        refreshing!.complete(false);
      } else {
        final r = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
            .post<Map<String, dynamic>>(
              '/auth/refresh-token',
              data: {'refreshToken': token},
            );
        final data = r.data!['data'] as Map<String, dynamic>;
        await tokens.save(
          data['accessToken'] as String,
          data['refreshToken'] as String,
        );
        refreshing!.complete(true);
      }
    } catch (_) {
      refreshing!.complete(false);
    }
    final result = await refreshing!.future;
    refreshing = null;
    return result;
  }

  /// Refreshes a persisted session during application startup.
  Future<bool> refreshSession() => _refresh();

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      return await dio.get<T>(path, queryParameters: query);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(path, data: data, options: options);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Response<T>> put<T>(String path, {Object? data}) async {
    try {
      return await dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) async {
    try {
      return await dio.patch<T>(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
