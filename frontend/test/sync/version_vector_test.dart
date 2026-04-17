import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/sync/version_vector.dart';

void main() {
  group('VersionVector', () {
    test('starts at version 0 for unknown items', () {
      final vv = VersionVector();
      expect(vv.get('item-1'), 0);
    });

    test('set stores version', () {
      final vv = VersionVector();
      vv.set('item-1', 5);
      expect(vv.get('item-1'), 5);
    });

    test('set only updates if higher', () {
      final vv = VersionVector();
      vv.set('item-1', 10);
      vv.set('item-1', 5); // lower — should be ignored
      expect(vv.get('item-1'), 10);
    });

    test('increment returns new version', () {
      final vv = VersionVector();
      expect(vv.increment('item-1'), 1);
      expect(vv.increment('item-1'), 2);
      expect(vv.get('item-1'), 2);
    });

    test('maxVersion returns highest across all items', () {
      final vv = VersionVector();
      vv.set('a', 3);
      vv.set('b', 7);
      vv.set('c', 5);
      expect(vv.maxVersion, 7);
    });

    test('merge takes max for each item', () {
      final vv1 = VersionVector();
      vv1.set('a', 5);
      vv1.set('b', 3);

      final vv2 = VersionVector();
      vv2.set('a', 2);
      vv2.set('b', 7);
      vv2.set('c', 4);

      vv1.merge(vv2);

      expect(vv1.get('a'), 5); // kept higher
      expect(vv1.get('b'), 7); // took from vv2
      expect(vv1.get('c'), 4); // new from vv2
    });

    test('toJson/fromJson round-trip', () {
      final vv = VersionVector();
      vv.set('item-1', 10);
      vv.set('item-2', 20);

      final json = vv.toJson();
      final restored = VersionVector.fromJson(json);

      expect(restored.get('item-1'), 10);
      expect(restored.get('item-2'), 20);
      expect(restored.get('item-3'), 0);
    });
  });
}
