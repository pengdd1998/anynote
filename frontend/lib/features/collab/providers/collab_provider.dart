import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/collab/crdt_editor_controller.dart';
import '../../../core/collab/crdt_text.dart';
import '../../../core/collab/merge_engine.dart';
import '../../../core/collab/ws_client.dart';
import '../../../main.dart' show databaseProvider;

/// Shared preferences key for the persistent CRDT site ID.
const _kSiteIdKey = 'crdt_site_id';

/// State held by the [CollabNotifier] for a single active collaboration
/// session.
class CollabSessionState {
  /// The note ID of the currently active collab room (null if not in a room).
  final String? noteId;

  /// Whether the WebSocket is connected and the room is joined.
  final bool isConnected;

  /// The editor controller that bridges the text field with the CRDT.
  final CrdtEditorController? editorController;

  const CollabSessionState({
    this.noteId,
    this.isConnected = false,
    this.editorController,
  });

  CollabSessionState copyWith({
    String? noteId,
    bool? isConnected,
    CrdtEditorController? editorController,
  }) {
    return CollabSessionState(
      noteId: noteId ?? this.noteId,
      isConnected: isConnected ?? this.isConnected,
      editorController: editorController ?? this.editorController,
    );
  }
}

/// Manages a single real-time collaboration session: room lifecycle,
/// outgoing CRDT operation batching, and incoming operation routing.
///
/// There is at most one active collab session at a time (one note being
/// edited collaboratively). When [joinRoom] is called, any previous
/// session is torn down first.
class CollabNotifier extends StateNotifier<CollabSessionState> {
  final Ref _ref;

  StreamSubscription<WSMessage>? _messageSub;
  StreamSubscription<CrdtEditorOp>? _editorOpSub;
  StreamSubscription<WSConnectionState>? _connectionSub;
  Timer? _batchTimer;
  Timer? _persistTimer;

  /// Buffer of outgoing CRDT operations, flushed every 50ms.
  final List<Map<String, dynamic>> _outgoingBuffer = [];

  /// Maximum interval between batched sends.
  static const _batchInterval = Duration(milliseconds: 50);

  /// How often CRDT state is persisted to the database while in a room.
  static const _persistInterval = Duration(seconds: 5);

  /// The local merge engine for this session.
  MergeEngine? _mergeEngine;

  /// In-memory cache for the siteId so we avoid reading SharedPreferences on
  /// every joinRoom call.
  static String? _siteIdCache;

  CollabNotifier(this._ref) : super(const CollabSessionState());

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Join a collaboration room for [noteId].
  ///
  /// Creates a [CrdtEditorController] backed by a fresh CRDT document,
  /// joins the WebSocket room, and starts routing operations.
  /// If [existingCrdt] is provided, uses it as the starting document state.
  Future<void> joinRoom(String noteId, {CRDTText? existingCrdt}) async {
    // Tear down any previous session.
    _tearDown();

    final siteId = await getOrCreateSiteId();
    _mergeEngine = MergeEngine(siteId);

    final crdt = existingCrdt ?? _mergeEngine!.getDocument(noteId);

    // Load persisted CRDT state for this note if available.
    final db = _ref.read(databaseProvider);
    final savedState = await db.collabDao.loadState(noteId);
    if (savedState != null) {
      try {
        _mergeEngine!.loadState(noteId, savedState.documentState);
      } catch (_) {
        // If the persisted state is corrupt, ignore and start fresh.
        // The CRDT will re-sync from the server.
      }
    }

    final editorController = CrdtEditorController(crdt: crdt);

    // Listen for local CRDT operations and buffer them.
    _editorOpSub = editorController.changes.listen(_onLocalOp);

    // Join the WebSocket room.
    final wsNotifier = _ref.read(wsClientProvider.notifier);
    wsNotifier.client.joinRoom(noteId);

    // Subscribe to incoming messages.
    _messageSub = wsNotifier.client.messages.listen(_onRemoteMessage);

    // Track connection state.
    _connectionSub = wsNotifier.client.connectionState.listen((connState) {
      if (!mounted) return;
      state = state.copyWith(
        isConnected: connState == WSConnectionState.connected,
      );
    });

    // Start periodic CRDT state persistence.
    _persistTimer = Timer.periodic(_persistInterval, (_) => _persistState());

    state = CollabSessionState(
      noteId: noteId,
      isConnected: wsNotifier.client.state == WSConnectionState.connected,
      editorController: editorController,
    );
  }

  /// Leave the current collaboration room and clean up resources.
  void leaveRoom() {
    if (state.noteId != null) {
      final wsNotifier = _ref.read(wsClientProvider.notifier);
      wsNotifier.client.leaveRoom(state.noteId!);
    }
    // Do a final persist before tearing down.
    _persistStateSync();
    _tearDown();
    state = const CollabSessionState();
  }

  /// Send a cursor position update for the current room.
  void sendCursorPosition(int position) {
    if (state.noteId == null) return;
    final wsNotifier = _ref.read(wsClientProvider.notifier);
    wsNotifier.client.sendCursor(state.noteId!, position);
  }

