import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/sync/sync_engine.dart';

void main() {
  group('SyncEngine.getDeviceId', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SyncEngine.resetDeviceIdCache();
    });

    tearDown(() {
      SyncEngine.resetDeviceIdCache();
    });

    test('returns a valid UUID v4', () async {
      final deviceId = await SyncEngine.getDeviceId();
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(deviceId),
        isTrue,
        reason: 'Device ID should be a valid UUID v4: $deviceId',
      );
    });

    test('returns same ID on subsequent calls', () async {
      final id1 = await SyncEngine.getDeviceId();
      final id2 = await SyncEngine.getDeviceId();
      expect(id1, equals(id2));
    });

    test('persists ID across cache resets', () async {
      final id1 = await SyncEngine.getDeviceId();
      SyncEngine.resetDeviceIdCache();
      final id2 = await SyncEngine.getDeviceId();
      expect(id1, equals(id2));
    });

    test('uses stored ID from SharedPreferences if available', () async {
      const storedId = 'stored-device-id-1234';
      SharedPreferences.setMockInitialValues({
        'device_id': storedId,
      });
      SyncEngine.resetDeviceIdCache();

      final deviceId = await SyncEngine.getDeviceId();
      expect(deviceId, equals(storedId));
    });

    test('stores newly generated ID in SharedPreferences', () async {
      final deviceId = await SyncEngine.getDeviceId();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_id'), equals(deviceId));
    });
  });

  group('SyncPushItem', () {
    test('toJson includes device_id when non-empty', () {
      final item = SyncPushItem(
        itemId: 'test-id',
        itemType: 'note',
        version: 1,
        encryptedData: [1, 2, 3],
        blobSize: 3,
        deviceId: 'device-123',
      );
      final json = item.toJson();
      expect(json['device_id'], equals('device-123'));
    });

    test('toJson omits device_id when empty', () {
      final item = SyncPushItem(
        itemId: 'test-id',
        itemType: 'note',
        version: 1,
        encryptedData: [1, 2, 3],
        blobSize: 3,
      );
      final json = item.toJson();
      expect(json.containsKey('device_id'), isFalse);
    });
  });
}
