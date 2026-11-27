import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/api_client.dart';

class IntegrationRepository {
  IntegrationRepository(this.api);
  final ApiClient api;
  Future<Position> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException(
        'Location services are disabled',
        code: 'LOCATION_DISABLED',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Location permission was denied',
        code: 'LOCATION_DENIED',
      );
    }
    return Geolocator.getCurrentPosition();
  }

  Future<Map<String, dynamic>> ai(String task, String content) async {
    final r = await api.post<Map<String, dynamic>>(
      '/ai/assist',
      data: {'task': task, 'content': content},
    );
    return r.data!['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPayment(
    String invoiceId,
    String key,
  ) async {
    final r = await api.post<Map<String, dynamic>>(
      '/payments/create-order',
      data: {'invoiceId': invoiceId},
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return r.data!['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> notifications() async {
    final r = await api.get<Map<String, dynamic>>('/notifications');
    return r.data!['data'] as List<dynamic>;
  }

  Future<List<dynamic>> messages(String bookingId) async {
    final r = await api.get<Map<String, dynamic>>('/bookings/$bookingId/chat');
    return r.data!['data'] as List<dynamic>;
  }

  Future<void> sendMessage(String bookingId, String message) =>
      api.post('/bookings/$bookingId/chat', data: {'message': message});
  Future<Map<String, dynamic>> sync(
    String key,
    String operation,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    final r = await api.post<Map<String, dynamic>>(
      '/sync',
      data: {
        'idempotencyKey': key,
        'operation': operation,
        'entityId': entityId,
        'payload': payload,
      },
    );
    return r.data!;
  }

  String encodeQueue(List<Map<String, dynamic>> queue) => jsonEncode(queue);
  List<Map<String, dynamic>> decodeQueue(String? raw) =>
      raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}
