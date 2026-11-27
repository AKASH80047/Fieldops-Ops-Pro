import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/auth_session.dart';
import '../../firebase_options.dart';
import '../network/api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

@immutable
class ForegroundNotification {
  const ForegroundNotification({
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
  });

  factory ForegroundNotification.fromRemoteMessage(RemoteMessage message) =>
      ForegroundNotification(
        title: message.notification?.title ?? 'FieldOps Pro',
        body: message.notification?.body ?? '',
        data: Map<String, dynamic>.unmodifiable(message.data),
        receivedAt: DateTime.now(),
      );

  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
}

class FirebaseMessagingService {
  const FirebaseMessagingService._();

  static final ValueNotifier<ForegroundNotification?>
  latestForegroundNotification = ValueNotifier(null);
  static final StreamController<ForegroundNotification>
  _foregroundNotifications = StreamController.broadcast();

  static Stream<ForegroundNotification> get foregroundNotifications =>
      _foregroundNotifications.stream;

  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static AuthSession? _session;
  static ApiClient? _api;
  static bool _initialized = false;

  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Initializes Firebase without prompting for notification permission.
  /// Permission is requested only after an authenticated, non-demo session is
  /// attached through [bindAuthenticatedSession].
  static Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      _messageSubscription ??= FirebaseMessaging.onMessage.listen((message) {
        final notification = ForegroundNotification.fromRemoteMessage(message);
        latestForegroundNotification.value = notification;
        _foregroundNotifications.add(notification);
      });
      _initialized = true;
    } catch (error) {
      // Messaging must never prevent the rest of the app from starting. A
      // later authenticated sync retries initialization.
      if (kDebugMode) debugPrint('Firebase messaging initialization: $error');
    }
  }

  /// Keeps the FCM device token associated with the currently authenticated
  /// API user. Demo builds deliberately skip permission prompts and network
  /// registration so widget tests and local mock sessions remain deterministic.
  static Future<void> bindAuthenticatedSession(
    AuthSession session,
    ApiClient api,
  ) async {
    if (!identical(_session, session)) {
      _session?.removeListener(_onAuthChanged);
      _session = session;
      session.addListener(_onAuthChanged);
    }
    _api = api;
    await _syncAuthenticationState();
  }

  static void _onAuthChanged() {
    unawaited(_syncAuthenticationState());
  }

  static Future<void> _syncAuthenticationState() async {
    final authenticated = _session?.role != null;
    if (!authenticated) {
      if (isSupported && !ApiConfig.useMocks) {
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (error) {
          if (kDebugMode) debugPrint('FCM token cleanup: $error');
        }
      }
      return;
    }

    if (ApiConfig.useMocks || !isSupported) return;

    await initialize();
    if (!_initialized || _session?.role == null) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);

      _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
        onError: (Object error) {
          if (kDebugMode) debugPrint('FCM token refresh: $error');
        },
      );
    } catch (error) {
      // Permission, APNs, Play Services, and networking can all be unavailable.
      // The authenticated app remains usable and retries on the next session.
      if (kDebugMode) debugPrint('FCM authenticated sync: $error');
    }
  }

  static Future<void> _registerToken(String token) async {
    final api = _api;
    if (api == null || _session?.role == null || ApiConfig.useMocks) return;

    try {
      await api.post<Map<String, dynamic>>(
        '/notifications/device',
        data: {'token': token, 'platform': _platformName},
      );
    } catch (error) {
      // Token registration is best-effort. onTokenRefresh or a future login
      // will retry without blocking authentication.
      if (kDebugMode) debugPrint('FCM device registration: $error');
    }
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => defaultTargetPlatform.name,
    };
  }

  static void clearForegroundNotification() {
    latestForegroundNotification.value = null;
  }
}
