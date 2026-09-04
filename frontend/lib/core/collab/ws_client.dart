import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../main.dart';

/// WS message types matching the backend handler.
enum WSMessageType { join, leave, presence, typing, comment, edit, cursor, ping, pong }

/// A typed WebSocket message with a [type] and arbitrary [data] payload.
class WSMessage {
  final WSMessageType type;
  final Map<String, dynamic> data;

  WSMessage(this.type, this.data);

  /// Serialize to a JSON string for sending over the wire.
  String encode() => jsonEncode({'type': type.name, ...data});

  /// Deserialize a raw JSON string into a [WSMessage].
  factory WSMessage.decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final typeStr = map.remove('type') as String;
    return WSMessage(
      WSMessageType.values.firstWhere((t) => t.name == typeStr),
      Map<String, dynamic>.from(map),
    );
  }

  @override
  String toString() => 'WSMessage(${type.name}, $data)';
}

/// Connection state exposed to the UI layer.
enum WSConnectionState { disconnected, connecting, connected, error }

/// Low-level WebSocket client that manages a single persistent connection
/// to the backend collaboration endpoint.
///
/// Responsibilities:
/// - Connect / reconnect with automatic ping keep-alive.
/// - Serialize / deserialize [WSMessage] objects.
/// - Expose incoming messages and connection state as broadcast streams.
/// - Room join / leave on top of the raw connection.
class WSClient {
  final String baseUrl;
  final String token;

  /// Optional resolver invoked before each (re)connect to obtain the
  /// CURRENT access token. Without it the client replays the token it was
  /// constructed with forever — after the JWT expires the server rejects
  /// every reconnect with 401 "token is expired".
  final Future<String?> Function()? tokenResolver;

  /// Token resolved via [tokenResolver], preferred over [token] when set.
  String? _resolvedToken;

  WebSocketChannel? _channel;
  final _messageController = StreamController<WSMessage>.broadcast();
  final _stateController = StreamController<WSConnectionState>.broadcast();

  WSConnectionState _state = WSConnectionState.disconnected;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _currentRoom;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);
  static const int _maxQueueSize = 100;

  /// Buffer of encoded messages to send once the connection is re-established.
  final List<String> _sendQueue = [];

  /// Random number generator for jitter in reconnection backoff.
  final Random _rng = Random();

  WSClient({required this.baseUrl, required this.token, this.tokenResolver});

  Stream<WSMessage> get messages => _messageController.stream;
  Stream<WSConnectionState> get connectionState => _stateController.stream;
  WSConnectionState get state => _state;

  /// Open the WebSocket connection. If already connected this is a no-op.
  Future<void> connect() async {
    if (_state == WSConnectionState.connected) return;
    _setState(WSConnectionState.connecting);

    // After a couple of failed attempts, re-resolve the access token —
    // the captured one has likely expired (JWT TTL is finite), and
    // replaying it makes the server reject every reconnect with 401.
    if (_reconnectAttempts >= 2 && tokenResolver != null) {
      try {
        final fresh = await tokenResolver!();
        if (fresh != null && fresh.isNotEmpty) _resolvedToken = fresh;
      } catch (_) {
        // Resolution failed (e.g. offline) — retry with whatever we have.
      }
    }
    final effectiveToken =
        (_resolvedToken != null && _resolvedToken!.isNotEmpty)
            ? _resolvedToken!
            : token;

    try {
      final uri = Uri.parse('$baseUrl?token=$effectiveToken');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setState(WSConnectionState.connected);
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            _messageController.add(WSMessage.decode(data));
          }
        },
        onDone: () => _handleDisconnect(),
        onError: (_) => _handleDisconnect(),
      );

      // Start periodic ping to keep the connection alive.
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        send(WSMessage(WSMessageType.ping, {}));
      });

      // Re-join the room if we are reconnecting.
      if (_currentRoom != null) {
        joinRoom(_currentRoom!);
      }

      // Flush any messages that were buffered while disconnected.
      _flushQueue();
    } catch (e) {
      _setState(WSConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// Send a join message for the given note room.
  void joinRoom(String noteId) {
    _currentRoom = noteId;
    send(WSMessage(WSMessageType.join, {'room': noteId}));
  }

  /// Send a leave message for the given note room.
  void leaveRoom(String noteId) {
    _currentRoom = null;
    send(WSMessage(WSMessageType.leave, {'room': noteId}));
  }

  /// Broadcast a typing indicator for the given note room.
  void sendTyping(String noteId) {
    send(WSMessage(WSMessageType.typing, {'room': noteId}));
  }

  /// Send a CRDT edit operation to the room.
  void sendEdit(String noteId, Map<String, dynamic> editPayload) {
    send(WSMessage(WSMessageType.edit, {'room': noteId, ...editPayload}));
  }

  /// Send a cursor position update to the room.
  void sendCursor(String noteId, int position) {
    send(WSMessage(WSMessageType.cursor, {
      'room': noteId,
      'position': position,
    }),);
  }

  /// Send a typed message over the WebSocket.
  ///
  /// If the connection is not currently in a connected state, the encoded
  /// message is buffered in a queue (up to [_maxQueueSize] entries) and
  /// will be flushed automatically when the connection is re-established.
  void send(WSMessage message) {
    final encoded = message.encode();
    if (_state == WSConnectionState.connected) {
      try {
        _channel?.sink.add(encoded);
      } catch (_) {
        // Swallow write errors; the onDone / onError callbacks will
        // handle reconnection. Queue the message so it is not lost.
        _enqueue(encoded);
      }
    } else {
      _enqueue(encoded);
    }
  }

  /// Add an encoded message to the send queue, respecting the size limit.
  void _enqueue(String encoded) {
    if (_sendQueue.length >= _maxQueueSize) {
      _sendQueue.removeAt(0);
    }
    _sendQueue.add(encoded);
  }

  /// Flush all queued messages over the active connection.
  void _flushQueue() {
    while (_sendQueue.isNotEmpty) {
      try {
        _channel?.sink.add(_sendQueue.removeAt(0));
      } catch (_) {
        // Write failed; stop flushing. The remaining messages stay queued
        // and will be retried on the next reconnect.
        break;
      }
    }
  }

  /// Clean up all resources (timers, streams, socket).
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _sendQueue.clear();
    _messageController.close();
    _stateController.close();
  }

  // ── Internal helpers ─────────────────────────────────

  void _handleDisconnect() {
    _pingTimer?.cancel();
    if (_state != WSConnectionState.disconnected) {
      _setState(WSConnectionState.disconnected);
    }
    _scheduleReconnect();
  }

  /// Schedule a reconnect attempt with exponential backoff and jitter.
  ///
  /// Base delay follows: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
  /// A random jitter of 0-500 ms is added to avoid thundering-herd effects.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final exponentialSeconds = (1 << (_reconnectAttempts - 1))
        .clamp(1, _maxReconnectDelay.inSeconds);
    final jitterMs = _rng.nextInt(500);
    final delay = Duration(seconds: exponentialSeconds, milliseconds: jitterMs);
    _reconnectTimer = Timer(delay, connect);
  }

  void _setState(WSConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }
}

