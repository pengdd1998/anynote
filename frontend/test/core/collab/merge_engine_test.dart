import 'package:anynote/core/collab/crdt_text.dart';
import 'package:anynote/core/collab/merge_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ===========================================================================
  // MergeEngine -- document lifecycle
  // ===========================================================================

  group('MergeEngine document lifecycle', () {
    test('new engine has no documents', () {
      final engine = MergeEngine('site-A');
      expect(engine.hasDocument('note-1'), isFalse);
      expect(engine.hasDocument('note-2'), isFalse);
    });

    test('getDocument creates a CRDTText with the engine siteId', () {
      final engine = MergeEngine('site-X');
      final doc = engine.getDocument('note-1');
      expect(doc, isNotNull);
      expect(doc.siteId, equals('site-X'));
      expect(doc.text, isEmpty);
    });

    test('getDocument returns the same instance on repeated calls', () {
      final engine = MergeEngine('site-A');
      final first = engine.getDocument('note-1');
      final second = engine.getDocument('note-1');
      expect(identical(first, second), isTrue);
    });

    test('getDocument for different note IDs returns different documents', () {
      final engine = MergeEngine('site-A');
      final doc1 = engine.getDocument('note-1');
      final doc2 = engine.getDocument('note-2');
      expect(identical(doc1, doc2), isFalse);
    });

    test('removeDocument removes the document from the engine', () {
      final engine = MergeEngine('site-A');
      engine.getDocument('note-1');
      expect(engine.hasDocument('note-1'), isTrue);

      engine.removeDocument('note-1');
      expect(engine.hasDocument('note-1'), isFalse);
    });

    test('removeDocument for non-existent noteId is a no-op', () {
      final engine = MergeEngine('site-A');
      // Should not throw.
      engine.removeDocument('nonexistent');
    });

    test('getDocument after removeDocument creates a fresh document', () {
      final engine = MergeEngine('site-A');
      final doc1 = engine.getDocument('note-1');
      doc1.localInsert(0, 'content');

      engine.removeDocument('note-1');
      expect(engine.hasDocument('note-1'), isFalse);

      final doc2 = engine.getDocument('note-1');
      // Freshly created, so it has no content.
      expect(doc2.text, isEmpty);
      expect(identical(doc1, doc2), isFalse);
    });
  });

  // ===========================================================================
  // MergeEngine -- mergeRemote
  // ===========================================================================

  group('MergeEngine mergeRemote', () {
    test('applies remote insert operations and reports changes', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      final docA = engineA.getDocument('note-1');
      final ops = docA.localInsert(0, 'hello');

      final result = engineB.mergeRemote('note-1', ops);

      expect(result.appliedCount, equals(5));
      expect(result.hasChanges, isTrue);
      expect(engineB.getDocument('note-1').text, equals('hello'));
    });

    test('reports no changes when merging already-applied operations', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      final ops = doc.localInsert(0, 'abc');

      final result = engine.mergeRemote('note-1', ops);
      // Nodes are already present in the local document, so text is unchanged.
      expect(result.hasChanges, isFalse);
    });

    test('reports no changes when merging empty operation list', () {
      final engine = MergeEngine('site-A');
      final result = engine.mergeRemote('note-1', []);
      expect(result.appliedCount, equals(0));
      expect(result.hasChanges, isFalse);
    });

    test('newOperations includes all operations after merge', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      final docA = engineA.getDocument('note-1');
      docA.localInsert(0, 'ab');

      final result = engineB.mergeRemote('note-1', docA.getOperations());
      expect(result.newOperations.length, equals(2));
    });

    test('concurrent edits from two engines converge', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      // A types "hello"
      final docA = engineA.getDocument('note-1');
      final opsA1 = docA.localInsert(0, 'hello');
      engineB.mergeRemote('note-1', opsA1);

      // B types " world"
      final docB = engineB.getDocument('note-1');
      final opsB1 = docB.localInsert(5, ' world');
      engineA.mergeRemote('note-1', opsB1);

      expect(docA.text, equals('hello world'));
      expect(docB.text, equals('hello world'));
    });

    test('mergeRemote creates document lazily if it does not exist', () {
      final engine = MergeEngine('site-A');
      final remoteOps = [
        RGANode(
          id: 'site-B:1',
          leftOriginId: '',
          rightOriginId: '',
          siteId: 'site-B',
          clock: 1,
          value: 'x',
        ),
      ];

      expect(engine.hasDocument('new-note'), isFalse);
      final result = engine.mergeRemote('new-note', remoteOps);
      expect(engine.hasDocument('new-note'), isTrue);
      expect(result.hasChanges, isTrue);
    });

    test('mergeRemote handles mixed inserts and deletes', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      final docA = engineA.getDocument('note-1');
      docA.localInsert(0, 'hello');
      docA.localDelete(0, 1); // delete 'h'
      // Text is now "ello"

      final allOps = docA.getOperations();
      final result = engineB.mergeRemote('note-1', allOps);
      expect(result.hasChanges, isTrue);

      final docB = engineB.getDocument('note-1');
      expect(docB.text, equals('ello'));
    });

    test('three-way merge via mergeRemote converges', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');
      final engineC = MergeEngine('site-C');

      // A creates base text
      final docA = engineA.getDocument('note-1');
      docA.localInsert(0, 'base');
      final baseOps = docA.getOperations();

      engineB.mergeRemote('note-1', baseOps);
      engineC.mergeRemote('note-1', baseOps);

      // Concurrent edits
      final docB = engineB.getDocument('note-1');
      final docC = engineC.getDocument('note-1');

      docA.localInsert(4, '-A');
      final opsA = docA.getOperations();
      docB.localInsert(4, '-B');
      final opsB = docB.getOperations();
      docC.localInsert(4, '-C');
      final opsC = docC.getOperations();

      // Star merge
      engineA.mergeRemote('note-1', opsB);
      engineA.mergeRemote('note-1', opsC);
      engineB.mergeRemote('note-1', opsA);
      engineB.mergeRemote('note-1', opsC);
      engineC.mergeRemote('note-1', opsA);
      engineC.mergeRemote('note-1', opsB);

      expect(docA.text, equals(docB.text));
      expect(docB.text, equals(docC.text));
      expect(docA.text, equals('base-A-B-C'));
    });
  });

  // ===========================================================================
  // MergeEngine -- getOpsSince
  // ===========================================================================

  group('MergeEngine getOpsSince', () {
    test('returns all operations when sinceClock is 0', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'abc');

      final ops = engine.getOpsSince('note-1', 0);
      expect(ops.length, equals(3));
    });

    test('returns only newer operations', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'abc'); // clock 1, 2, 3

      final ops = engine.getOpsSince('note-1', 2);
      expect(ops.length, equals(1));
      expect(ops.first.clock, equals(3));
    });

    test('returns empty list when no operations are newer', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'abc');

      final ops = engine.getOpsSince('note-1', 100);
      expect(ops, isEmpty);
    });

    test('creates document lazily if it does not exist', () {
      final engine = MergeEngine('site-A');
      expect(engine.hasDocument('note-x'), isFalse);

      final ops = engine.getOpsSince('note-x', 0);
      expect(ops, isEmpty);
      expect(engine.hasDocument('note-x'), isTrue);
    });

    test('reflects operations from mergeRemote', () {
      final engineA = MergeEngine('site-A');
      final engineB = MergeEngine('site-B');

      final docA = engineA.getDocument('note-1');
      docA.localInsert(0, 'ab');

      engineB.mergeRemote('note-1', docA.getOperations());

      // B adds more
      final docB = engineB.getDocument('note-1');
      docB.localInsert(2, 'XY');

      final opsSince2 = engineB.getOpsSince('note-1', 2);
      expect(opsSince2.length, equals(2));
    });
  });

  // ===========================================================================
  // MergeEngine -- serialization
  // ===========================================================================

  group('MergeEngine serialization', () {
    test('toJson/fromJson round-trip preserves siteId', () {
      final engine = MergeEngine('site-A');
      final json = engine.toJson();
      final restored = MergeEngine.fromJson(json);

      expect(restored.siteId, equals('site-A'));
    });

    test('toJson/fromJson round-trip preserves empty engine', () {
      final engine = MergeEngine('site-A');
      final json = engine.toJson();
      final restored = MergeEngine.fromJson(json);

      expect(restored.hasDocument('note-1'), isFalse);
    });

    test('toJson/fromJson round-trip preserves single document', () {
      final engine = MergeEngine('site-A');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'hello');

      final json = engine.toJson();
      final restored = MergeEngine.fromJson(json);

      expect(restored.hasDocument('note-1'), isTrue);
      final restoredDoc = restored.getDocument('note-1');
      expect(restoredDoc.text, equals('hello'));
    });

    test('toJson/fromJson round-trip preserves multiple documents', () {
      final engine = MergeEngine('site-A');

      final doc1 = engine.getDocument('note-1');
      doc1.localInsert(0, 'first');

      final doc2 = engine.getDocument('note-2');
      doc2.localInsert(0, 'second');

      final json = engine.toJson();
      final restored = MergeEngine.fromJson(json);

      expect(restored.hasDocument('note-1'), isTrue);
      expect(restored.hasDocument('note-2'), isTrue);
      expect(restored.getDocument('note-1').text, equals('first'));
      expect(restored.getDocument('note-2').text, equals('second'));
    });

    test('fromJson handles missing documents key gracefully', () {
      final json = {'site_id': 'site-A'};
      final restored = MergeEngine.fromJson(json);
      expect(restored.siteId, equals('site-A'));
      expect(restored.hasDocument('note-1'), isFalse);
    });

    test('fromJson handles null documents key gracefully', () {
      final json = {'site_id': 'site-A', 'documents': null};
      final restored = MergeEngine.fromJson(json);
      expect(restored.siteId, equals('site-A'));
      expect(restored.hasDocument('note-1'), isFalse);
    });
  });

  // ===========================================================================
  // MergeEngine -- multi-document isolation
  // ===========================================================================

  group('MergeEngine multi-document isolation', () {
    test('operations in one document do not affect another', () {
      final engine = MergeEngine('site-A');

      final doc1 = engine.getDocument('note-1');
      final doc2 = engine.getDocument('note-2');

      doc1.localInsert(0, 'alpha');
      doc2.localInsert(0, 'beta');

      expect(doc1.text, equals('alpha'));
      expect(doc2.text, equals('beta'));
    });

    test('mergeRemote targets only the specified document', () {
      final engine = MergeEngine('site-A');
      final otherEngine = MergeEngine('site-B');

      engine.getDocument('note-1').localInsert(0, 'existing');
      engine.getDocument('note-2').localInsert(0, 'other');

      final remoteDoc = otherEngine.getDocument('note-1');
      remoteDoc.localInsert(0, 'remote');

      final result = engine.mergeRemote('note-1', remoteDoc.getOperations());

      expect(result.hasChanges, isTrue);
      // note-2 should be untouched
      expect(engine.getDocument('note-2').text, equals('other'));
    });

    test('removeDocument does not affect other documents', () {
      final engine = MergeEngine('site-A');

      final doc1 = engine.getDocument('note-1');
      doc1.localInsert(0, 'keep');

      final doc2 = engine.getDocument('note-2');
      doc2.localInsert(0, 'also keep');

      engine.removeDocument('note-1');
      expect(engine.hasDocument('note-1'), isFalse);
      expect(engine.getDocument('note-2').text, equals('also keep'));
    });
  });

  // ===========================================================================
  // MergeEngine -- MergeResult
  // ===========================================================================

  group('MergeResult', () {
    test('toString contains appliedCount, hasChanges, and newOperations length',
        () {
      final result = MergeResult(
        appliedCount: 3,
        hasChanges: true,
        newOperations: [
          RGANode(
            id: 's:1',
            leftOriginId: '',
            rightOriginId: '',
            siteId: 's',
            clock: 1,
            value: 'a',
          ),
        ],
      );
      final str = result.toString();
      expect(str, contains('3'));
      expect(str, contains('true'));
      expect(str, contains('1'));
    });
  });
}
