import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/sync/conflict_resolver.dart';

void main() {
  group('ConflictResolver', () {
    test('local wins when newer', () {
      final result = ConflictResolver.resolve<String>(
        local: 'local-value',
        remote: 'remote-value',
        localUpdatedAt: DateTime(2024, 1, 2),
        remoteUpdatedAt: DateTime(2024, 1, 1),
      );

      expect(result.winner, 'local-value');
      expect(result.loser, 'remote-value');
      expect(result.hadConflict, true);
    });

    test('remote wins when newer', () {
      final result = ConflictResolver.resolve<String>(
        local: 'local-value',
        remote: 'remote-value',
        localUpdatedAt: DateTime(2024, 1, 1),
        remoteUpdatedAt: DateTime(2024, 1, 2),
      );

      expect(result.winner, 'remote-value');
      expect(result.loser, 'local-value');
    });

    test('tiebreaker uses device ID when timestamps equal', () {
      final ts = DateTime(2024, 1, 1);

      final result = ConflictResolver.resolve<String>(
        local: 'local-value',
        remote: 'remote-value',
        localUpdatedAt: ts,
        remoteUpdatedAt: ts,
        localDeviceId: 'device-b',
        remoteDeviceId: 'device-a',
      );

      // 'device-b' >= 'device-a' → local wins
      expect(result.winner, 'local-value');
    });
  });
}