  @override
  void dispose() {
    _persistStateSync();
    _tearDown();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Site ID persistence
  // ---------------------------------------------------------------------------

  /// Get or create a stable site ID for this installation.
  ///
  /// The site ID is a UUID v4 stored in SharedPreferences under
  /// [ _kSiteIdKey]. Once generated, it persists across app restarts.
  static Future<String> getOrCreateSiteId() async {
    if (_siteIdCache != null) return _siteIdCache!;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kSiteIdKey);
    if (existing != null) {
      _siteIdCache = existing;
      return existing;
    }

    final newId = const Uuid().v4();
    await prefs.setString(_kSiteIdKey, newId);
    _siteIdCache = newId;
    return newId;
  }

  /// Clear the in-memory siteId cache. Used in tests to force re-reads
  /// from SharedPreferences or to simulate a fresh installation.
  static void resetSiteIdCache() {
    _siteIdCache = null;
  }

  // ---------------------------------------------------------------------------
  // CRDT state persistence
  // ---------------------------------------------------------------------------

  /// Persist the current CRDT state to the database (async fire-and-forget
  /// for use in timer callbacks and leaveRoom/dispose where we do not want
  /// to await the result).
  void _persistStateSync() {
    if (_mergeEngine == null || state.noteId == null) return;
    final noteId = state.noteId!;
    final engine = _mergeEngine!;
    final stateJson = engine.exportState();
    final clock = engine.clock;

    // Fire and forget -- errors are non-critical (state will be rebuilt from
    // server sync on next join).
    _doPersist(noteId, stateJson, clock);
  }

  Future<void> _doPersist(String noteId, String stateJson, int clock) async {
    try {
      final db = _ref.read(databaseProvider);
      await db.collabDao.saveState(
        noteId: noteId,
        documentState: stateJson,
        lastVersion: clock,
      );
    } catch (_) {
      // Persist failures are non-critical. The CRDT will re-sync from the
      // server on the next joinRoom call.
    }
  }

  /// Persist CRDT state periodically (called by [_persistTimer]).
  Future<void> _persistState() async {
    if (_mergeEngine == null || state.noteId == null) return;
    final noteId = state.noteId!;
    final engine = _mergeEngine!;
    final stateJson = engine.exportState();
    final clock = engine.clock;

    await _doPersist(noteId, stateJson, clock);
  }

  // ---------------------------------------------------------------------------
  // Private: local operation routing
  // ---------------------------------------------------------------------------

  /// Called when the editor controller emits a local CRDT operation.
  /// Buffers the operation for batched sending.
  void _onLocalOp(CrdtEditorOp op) {
    final payload = <String, dynamic>{};

    if (op.isInsert && op.insertedNodes != null) {
      payload['inserts'] = op.insertedNodes!.map((n) => n.toJson()).toList();
    }
    if (op.isDelete && op.deletedNodeIds != null) {
      payload['deletes'] = op.deletedNodeIds!;
    }

    _outgoingBuffer.add(payload);

    // Start batch timer if not already running.
    _batchTimer ??= Timer(_batchInterval, _flushOutgoing);
  }

  /// Flush all buffered outgoing operations in a single WebSocket message.
  void _flushOutgoing() {
    _batchTimer = null;
    if (_outgoingBuffer.isEmpty) return;
    if (state.noteId == null) return;

    final wsNotifier = _ref.read(wsClientProvider.notifier);
    wsNotifier.client.sendEdit(state.noteId!, {
      'ops': List<Map<String, dynamic>>.from(_outgoingBuffer),
    });

    _outgoingBuffer.clear();
  }

  // ---------------------------------------------------------------------------
  // Private: remote message handling
  // ---------------------------------------------------------------------------

  /// Called for each incoming WebSocket message. Routes edit and cursor
  /// messages to the appropriate handler.
  void _onRemoteMessage(WSMessage msg) {
    switch (msg.type) {
      case WSMessageType.edit:
        _onRemoteEdit(msg.data);
      case WSMessageType.cursor:
        // Cursor messages could update remote cursor markers in the future.
        // For now they are acknowledged but not rendered.
        break;
      default:
        // Other message types (join, leave, presence, typing) are handled
        // by PresenceNotifier.
        break;
    }
  }

  /// Apply a remote edit to the editor controller.
  void _onRemoteEdit(Map<String, dynamic> data) {
    final controller = state.editorController;
    if (controller == null) return;

    final ops = data['ops'] as List<dynamic>?;
    if (ops == null) return;

    for (final op in ops) {
      if (op is! Map<String, dynamic>) continue;

      // Apply insert operations.
      final inserts = op['inserts'] as List<dynamic>?;
      if (inserts != null) {
        final nodes = inserts
            .map((j) => RGANode.fromJson(j as Map<String, dynamic>))
            .toList();
        controller.applyRemoteOps(nodes);
      }

      // Apply delete operations.
      final deletes = op['deletes'] as List<dynamic>?;
      if (deletes != null) {
        for (final id in deletes) {
          if (id is String) {
            controller.applyRemoteDelete(id);
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private: cleanup
  // ---------------------------------------------------------------------------

  void _tearDown() {
    _persistTimer?.cancel();
    _persistTimer = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    _outgoingBuffer.clear();
    _messageSub?.cancel();
    _messageSub = null;
    _editorOpSub?.cancel();
    _editorOpSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    state.editorController?.dispose();
    _mergeEngine = null;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides the current collaboration session state.
final collabProvider =
    StateNotifierProvider<CollabNotifier, CollabSessionState>((ref) {
  return CollabNotifier(ref);
});
