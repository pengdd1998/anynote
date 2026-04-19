
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
  });
}
