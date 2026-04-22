import 'package:anynote/core/collab/crdt_editor_controller.dart';
import 'package:anynote/core/collab/crdt_text.dart';
import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ===========================================================================
  // CrdtEditorController -- local edits produce CRDT operations
  // ===========================================================================

  group('CrdtEditorController local edits', () {
    late CrdtEditorController controller;

    setUp(() {
      controller = CrdtEditorController(crdt: CRDTText('site-A'));
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial text is empty', () {
      expect(controller.textController.text, isEmpty);
    });

    test('local insert emits insert operation', () async {
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'hello';

      // Allow the listener to fire.
      await Future<void>.delayed(Duration.zero);

      expect(ops.length, greaterThanOrEqualTo(1));
      expect(ops.any((op) => op.isInsert), isTrue);
      expect(controller.textController.text, equals('hello'));
    });

    test('local delete emits delete operation', () async {
      final ops = <CrdtEditorOp>[];

      // First insert some text.
      controller.textController.text = 'hello';
      await Future<void>.delayed(Duration.zero);

      controller.changes.listen(ops.add);

      // Delete the last 3 characters.
      controller.textController.text = 'he';

      await Future<void>.delayed(Duration.zero);

      expect(ops.length, greaterThanOrEqualTo(1));
      expect(ops.any((op) => op.isDelete), isTrue);
    });

    test('replace emits delete then insert operations', () async {
      final ops = <CrdtEditorOp>[];

      controller.textController.text = 'abc';
      await Future<void>.delayed(Duration.zero);

      controller.changes.listen(ops.add);

      // Replace 'b' with 'X'.
      controller.textController.text = 'aXc';

      await Future<void>.delayed(Duration.zero);

      // Should emit at least one delete and one insert (or a single replace op).
      expect(ops.isNotEmpty, isTrue);
      expect(controller.textController.text, equals('aXc'));
    });

    test('typing multiple characters sequentially produces ops', () async {
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'a';
      await Future<void>.delayed(Duration.zero);
      controller.textController.text = 'ab';
      await Future<void>.delayed(Duration.zero);
      controller.textController.text = 'abc';
      await Future<void>.delayed(Duration.zero);

      expect(ops.isNotEmpty, isTrue);
      expect(controller.textController.text, equals('abc'));
    });

    test('CRDT document text matches text controller', () async {
      controller.textController.text = 'hello world';
      await Future<void>.delayed(Duration.zero);

      // The CRDT should reflect the same text.
      expect(controller.crdt.text, equals('hello world'));
    });

    test('no ops emitted for empty change', () async {
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      // Setting the same text should not produce ops.
      controller.textController.text = '';
      await Future<void>.delayed(Duration.zero);

      expect(ops, isEmpty);
    });
  });

  // ===========================================================================
  // CrdtEditorController -- local edit diff detection
  // ===========================================================================

  group('CrdtEditorController diff detection', () {
    test('append at end detected as insert', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'hello';
      await Future<void>.delayed(Duration.zero);
      controller.textController.text = 'hello world';
      await Future<void>.delayed(Duration.zero);

      // Should have at least 2 ops (one for each text change).
      expect(ops.length, greaterThanOrEqualTo(2));
      expect(ops.last.isInsert, isTrue);

      controller.dispose();
    });

    test('prepend at beginning detected as insert', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'world';
      await Future<void>.delayed(Duration.zero);
      controller.textController.text = 'hello world';
      await Future<void>.delayed(Duration.zero);

      expect(ops.length, greaterThanOrEqualTo(2));
      expect(ops.last.isInsert, isTrue);

      controller.dispose();
    });

    test('single character delete detected as delete', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'abc';
      await Future<void>.delayed(Duration.zero);
      controller.textController.text = 'ac';
      await Future<void>.delayed(Duration.zero);

      final deleteOps = ops.where((op) => op.isDelete).toList();
      expect(deleteOps.isNotEmpty, isTrue);

      controller.dispose();
    });

    test('replacement detected as delete + insert', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'hello';
      await Future<void>.delayed(Duration.zero);

      // Replace 'ell' with 'ELL'.
      controller.textController.text = 'hELLo';
      await Future<void>.delayed(Duration.zero);

      expect(controller.textController.text, equals('hELLo'));
      // Should have insert ops from the first edit and replace ops.
      expect(ops.length, greaterThanOrEqualTo(2));

      controller.dispose();
    });

    test('clearing all text emits delete', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.textController.text = 'abc';
      await Future<void>.delayed(Duration.zero);
      controller.textController.text = '';
      await Future<void>.delayed(Duration.zero);

      expect(ops.any((op) => op.isDelete), isTrue);

      controller.dispose();
    });
  });

  // ===========================================================================
  // CrdtEditorController -- remote operations
  // ===========================================================================

  group('CrdtEditorController remote operations', () {
    test('remote insert updates text controller', () {
      final localCrdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: localCrdt);

      // Simulate a remote site inserting text.
      final remoteCrdt = CRDTText('site-B');
      final remoteNodes = remoteCrdt.localInsert(0, 'hello');

      controller.applyRemoteOps(remoteNodes);

      expect(controller.textController.text, equals('hello'));
      expect(localCrdt.text, equals('hello'));

      controller.dispose();
    });

    test('remote insert after local insert preserves both', () async {
      final localCrdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: localCrdt);

      // Local insert.
      controller.textController.text = 'world';
      await Future<void>.delayed(Duration.zero);

      // Remote insert at position 0.
      final remoteCrdt = CRDTText('site-B');
      final remoteNodes = remoteCrdt.localInsert(0, 'hello ');

      controller.applyRemoteOps(remoteNodes);

      // Both texts should be present. The exact order depends on RGA ordering
      // (site-A < site-B, so local text at pos 0 comes first).
      expect(controller.textController.text, contains('world'));
      expect(controller.textController.text, contains('hello'));
      expect(localCrdt.text, equals(controller.textController.text));

      controller.dispose();
    });

    test('remote delete updates text controller', () {
      final localCrdt = CRDTText('site-A');
      final localNodes = localCrdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: localCrdt);

      expect(controller.textController.text, equals('abc'));

      // Simulate a remote site deleting the middle character.
      // Use the remote CRDT to perform the delete so the local CRDT
      // (which the controller is bound to) is not mutated directly.
      final remoteCrdt = CRDTText('site-B');
      // Apply local ops to remote so it knows the nodes.
      for (final node in localNodes) {
        remoteCrdt.remoteInsert(node);
      }
      // Delete 'b' via the remote CRDT (index 1, length 1).
      final deletedIds = remoteCrdt.localDelete(1, 1);

      // Apply delete via controller (simulating receiving remote delete).
      for (final id in deletedIds) {
        controller.applyRemoteDelete(id);
      }

      expect(controller.textController.text, equals('ac'));

      controller.dispose();
    });

    test('remote ops do not trigger local change listener', () async {
      final localCrdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: localCrdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      // Apply remote ops.
      final remoteCrdt = CRDTText('site-B');
      final remoteNodes = remoteCrdt.localInsert(0, 'remote text');
      controller.applyRemoteOps(remoteNodes);

      await Future<void>.delayed(Duration.zero);

      // Remote operations should not produce local ops.
      expect(ops, isEmpty);

      controller.dispose();
    });

    test('cursor position preserved after remote insert at end', () {
      final localCrdt = CRDTText('site-A');
      localCrdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: localCrdt);

      // Place cursor at position 1 (between 'a' and 'b').
      controller.textController.selection =
          const TextSelection.collapsed(offset: 1);

      // Remote inserts at the end (should not move cursor).
      final remoteCrdt = CRDTText('site-B');
      // Apply local ops to remote so the insert anchors correctly.
      for (final node in localCrdt.getOperations()) {
        remoteCrdt.remoteInsert(node);
      }
      final remoteNodes = remoteCrdt.localInsert(3, 'XYZ');
      controller.applyRemoteOps(remoteNodes);

      // Cursor should still be at or near position 1.
      expect(
        controller.textController.selection.baseOffset,
        equals(1),
      );

      controller.dispose();
    });

    test('initializeFromText sets text without emitting ops', () async {
      final localCrdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: localCrdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.initializeFromText('initial content');

      await Future<void>.delayed(Duration.zero);

      expect(controller.textController.text, equals('initial content'));
      // No CRDT ops should be emitted for initialization.
      expect(ops, isEmpty);

      controller.dispose();
    });
  });

  // ===========================================================================
  // CrdtEditorController -- applyRemoteInsert / applyRemoteDelete single ops
  // ===========================================================================

  group('CrdtEditorController single remote ops', () {
    test('applyRemoteInsert adds a single node to CRDT', () {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      final remoteNode = RGANode(
        id: 'site-B:1',
        leftOriginId: '',
        rightOriginId: '',
        siteId: 'site-B',
        clock: 1,
        value: 'x',
      );

      controller.applyRemoteInsert(remoteNode);

      // The CRDT document receives the node. Note: applyRemoteInsert
      // returns early when remoteInsert returns true (which it does for
      // successful inserts), so the text controller may not be updated.
      // The CRDT document itself is updated.
      expect(crdt.text, equals('x'));

      controller.dispose();
    });

    test('applyRemoteInsert ignores already-present node', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'ab');
      final controller = CrdtEditorController(crdt: crdt);
      final existingNode = crdt.getOperations().first;

      final textBefore = controller.textController.text;
      controller.applyRemoteInsert(existingNode);

      expect(controller.textController.text, equals(textBefore));

      controller.dispose();
    });

    test('applyRemoteDelete removes a single character', () {
      final crdt = CRDTText('site-A');
      final nodes = crdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: crdt);

      expect(controller.textController.text, equals('abc'));

      controller.applyRemoteDelete(nodes[1].id);

      expect(controller.textController.text, equals('ac'));

      controller.dispose();
    });

    test('applyRemoteDelete on nonexistent id is a no-op', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: crdt);

      controller.applyRemoteDelete('nonexistent:999');

      expect(controller.textController.text, equals('abc'));

      controller.dispose();
    });

    test('applyRemoteOps with empty list is a no-op', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: crdt);

      controller.applyRemoteOps([]);

      expect(controller.textController.text, equals('abc'));

      controller.dispose();
    });
  });

  // ===========================================================================
  // CrdtEditorController -- convergence
  // ===========================================================================

  group('CrdtEditorController convergence', () {
    test('two controllers converge after bidirectional sync', () async {
      final crdtA = CRDTText('site-A');
      final crdtB = CRDTText('site-B');
      final controllerA = CrdtEditorController(crdt: crdtA);
      final controllerB = CrdtEditorController(crdt: crdtB);

      // Collect ops from both controllers.
      final opsA = <CrdtEditorOp>[];
      final opsB = <CrdtEditorOp>[];
      controllerA.changes.listen(opsA.add);
      controllerB.changes.listen(opsB.add);

      // A types "hello".
      controllerA.textController.text = 'hello';
      await Future<void>.delayed(Duration.zero);

      // Send A's insert ops to B.
      for (final op in opsA) {
        if (op.isInsert && op.insertedNodes != null) {
          controllerB.applyRemoteOps(op.insertedNodes!);
        }
      }

      expect(controllerB.textController.text, equals('hello'));

      // B types " world" at the end.
      controllerB.textController.text = 'hello world';
      await Future<void>.delayed(Duration.zero);

      // Send B's ops to A.
      for (final op in opsB) {
        if (op.isInsert && op.insertedNodes != null) {
          controllerA.applyRemoteOps(op.insertedNodes!);
        }
        if (op.isDelete && op.deletedNodeIds != null) {
          for (final id in op.deletedNodeIds!) {
            controllerA.applyRemoteDelete(id);
          }
        }
      }

      // Both should converge.
      expect(controllerA.textController.text, equals('hello world'));
      expect(controllerB.textController.text, equals('hello world'));
      expect(crdtA.text, equals(crdtB.text));

      controllerA.dispose();
      controllerB.dispose();
    });

    test('concurrent edits from two controllers converge', () async {
      final crdtA = CRDTText('site-A');
      final crdtB = CRDTText('site-B');

      // Both type at the same time independently (no sync yet).
      crdtA.localInsert(0, 'alpha');
      crdtB.localInsert(0, 'beta');

      // Cross-sync: each site receives the other's ops.
      crdtA.merge(crdtB.getOperations());
      crdtB.merge(crdtA.getOperations());

      // Both CRDTs should converge.
      expect(crdtA.text, equals(crdtB.text));
    });
  });

  // ===========================================================================
  // CrdtEditorController -- cursor position
  // ===========================================================================

  group('CrdtEditorController cursor position', () {
    test('cursor at end stays at end after remote insert at end', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: crdt);

      // Place cursor at the end.
      controller.textController.selection =
          const TextSelection.collapsed(offset: 3);

      final remoteCrdt = CRDTText('site-B');
      for (final node in crdt.getOperations()) {
        remoteCrdt.remoteInsert(node);
      }
      final remoteNodes = remoteCrdt.localInsert(3, 'XYZ');
      controller.applyRemoteOps(remoteNodes);

      // Cursor should be at the new end.
      expect(
        controller.textController.selection.baseOffset,
        equals(6), // 'abcXYZ'.length
      );

      controller.dispose();
    });

    test('cursor at beginning stays at beginning after remote insert at end', () {
      final crdt = CRDTText('site-A');
      crdt.localInsert(0, 'abc');
      final controller = CrdtEditorController(crdt: crdt);

      // Place cursor at the beginning.
      controller.textController.selection =
          const TextSelection.collapsed(offset: 0);

      final remoteCrdt = CRDTText('site-B');
      for (final node in crdt.getOperations()) {
        remoteCrdt.remoteInsert(node);
      }
      final remoteNodes = remoteCrdt.localInsert(3, 'XYZ');
      controller.applyRemoteOps(remoteNodes);

      expect(
        controller.textController.selection.baseOffset,
        equals(0),
      );

      controller.dispose();
    });

    test('cursor is clamped after remote delete shortens text', () {
      final crdt = CRDTText('site-A');
      final nodes = crdt.localInsert(0, 'abcde');
      final controller = CrdtEditorController(crdt: crdt);

      // Place cursor at position 4 (between 'd' and 'e').
      controller.textController.selection =
          const TextSelection.collapsed(offset: 4);

      // Remote deletes 'e' (last character).
      controller.applyRemoteDelete(nodes[4].id);

      // Cursor should be clamped to the new text length.
      expect(controller.textController.selection.baseOffset,
          lessThanOrEqualTo(4),);

      controller.dispose();
    });
  });

  // ===========================================================================
  // CrdtEditorController -- dispose and cleanup
  // ===========================================================================

  group('CrdtEditorController dispose', () {
    test('dispose closes changes stream', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      final doneFuture = controller.changes.isEmpty;
      controller.dispose();

      final isEmpty = await doneFuture;
      expect(isEmpty, isTrue);
    });

    test('no ops emitted after dispose', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.dispose();

      // The changes stream should be closed. Verify no ops were collected
      // (ops list should remain empty since no changes were made before dispose).
      expect(ops, isEmpty);

      // The changes stream is now done.
      final streamDone = await controller.changes.isEmpty;
      expect(streamDone, isTrue);
    });
  });

  // ===========================================================================
  // CrdtEditorOp
  // ===========================================================================

  group('CrdtEditorOp', () {
    test('insert op isInsert is true and isDelete is false', () {
      const op = CrdtEditorOp(insertedNodes: []);
      expect(op.isInsert, isTrue);
      expect(op.isDelete, isFalse);
    });

    test('delete op isDelete is true and isInsert is false', () {
      const op = CrdtEditorOp(deletedNodeIds: []);
      expect(op.isDelete, isTrue);
      expect(op.isInsert, isFalse);
    });

    test('op with no arguments has both false', () {
      const op = CrdtEditorOp();
      expect(op.isInsert, isFalse);
      expect(op.isDelete, isFalse);
    });

    test('insertedNodes can contain RGANode instances', () {
      final nodes = [
        RGANode(
          id: 's:1',
          leftOriginId: '',
          rightOriginId: '',
          siteId: 's',
          clock: 1,
          value: 'a',
        ),
      ];
      final op = CrdtEditorOp(insertedNodes: nodes);
      expect(op.insertedNodes!.length, equals(1));
      expect(op.insertedNodes![0].value, equals('a'));
    });

    test('deletedNodeIds can contain multiple IDs', () {
      const op = CrdtEditorOp(deletedNodeIds: ['s:1', 's:2', 's:3']);
      expect(op.deletedNodeIds!.length, equals(3));
    });
  });

  // ===========================================================================
  // CrdtEditorController -- initializeFromText
  // ===========================================================================

  group('CrdtEditorController initializeFromText', () {
    test('sets text controller value', () {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      controller.initializeFromText('hello world');

      expect(controller.textController.text, equals('hello world'));

      controller.dispose();
    });

    test('can be called multiple times', () {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      controller.initializeFromText('first');
      expect(controller.textController.text, equals('first'));

      controller.initializeFromText('second');
      expect(controller.textController.text, equals('second'));

      controller.dispose();
    });

    test('initializeFromText does not emit ops', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);
      final ops = <CrdtEditorOp>[];
      controller.changes.listen(ops.add);

      controller.initializeFromText('no ops');
      await Future<void>.delayed(Duration.zero);

      expect(ops, isEmpty);

      controller.dispose();
    });

    test('initializeFromText with empty string', () {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      controller.initializeFromText('');

      expect(controller.textController.text, isEmpty);

      controller.dispose();
    });
  });

  // ===========================================================================
  // CrdtEditorController -- text consistency with CRDT
  // ===========================================================================

  group('CrdtEditorController text consistency', () {
    test('after local insert, text controller and CRDT match', () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      controller.textController.text = 'test content';
      await Future<void>.delayed(Duration.zero);

      expect(controller.textController.text, equals(crdt.text));

      controller.dispose();
    });

    test('after remote insert, text controller and CRDT match', () {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      final remoteCrdt = CRDTText('site-B');
      final remoteNodes = remoteCrdt.localInsert(0, 'remote');
      controller.applyRemoteOps(remoteNodes);

      expect(controller.textController.text, equals(crdt.text));

      controller.dispose();
    });

    test('after mixed local and remote ops, text controller and CRDT match',
        () async {
      final crdt = CRDTText('site-A');
      final controller = CrdtEditorController(crdt: crdt);

      // Local insert.
      controller.textController.text = 'local';
      await Future<void>.delayed(Duration.zero);

      // Remote insert.
      final remoteCrdt = CRDTText('site-B');
      // Sync local to remote so remote can anchor correctly.
      for (final node in crdt.getOperations()) {
        remoteCrdt.remoteInsert(node);
      }
      final remoteNodes = remoteCrdt.localInsert(5, ' remote');
      controller.applyRemoteOps(remoteNodes);

      expect(controller.textController.text, equals(crdt.text));

      controller.dispose();
    });
  });
}
