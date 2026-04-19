import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../main.dart';

/// WS message types matching the backend handler.
enum WSMessageType { join, leave, presence, typing, comment, ping, pong }

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

  WebSocketChannel? _channel;
  final _messageController = StreamController<WSMessage>.broadcast();
  final _stateController = StreamController<WSConnectionState>.broadcast();

  WSConnectionState _state = WSConnectionState.disconnected;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _currentRoom;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);

  WSClient({required this.baseUrl, required this.token});

  Stream<WSMessage> get messages => _messageController.stream;
  Stream<WSConnectionState> get connectionState => _stateController.stream;
  WSConnectionState get state => _state;

  /// Open the WebSocket connection. If already connected this is a no-op.
  Future<void> connect() async {
    if (_state == WSConnectionState.connected) return;
    _setState(WSConnectionState.connecting);

    try {
      final uri = Uri.parse('$baseUrl?token=$token');
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

  /// Send a typed message over the WebSocket. Silently drops the message
  /// if the connection is not currently in a connected state.
  void send(WSMessage message) {
    if (_state != WSConnectionState.connected) return;
    try {
      _channel?.sink.add(message.encode());
    } catch (_) {
      // Swallow write errors; the onDone / onError callbacks will
      // handle reconnection.
    }
  }

  /// Clean up all resources (timers, streams, socket).
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
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

  /// Schedule a reconnect attempt with exponential backoff, capped at
  /// [_maxReconnectDelay].
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = Duration(
      seconds: (3 * _reconnectAttempts).clamp(3, _maxReconnectDelay.inSeconds),
    );
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

  /// The active [WSClient]. Lazily created on first access.
  WSClient get client {
    _client ??= WSClient(
      baseUrl: _wsBaseUrlFromHttp(
        _ref.read(apiClientProvider).baseUrl,
      ),
      token: '',
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
