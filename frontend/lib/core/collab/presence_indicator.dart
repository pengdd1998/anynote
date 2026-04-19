import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ws_client.dart';

// ---------------------------------------------------------------------------
// RoomPresence model
// ---------------------------------------------------------------------------

/// Represents a single user's presence in a collaboration room (note).
///
/// Instances are keyed by [userId] in the [PresenceNotifier] state map so
/// that each user appears at most once per room.
class RoomPresence {
  final String userId;
  final String displayName;
  final DateTime joinedAt;
  final bool isTyping;

  const RoomPresence({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
    this.isTyping = false,
  });

  RoomPresence copyWith({
    String? userId,
    String? displayName,
    DateTime? joinedAt,
    bool? isTyping,
  }) {
    return RoomPresence(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

// ---------------------------------------------------------------------------
// PresenceNotifier
// ---------------------------------------------------------------------------

/// Manages the in-room presence map by listening to the [WSClient] message
/// stream and reacting to join / leave / presence / typing events.
///
/// The state is a `Map<String, RoomPresence>` keyed by user ID. Only one
/// room is active at a time (determined by the last call to [joinRoom]).
class PresenceNotifier extends StateNotifier<Map<String, RoomPresence>> {
  final Ref _ref;
  StreamSubscription<WSMessage>? _subscription;

  /// Timers used to auto-clear the `isTyping` flag per user after 3 seconds.
  final Map<String, Timer> _typingTimers = {};

  /// The note ID of the currently joined room, or null if not in a room.
  String? _currentRoomId;

  PresenceNotifier(this._ref) : super(const {});

  // ── Public API ────────────────────────────────────

  /// Join a collaboration room for the given [noteId].
  ///
  /// Sends a join message over the WebSocket and clears any stale presence
  /// state from a previous room.
  void joinRoom(String noteId) {
    _currentRoomId = noteId;

    // Clear state from a previous room.
    state = const {};
    _cancelAllTypingTimers();

    // Ensure the WS client is connected.
    final wsNotifier = _ref.read(wsClientProvider.notifier);
    wsNotifier.client.joinRoom(noteId);

    // Subscribe to incoming messages (idempotent -- old subscription is
    // cancelled first).
    _subscription?.cancel();
    _subscription = wsNotifier.client.messages.listen(_handleMessage);
  }

  /// Leave the current room and clear all presence state.
  void leaveRoom() {
    if (_currentRoomId != null) {
      final wsNotifier = _ref.read(wsClientProvider.notifier);
      wsNotifier.client.leaveRoom(_currentRoomId!);
    }
    _currentRoomId = null;
    state = const {};
    _cancelAllTypingTimers();
    _subscription?.cancel();
    _subscription = null;
  }

  /// Broadcast a typing indicator for the current room.
  void sendTyping(String noteId) {
    final wsNotifier = _ref.read(wsClientProvider.notifier);
    wsNotifier.client.sendTyping(noteId);
  }

  // ── Message handling ──────────────────────────────

  void _handleMessage(WSMessage msg) {
    switch (msg.type) {
      case WSMessageType.join:
        _onJoin(msg.data);
      case WSMessageType.leave:
        _onLeave(msg.data);
      case WSMessageType.presence:
        _onPresence(msg.data);
      case WSMessageType.typing:
        _onTyping(msg.data);
      default:
        // Ignore ping / pong / comment messages here.
        break;
    }
  }

  void _onJoin(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    final displayName = data['display_name'] as String? ?? 'Unknown';
    if (userId == null) return;

    state = {
      ...state,
      userId: RoomPresence(
        userId: userId,
        displayName: displayName,
        joinedAt: DateTime.now(),
      ),
    };
  }

  void _onLeave(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId == null) return;

    _typingTimers[userId]?.cancel();
    _typingTimers.remove(userId);

    final updated = Map<String, RoomPresence>.from(state)..remove(userId);
    state = updated;
  }

  void _onPresence(Map<String, dynamic> data) {
    final users = data['users'] as List<dynamic>?;
    if (users == null) return;

    final presenceMap = <String, RoomPresence>{};
    for (final entry in users) {
      if (entry is! Map<String, dynamic>) continue;
      final userId = entry['user_id'] as String?;
      if (userId == null) continue;
      presenceMap[userId] = RoomPresence(
        userId: userId,
        displayName: entry['display_name'] as String? ?? 'Unknown',
        joinedAt: entry['joined_at'] != null
            ? DateTime.tryParse(entry['joined_at'] as String) ??
                DateTime.now()
            : DateTime.now(),
      );
    }
    state = presenceMap;
  }

  void _onTyping(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId == null) return;

    final existing = state[userId];
    if (existing == null) return;

    state = {
      ...state,
      userId: existing.copyWith(isTyping: true),
    };

    // Cancel any existing timer for this user and start a fresh one.
    _typingTimers[userId]?.cancel();
    _typingTimers[userId] = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final current = state[userId];
      if (current != null && current.isTyping) {
        state = {
          ...state,
          userId: current.copyWith(isTyping: false),
        };
      }
      _typingTimers.remove(userId);
    });
  }

  // ── Cleanup ───────────────────────────────────────

  void _cancelAllTypingTimers() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _cancelAllTypingTimers();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// presenceProvider
