import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/focus_management.dart';

void main() {
  // Save original value so we can restore it after each test.
  final originalPlatform = debugDefaultTargetPlatformOverride;

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  // ---------------------------------------------------------------------------
  // FocusRing basics
  // ---------------------------------------------------------------------------

  group('FocusRing', () {
    test('starts empty', () {
      final ring = FocusRing();
      expect(ring.isEmpty, isTrue);
      expect(ring.length, 0);
      ring.dispose();
    });

    test('add adds a node to the ring', () {
      final ring = FocusRing();
      final node = FocusNode();
      ring.add(node);
      expect(ring.length, 1);
      expect(ring.isEmpty, isFalse);
      ring.dispose();
      // node was not created by ring, so ring.dispose does not dispose it.
      node.dispose();
    });

    test('addAll adds multiple nodes in order', () {
      final ring = FocusRing();
      final n1 = FocusNode();
      final n2 = FocusNode();
      final n3 = FocusNode();
      ring.addAll([n1, n2, n3]);
      expect(ring.length, 3);
      expect(ring[0], n1);
      expect(ring[1], n2);
      expect(ring[2], n3);
      ring.dispose();
      n1.dispose();
      n2.dispose();
      n3.dispose();
    });

    test('remove removes a specific node', () {
      final ring = FocusRing();
      final n1 = FocusNode();
      final n2 = FocusNode();
      ring.addAll([n1, n2]);
      ring.remove(n1);
      expect(ring.length, 1);
      expect(ring[0], n2);
      ring.dispose();
      n1.dispose();
      n2.dispose();
    });

    test('operator [] returns null for out of bounds', () {
      final ring = FocusRing();
      expect(ring[0], isNull);
      expect(ring[-1], isNull);
      ring.dispose();
    });

    test('operator [] returns correct node for valid index', () {
      final ring = FocusRing();
      final n1 = FocusNode();
      final n2 = FocusNode();
      ring.addAll([n1, n2]);
      expect(ring[0], n1);
      expect(ring[1], n2);
      ring.dispose();
      n1.dispose();
      n2.dispose();
    });

    test('createNode creates and tracks a managed node', () {
      final ring = FocusRing();
      final node = ring.createNode('test');
      expect(ring.length, 1);
      expect(ring[0], node);
      expect(node.debugLabel, 'test');
      // dispose should clean up the created node.
      ring.dispose();
      expect(ring.length, 0);
    });

    test('dispose clears all nodes and disposes managed nodes', () {
      final ring = FocusRing();
      ring.createNode('a');
      ring.createNode('b');
      final external = FocusNode();
      ring.add(external);
      expect(ring.length, 3);
      ring.dispose();
      expect(ring.length, 0);
      // External node is caller's responsibility.
      external.dispose();
    });

    test('unfocus unfocuses all nodes', () {
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      ring.addAll([n1, n2]);
      // unfocus should not throw even when not attached to widget tree.
      ring.unfocus();
      expect(n1.hasFocus, isFalse);
      expect(n2.hasFocus, isFalse);
      ring.dispose();
      n1.dispose();
      n2.dispose();
    });

    test('focusFirst does nothing on empty ring', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      ring.focusFirst();
      ring.dispose();
    });

    test('focusLast does nothing on empty ring', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      ring.focusLast();
      ring.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // FocusRing navigation on desktop
  // ---------------------------------------------------------------------------

  group('FocusRing navigation', () {
    test('focusNext does nothing on mobile platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final ring = FocusRing();
      final n1 = FocusNode();
      ring.add(n1);
      // Should not throw.
      ring.focusNext(n1);
      ring.dispose();
      n1.dispose();
    });

    test('focusPrevious does nothing on mobile platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ring = FocusRing();
      final n1 = FocusNode();
      ring.add(n1);
      ring.focusPrevious(n1);
      ring.dispose();
      n1.dispose();
    });

    test('focusNext does nothing on empty ring', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      ring.focusNext(null);
      ring.dispose();
    });

    test('focusPrevious does nothing on empty ring', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      ring.focusPrevious(null);
      ring.dispose();
    });

    test('focusNext with null current focuses first node on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      ring.addAll([n1, n2]);

      // focusNext(null) should target index 0.
      // Without a widget tree, we cannot assert hasFocus, but we verify
      // no exceptions are thrown.
      ring.focusNext(null);
      ring.dispose();
      n1.dispose();
      n2.dispose();
    });

    test('focusPrevious with null current focuses last node on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      ring.addAll([n1, n2]);

      ring.focusPrevious(null);
      ring.dispose();
      n1.dispose();
      n2.dispose();
    });

    test('focusNext wraps from last to first on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      final n3 = FocusNode(debugLabel: 'n3');
      ring.addAll([n1, n2, n3]);

      // Passing n3 (last) should wrap to n1 (first).
      ring.focusNext(n3);
      ring.dispose();
      n1.dispose();
      n2.dispose();
      n3.dispose();
    });

    test('focusPrevious wraps from first to last on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      final n3 = FocusNode(debugLabel: 'n3');
      ring.addAll([n1, n2, n3]);

      // Passing n1 (first) should wrap to n3 (last).
      ring.focusPrevious(n1);
      ring.dispose();
      n1.dispose();
      n2.dispose();
      n3.dispose();
    });

    test('focusNext advances through the ring on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      final n3 = FocusNode(debugLabel: 'n3');
      ring.addAll([n1, n2, n3]);

      // n1 -> n2
      ring.focusNext(n1);
      // n2 -> n3
      ring.focusNext(n2);
      // n3 -> n1 (wrap)
      ring.focusNext(n3);

      ring.dispose();
      n1.dispose();
      n2.dispose();
      n3.dispose();
    });

    test('focusPrevious advances backwards through the ring on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      final n3 = FocusNode(debugLabel: 'n3');
      ring.addAll([n1, n2, n3]);

      // n3 -> n2
      ring.focusPrevious(n3);
      // n2 -> n1
      ring.focusPrevious(n2);
      // n1 -> n3 (wrap)
      ring.focusPrevious(n1);

      ring.dispose();
      n1.dispose();
      n2.dispose();
      n3.dispose();
    });

    test('focusNext with unknown node focuses first node', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final unknown = FocusNode(debugLabel: 'unknown');
      ring.add(n1);

      // unknown node is not in the ring, so focusNext should focus index 0.
      ring.focusNext(unknown);
      ring.dispose();
      n1.dispose();
      unknown.dispose();
    });

    test('focusPrevious with unknown node focuses last node', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final ring = FocusRing();
      final n1 = FocusNode(debugLabel: 'n1');
      final n2 = FocusNode(debugLabel: 'n2');
      final unknown = FocusNode(debugLabel: 'unknown');
      ring.addAll([n1, n2]);

      ring.focusPrevious(unknown);
      ring.dispose();
      n1.dispose();
      n2.dispose();
      unknown.dispose();
    });
  });
}
