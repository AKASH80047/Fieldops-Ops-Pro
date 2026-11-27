import 'package:field_ops_pro/core/notifications/firebase_messaging_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreground notification exposes safe display data', () {
    final notification = ForegroundNotification.fromRemoteMessage(
      const RemoteMessage(
        notification: RemoteNotification(
          title: 'New nearby job',
          body: 'An electrical service request is available.',
        ),
        data: {'type': 'JOB_ASSIGNED', 'jobId': 'job-1'},
      ),
    );

    expect(notification.title, 'New nearby job');
    expect(notification.body, 'An electrical service request is available.');
    expect(notification.data['jobId'], 'job-1');
    expect(
      () => notification.data['jobId'] = 'changed',
      throwsUnsupportedError,
    );
  });

  test('foreground notification can be cleared after it is consumed', () {
    FirebaseMessagingService.latestForegroundNotification.value =
        ForegroundNotification(
          title: 'Title',
          body: 'Body',
          data: const {},
          receivedAt: DateTime(2026),
        );

    FirebaseMessagingService.clearForegroundNotification();

    expect(FirebaseMessagingService.latestForegroundNotification.value, isNull);
  });
}
