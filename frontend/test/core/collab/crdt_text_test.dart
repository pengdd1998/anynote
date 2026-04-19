import 'package:anynote/core/collab/crdt_text.dart';
import 'package:anynote/core/collab/merge_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ===========================================================================
  // CRDTText -- basic local operations
  // ===========================================================================

  group('CRDTText basics', () {
    test('empty CRDT has empty text', () {
      final crdt = CRDTText('site-A');
      expect(crdt.text, isEmpty);
      expect(crdt.isEmpty, isTrue);
    });

    test('clock starts at zero', () {
      final crdt = CRDTText('site-A');
      expect(crdt.clock, equals(0));
    });

    test('clock increments monotonically', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      expect(crdt.clock, equals(3));

      crdt.localInsert(1, 'x');
      expect(crdt.clock, equals(4));

      crdt.localDelete(0, 1);
      // Delete does not advance the clock.
      expect(crdt.clock, equals(4));
    });

    test('local insert appends text', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'hello');
      expect(crdt.text, equals('hello'));

      crdt.localInsert(5, ' world');
      expect(crdt.text, equals('hello world'));
    });

    test('local insert at beginning', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'world');
      crdt.localInsert(0, 'hello ');
      expect(crdt.text, equals('hello world'));
    });

    test('local insert in middle', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'helo');
      crdt.localInsert(2, 'l');
      expect(crdt.text, equals('hello'));
    });

    test('local delete removes characters', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'hello world');
      final deleted = crdt.localDelete(5, 6); // delete ' world'
      expect(crdt.text, equals('hello'));
      expect(deleted.length, equals(6));
    });

    test('local delete at beginning', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      crdt.localDelete(0, 1);
      expect(crdt.text, equals('bc'));
    });

    test('local delete entire content', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      crdt.localDelete(0, 3);
      expect(crdt.text, isEmpty);
    });

    test('local insert empty string returns no nodes', () {
      final crdt = CRDTText('site-A');
      final nodes = crdt.localInsert(0, '');
      expect(nodes, isEmpty);
      expect(crdt.text, isEmpty);
    });
  });

  // ===========================================================================
  // CRDTText -- remote operations & convergence
  // ===========================================================================

  group('CRDTText convergence', () {
    test('remote insert converges (sequential inserts from two sites)', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // A types "hello"
      final opsA = a.localInsert(0, 'hello');
      expect(a.text, equals('hello'));

      // B receives A's ops and applies them
      for (final node in opsA) {
        b.remoteInsert(node);
      }
      expect(b.text, equals('hello'));

      // B types " world"
      final opsB = b.localInsert(5, ' world');

      // A receives B's ops
      for (final node in opsB) {
        a.remoteInsert(node);
      }

      expect(a.text, equals('hello world'));
      expect(b.text, equals('hello world'));
    });

    test('remote insert converges (concurrent inserts at same position)', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // Both start with the same base text "ab"
      a.localInsert(0, 'ab');
      final baseOps = a.getOperations();
      for (final node in baseOps) {
        b.remoteInsert(node);
      }
      expect(a.text, equals('ab'));
      expect(b.text, equals('ab'));

      // A inserts 'X' between 'a' and 'b' (index 1)
      final opsA = a.localInsert(1, 'X');

      // B inserts 'Y' between 'a' and 'b' (index 1), concurrently
      final opsB = b.localInsert(1, 'Y');

      // Now sync: A receives B's op, B receives A's op
      for (final node in opsB) {
        a.remoteInsert(node);
      }
      for (final node in opsA) {
        b.remoteInsert(node);
      }

      // Both must converge to the same text.
      expect(a.text, equals(b.text));
      // Concurrent inserts at the same position are ordered by siteId.
      // site-A < site-B, so X comes before Y: "aXYb".
      expect(a.text, equals('aXYb'));
    });

    test('remote delete converges (concurrent deletes)', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // Both start with "hello"
      a.localInsert(0, 'hello');
      for (final node in a.getOperations()) {
        b.remoteInsert(node);
      }

      // A deletes 'h'
      final delA = a.localDelete(0, 1);
      expect(a.text, equals('ello'));

      // B deletes 'o'
      final delB = b.localDelete(4, 1);
      expect(b.text, equals('hell'));

      // Sync deletes
      for (final id in delA) {
        b.remoteDelete(id);
      }
      for (final id in delB) {
        a.remoteDelete(id);
      }

      expect(a.text, equals('ell'));
      expect(b.text, equals('ell'));
    });

    test('merge from two sites produces identical text', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // A builds "abc"
      a.localInsert(0, 'abc');

      // B builds "xyz"
      b.localInsert(0, 'xyz');

      // Full merge: A sends all ops to B, B sends all ops to A
      a.merge(b.getOperations());
      b.merge(a.getOperations());

      expect(a.text, equals(b.text));
      // Concurrent inserts at position 0: all of A's characters are in the
      // anchor group of '' with siteId < site-B, so A's block comes first.
      expect(a.text, equals('abcxyz'));
    });

    test('three-way merge converges', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');
      final c = CRDTText('site-C');

      // A creates base text "base"
      a.localInsert(0, 'base');
      final baseOps = a.getOperations();

      // B and C receive the base
      b.merge(baseOps);
      c.merge(baseOps);

      // Each site makes a concurrent edit at the end
      a.localInsert(4, '-A');
      b.localInsert(4, '-B');
      c.localInsert(4, '-C');

      // Star merge: every site receives ops from every other site
      a.merge(b.getOperations());
      a.merge(c.getOperations());

      b.merge(a.getOperations());
      b.merge(c.getOperations());

      c.merge(a.getOperations());
      c.merge(b.getOperations());

      // All three must converge to the same text.
      expect(a.text, equals(b.text));
      expect(b.text, equals(c.text));

      // The suffix order is by siteId: A, B, C.
      expect(a.text, equals('base-A-B-C'));
    });

    test('insert-delete-insert sequence converges', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // A creates "abc"
      a.localInsert(0, 'abc');
      b.merge(a.getOperations());
      expect(b.text, equals('abc'));

      // A deletes 'b' -> "ac"
      final delOps = a.localDelete(1, 1);
      for (final id in delOps) {
        b.remoteDelete(id);
      }
      expect(a.text, equals('ac'));
      expect(b.text, equals('ac'));

      // B inserts 'X' at position 1 -> "aXc"
      final insOps = b.localInsert(1, 'X');
      for (final node in insOps) {
        a.remoteInsert(node);
      }
      expect(b.text, equals('aXc'));
      expect(a.text, equals('aXc'));

      // Verify convergence
      expect(a.text, equals(b.text));
    });

    test('remote insert of duplicate id is idempotent', () {
      final a = CRDTText('site-A');
      final nodes = a.localInsert(0, 'ab');

      final b = CRDTText('site-B');
      // Apply the same op twice.
      b.remoteInsert(nodes[0]);
      b.remoteInsert(nodes[0]);
      b.remoteInsert(nodes[1]);

      expect(b.text, equals('ab'));
    });

    test('merge handles tombstones from remote', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // A creates "abc" and deletes 'b'
      a.localInsert(0, 'abc');
      a.localDelete(1, 1);
      expect(a.text, equals('ac'));

      // B receives all of A's operations via merge
      b.merge(a.getOperations());
      expect(b.text, equals('ac'));
    });

    test('merge applies deletion to existing node', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // A creates "abc"
      final insOps = a.localInsert(0, 'abc');
      // B receives inserts
      b.merge(insOps);
      expect(b.text, equals('abc'));

      // A deletes 'b'
      final delIds = a.localDelete(1, 1);

      // Build tombstone nodes for the merge
      final tombstones = delIds.map((id) {
        final node = a.getOperations().firstWhere((n) => n.id == id);
        return RGANode(
          id: node.id,
          leftOriginId: node.leftOriginId,
          rightOriginId: node.rightOriginId,
          siteId: node.siteId,
          clock: node.clock,
          value: '',
          isDeleted: true,
        );
      }).toList();

      b.merge(tombstones);
      expect(b.text, equals('ac'));
    });
  });

  // ===========================================================================
  // CRDTText -- serialization
  // ===========================================================================

  group('CRDTText serialization', () {
    test('toJson/fromJson round-trip preserves text', () {
      final original = CRDTText('site-A');
      original.localInsert(0, 'hello');
      original.localDelete(0, 1);
      original.localInsert(0, 'H');

      final json = original.toJson();
      final restored = CRDTText.fromJson(json);

      expect(restored.text, equals(original.text));
      expect(restored.siteId, equals('site-A'));
      expect(restored.clock, equals(original.clock));
      expect(restored.nodeCount, equals(original.nodeCount));
    });

    test('toJson/fromJson round-trip for complex concurrent document', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      a.localInsert(0, 'abc');
      b.merge(a.getOperations());

      a.localInsert(1, 'X');
      b.localInsert(1, 'Y');

      a.merge(b.getOperations());
      b.merge(a.getOperations());

      final jsonA = a.toJson();
      final restoredA = CRDTText.fromJson(jsonA);

      expect(restoredA.text, equals(a.text));
      expect(restoredA.text, equals(b.text));
    });

    test('RGANode toJson/fromJson round-trip', () {
      final node = RGANode(
        id: 'site-A:1',
        leftOriginId: 'site-A:0',
        rightOriginId: 'site-A:2',
        siteId: 'site-A',
        clock: 1,
        value: 'x',
      );
      final json = node.toJson();
      final restored = RGANode.fromJson(json);

      expect(restored.id, equals(node.id));
      expect(restored.leftOriginId, equals(node.leftOriginId));
      expect(restored.rightOriginId, equals(node.rightOriginId));
      expect(restored.siteId, equals(node.siteId));
      expect(restored.clock, equals(node.clock));
      expect(restored.value, equals(node.value));
      expect(restored.isDeleted, equals(node.isDeleted));
    });

    test('RGANode.fromJson defaults deleted to false and rightOrigin to empty', () {
      final json = {
        'id': 's:1',
        'left_origin': '',
        'site': 's',
        'clock': 1,
        'value': 'a',
        // 'deleted' and 'right_origin' intentionally omitted
      };
      final node = RGANode.fromJson(json);
      expect(node.isDeleted, isFalse);
      expect(node.rightOriginId, isEmpty);
    });
  });

  // ===========================================================================
  // MergeEngine
  // ===========================================================================

  group('MergeEngine', () {
    test('getDocument creates new document on first access', () {
      final engine = MergeEngine('site-A');
      expect(engine.hasDocument('note-1'), isFalse);

      final doc = engine.getDocument('note-1');
      expect(doc, isNotNull);
      expect(doc.siteId, equals('site-A'));
      expect(engine.hasDocument('note-1'), isTrue);
    });

    test('getDocument returns same instance for same noteId', () {
      final engine = MergeEngine('site-A');
      final doc1 = engine.getDocument('note-1');
      final doc2 = engine.getDocument('note-1');
      expect(identical(doc1, doc2), isTrue);
    });

    test('removeDocument removes the document', () {
      final engine = MergeEngine('site-A');
      engine.getDocument('note-1');
      expect(engine.hasDocument('note-1'), isTrue);

      engine.removeDocument('note-1');
      expect(engine.hasDocument('note-1'), isFalse);
    });

    test('mergeRemote applies remote operations', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      final docA = engineA.getDocument('note-1');
      final ops = docA.localInsert(0, 'hello');

      final result = engineB.mergeRemote('note-1', ops);
      expect(result.appliedCount, equals(5));
      expect(result.hasChanges, isTrue);

      final docB = engineB.getDocument('note-1');
      expect(docB.text, equals('hello'));
    });

    test('mergeRemote reports no changes when ops are already applied', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      final ops = doc.localInsert(0, 'abc');

      // Merge the same ops back (they are already present).
      final result = engine.mergeRemote('note-1', ops);
      // appliedCount still counts the ops but text did not change.
      expect(result.hasChanges, isFalse);
    });

    test('getOpsSince returns only newer operations', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'abc'); // clock goes to 3

      final opsSince0 = engine.getOpsSince('note-1', 0);
      expect(opsSince0.length, equals(3));

      final opsSince2 = engine.getOpsSince('note-1', 2);
      expect(opsSince2.length, equals(1));

      final opsSince10 = engine.getOpsSince('note-1', 10);
      expect(opsSince10, isEmpty);
    });

    test('mergeRemote converges two engines', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      // A types in note-1
      final docA = engineA.getDocument('note-1');
      final opsA1 = docA.localInsert(0, 'hello');
      engineB.mergeRemote('note-1', opsA1);

      // B types in note-1
      final docB = engineB.getDocument('note-1');
      final opsB1 = docB.localInsert(5, ' world');
      engineA.mergeRemote('note-1', opsB1);

      expect(docA.text, equals('hello world'));
      expect(docB.text, equals('hello world'));
    });

    test('MergeEngine toJson/fromJson round-trip', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'test');

      final json = engine.toJson();
      final restored = MergeEngine.fromJson(json);

      expect(restored.siteId, equals('site-A'));
      expect(restored.hasDocument('note-1'), isTrue);

      final restoredDoc = restored.getDocument('note-1');
      expect(restoredDoc.text, equals('test'));
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('edge cases', () {
    test('large concurrent merge converges', () {
      final a = CRDTText('site-A');
      final b = CRDTText('site-B');

      // Each site independently builds a paragraph at position 0.
      a.localInsert(0, 'The quick brown fox');
      b.localInsert(0, 'jumps over the lazy dog');

      // Merge both ways.
      a.merge(b.getOperations());
      b.merge(a.getOperations());

      expect(a.text, equals(b.text));
      // site-A < site-B, so A's text comes first.
      expect(a.text, equals('The quick brown foxjumps over the lazy dog'));
    });

    test('many concurrent inserts at position 0 converge', () {
      final sites = List.generate(5, (i) => CRDTText('site-$i'));

      // Each site inserts a single letter at position 0, concurrently.
      final allOps = <RGANode>[];
      for (final site in sites) {
        final ops = site.localInsert(0, site.siteId.substring(5));
        allOps.addAll(ops);
      }

      // Every site receives all ops.
      for (final site in sites) {
        site.merge(allOps);
      }

      // All must converge.
      final expected = sites.first.text;
      for (final site in sites) {
        expect(site.text, equals(expected));
      }
      // Ordered by siteId: site-0, site-1, site-2, site-3, site-4.
      expect(expected, equals('01234'));
    });

    test('delete beyond visible length is safe', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'ab');
      final deleted = crdt.localDelete(1, 100);
      expect(deleted.length, equals(1)); // Only 'b' was visible to delete.
      expect(crdt.text, equals('a'));
    });

    test('insert at index beyond end appends', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'a');
      crdt.localInsert(100, 'b'); // Way past the end.
      expect(crdt.text, equals('ab'));
    });
  });
}
