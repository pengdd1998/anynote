import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anynote/core/notifications/local_notification_service.dart';

void main() {
  late LocalNotificationService service;

  setUp(() {
    service = LocalNotificationService();
  });

  group('LocalNotificationService', () {
    test('is not initialized before init()', () {
      expect(service.isInitialized, isFalse);
    });

    test('init() completes without error on unsupported platform', () async {
      await service.init();
      expect(service.isInitialized, isTrue);
    });

    test('repeated init() is idempotent', () async {
      await service.init();
      expect(service.isInitialized, isTrue);
      // Second call should return immediately without error.
      await service.init();
      expect(service.isInitialized, isTrue);
    });

    test('requestPermissions returns false before init', () async {
      final result = await service.requestPermissions();
      expect(result, isFalse);
    });

    test('requestPermissions returns false on unsupported platform', () async {
      await service.init();
      final result = await service.requestPermissions();
      expect(result, isFalse);
    });

    test('scheduleNotification completes without error', () async {
      await service.init();
      // Should not throw on unsupported platform.
      await service.scheduleNotification(
        id: 1,
        title: 'Test',
        body: 'Test body',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
        payload: 'note:123',
      );
    });

    test('scheduleNotification with recurring completes', () async {
      await service.init();
      await service.scheduleNotification(
        id: 2,
        title: 'Recurring',
        body: 'Daily reminder',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
        recurring: 'daily',
      );
    });

    test('cancelNotification completes without error', () async {
      await service.init();
      await service.cancelNotification(1);
    });

    test('cancelAllNotifications completes without error', () async {
      await service.init();
      await service.cancelAllNotifications();
    });

    test('showNotification completes without error', () async {
      await service.init();
      await service.showNotification(
        id: 1,
        title: 'Immediate',
        body: 'Test notification',
        payload: 'note:456',
      );
    });

    test('setOnNotificationTap stores callback', () {
      String? captured;
      service.setOnNotificationTap((payload) {
        captured = payload;
      });
      // The callback was stored without error. It has not been invoked yet.
      expect(captured, isNull);
    });

    test('provider creates instance', () {
      final container = ProviderContainer();
      final instance = container.read(localNotificationServiceProvider);
      expect(instance, isA<LocalNotificationService>());
      container.dispose();
    });
  });
}