// ── Riverpod providers ────────────────────────────────────

/// Constructs the WebSocket base URL from the same base URL used by the
/// HTTP API client (http -> ws, https -> wss).
String _wsBaseUrlFromHttp(String httpBaseUrl) {
  final scheme = httpBaseUrl.startsWith('https') ? 'wss' : 'ws';
  final rest = httpBaseUrl.replaceFirst(RegExp(r'^https?'), '');
  return '$scheme$rest/api/v1/ws';
}

/// Provides the current [WSConnectionState] and exposes the [WSClient]
/// for feature-level providers to use.
final wsClientProvider =
    StateNotifierProvider<WSClientNotifier, WSConnectionState>((ref) {
  return WSClientNotifier(ref);
});

/// Notifier that owns a single [WSClient] instance scoped to the
/// authenticated session.
class WSClientNotifier extends StateNotifier<WSConnectionState> {
  final Ref _ref;
  WSClient? _client;

  WSClientNotifier(this._ref) : super(WSConnectionState.disconnected);

  /// Resolves the current access token for WS reconnects: prefers a fresh
  /// silent refresh, falling back to the in-memory token (which may still be
  /// valid if the refresh failed for transient reasons).
  Future<String?> _resolveFreshToken() async {
    final api = _ref.read(apiClientProvider);
    final refreshed = await api.tryRefreshToken();
    return refreshed ?? api.accessToken;
  }

  /// The active [WSClient]. Lazily created on first access.
  ///
  /// If the client has not been explicitly connected via [connect], this
  /// creates a placeholder that will be replaced on the first [connect] call.
  WSClient get client {
    _client ??= WSClient(
      baseUrl: _wsBaseUrlFromHttp(
        _ref.read(apiClientProvider).baseUrl,
      ),
      token: _ref.read(apiClientProvider).accessToken ?? '',
      tokenResolver: _resolveFreshToken,
    );
    return _client!;
  }

  /// Connect using the given JWT [token]. Disposes any previous client first.
  Future<void> connect(String token) async {
    _client?.dispose();
    _client = WSClient(
      baseUrl: _wsBaseUrlFromHttp(
        _ref.read(apiClientProvider).baseUrl,
      ),
      token: token,
      tokenResolver: _resolveFreshToken,
    );
    _client!.connectionState.listen((s) {
      if (mounted) state = s;
    });
    await _client!.connect();
  }

  /// Disconnect and clean up the client.
  void disconnect() {
    _client?.dispose();
    _client = null;
    if (mounted) state = WSConnectionState.disconnected;
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