// ---------------------------------------------------------------------------

/// Provides the current presence map for the active collaboration room.
///
/// Watch this provider from the UI layer to reactively show who is viewing
/// or editing a note.
final presenceProvider = StateNotifierProvider<PresenceNotifier,
    Map<String, RoomPresence>>((ref) {
  return PresenceNotifier(ref);
});

// ---------------------------------------------------------------------------
// PresenceAvatarStack
// ---------------------------------------------------------------------------

/// A horizontal stack of colored avatar circles representing users currently
/// in the room.
///
/// Shows up to 4 avatars with a -8 px overlap. If there are more than 4 users
/// an additional "+N" badge is displayed.
class PresenceAvatarStack extends StatelessWidget {
  /// The list of users to display.
  final List<RoomPresence> users;

  /// Size of each avatar circle in logical pixels.
  final double avatarSize;

  /// Horizontal offset between overlapping avatars (negative = overlap).
  final double overlapOffset;

  static const _maxVisibleAvatars = 4;

  const PresenceAvatarStack({
    super.key,
    required this.users,
    this.avatarSize = 30,
    this.overlapOffset = -8,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final visible = users.take(_maxVisibleAvatars).toList();
    final remaining = users.length - _maxVisibleAvatars;

    final children = <Widget>[
      for (final user in visible)
        _AvatarCircle(user: user, size: avatarSize),
      if (remaining > 0) _OverflowBadge(count: remaining, size: avatarSize),
    ];

    return SizedBox(
      // Width: first avatar at full width, each subsequent one offset by
      // (avatarSize + overlapOffset).
      width: avatarSize +
          (children.length - 1) * (avatarSize + overlapOffset),
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < children.length; i++)
            Positioned(
              left: i * (avatarSize + overlapOffset),
              child: children[i],
            ),
        ],
      ),
    );
  }
}

/// A single colored circle representing a user, with an initial letter
/// displayed in the center.
class _AvatarCircle extends StatelessWidget {
  final RoomPresence user;
  final double size;

  const _AvatarCircle({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _colorForUserId(user.userId);
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? Colors.white
              : Colors.black,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Deterministic color derived from the user ID so each user gets a
  /// consistent color across sessions.
  static Color _colorForUserId(String userId) {
    // Simple hash-based color selection from a curated palette.
    var hash = 0;
    for (var i = 0; i < userId.length; i++) {
      hash = (hash * 31 + userId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    const palette = [
      Color(0xFF6750A4), // purple
      Color(0xFFE91E63), // pink
      Color(0xFF009688), // teal
      Color(0xFFFF9800), // orange
      Color(0xFF2196F3), // blue
      Color(0xFF4CAF50), // green
      Color(0xFFF44336), // red
      Color(0xFF3F51B5), // indigo
      Color(0xFF00BCD4), // cyan
      Color(0xFF8BC34A), // light green
    ];
    return palette[hash % palette.length];
  }
}

/// A small circle showing "+N" when there are more users than can be shown.
class _OverflowBadge extends StatelessWidget {
  final int count;
  final double size;

  const _OverflowBadge({required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TypingIndicatorText
// ---------------------------------------------------------------------------

/// Displays an animated typing indicator for one or more users.
///
/// Shows text like "Alice is typing..." or "Alice and Bob are typing..."
/// with three pulsing dots. When [typingUsers] is empty the widget renders
/// a zero-height SizedBox.
class TypingIndicatorText extends StatefulWidget {
  /// Users currently marked as typing.
  final List<RoomPresence> typingUsers;

  const TypingIndicatorText({
    super.key,
    required this.typingUsers,
  });

  @override
  State<TypingIndicatorText> createState() => _TypingIndicatorTextState();
}

class _TypingIndicatorTextState extends State<TypingIndicatorText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) return const SizedBox.shrink();

    final text = _buildTypingText(widget.typingUsers);
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 2),
        _AnimatedDots(controller: _controller),
      ],
    );
  }

  /// Build the human-readable prefix based on how many users are typing.
  String _buildTypingText(List<RoomPresence> users) {
    if (users.length == 1) {
      return '${users.first.displayName} is typing';
    } else if (users.length == 2) {
      return '${users.first.displayName} and '
          '${users.last.displayName} are typing';
    } else {
      return '${users.first.displayName} and '
          '${users.length - 1} others are typing';
    }
  }
}

/// Three dots that pulse with staggered opacity animation.
class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          _PulsingDot(
            controller: controller,
            delay: i * 0.2,
          ),
      ],
    );
  }
}

/// A single dot whose opacity oscillates based on the parent animation
/// controller, offset by [delay] as a fraction of the period.
class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _PulsingDot({
    required this.controller,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Phase-shifted sine wave for smooth pulsing.
        final t = (controller.value - delay) % 1.0;
        final opacity =
            0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: child,
        );
      },
      child: Text(
        '.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
