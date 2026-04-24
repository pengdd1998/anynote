import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase of an ongoing sync operation.
enum SyncPhase {
  idle,
  pulling,
  pushing,
  done,
  error,
}

/// Detailed progress information for an active sync operation.
///
/// Emitted by the sync engine during pull/push cycles so the UI can display
/// a progress bar, current item label, and failed-item retry controls.
class SyncProgress {
  final SyncPhase phase;
  final int completedCount;
  final int totalCount;
  final String? currentItemLabel;
  final List<SyncFailedItem> failedItems;
  final DateTime? completedAt;

  const SyncProgress({
    this.phase = SyncPhase.idle,
    this.completedCount = 0,
    this.totalCount = 0,
    this.currentItemLabel,
    this.failedItems = const [],
    this.completedAt,
  });

  /// Convenience getter for progress fraction (0.0 - 1.0).
  double get progress => totalCount > 0 ? completedCount / totalCount : 0.0;

  /// Whether a sync is actively running.
  bool get isActive => phase == SyncPhase.pulling || phase == SyncPhase.pushing;

  /// Human-readable description of the current phase.
  String get phaseLabel {
    switch (phase) {
      case SyncPhase.idle:
        return '';
      case SyncPhase.pulling:
        return 'Pulling changes';
      case SyncPhase.pushing:
        return 'Pushing changes';
      case SyncPhase.done:
        return 'Sync complete';
      case SyncPhase.error:
        return 'Sync failed';
    }
  }

  SyncProgress copyWith({
    SyncPhase? phase,
    int? completedCount,
    int? totalCount,
    String? currentItemLabel,
    List<SyncFailedItem>? failedItems,
    DateTime? completedAt,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      currentItemLabel: currentItemLabel ?? this.currentItemLabel,
      failedItems: failedItems ?? this.failedItems,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static const idle = SyncProgress();
}

/// Represents a single item that failed during sync.
class SyncFailedItem {
  final String itemId;
  final String itemType;
  final String error;

  const SyncFailedItem({
    required this.itemId,
    required this.itemType,
    required this.error,
  });
}

/// Callback signature for progress reporting from the sync engine.
typedef SyncProgressCallback = void Function(SyncProgress progress);

/// Riverpod provider for the sync progress stream.
///
/// The sync engine emits progress events to the notifier; the UI watches
/// the stream via this provider.
final syncProgressProvider = StreamProvider<SyncProgress>((ref) {
  return SyncProgressNotifier.instance.stream;
});

/// Global stream controller for sync progress events.
///
/// The sync engine pushes events here; the [syncProgressProvider] exposes
/// them to the widget tree. Using a global controller avoids coupling the
/// engine directly to Riverpod.
class SyncProgressNotifier {
  static final SyncProgressNotifier instance = SyncProgressNotifier._();
  SyncProgressNotifier._();

  final _controller = StreamController<SyncProgress>.broadcast();

  /// Stream of progress events for the UI.
  Stream<SyncProgress> get stream => _controller.stream;

  /// Current progress state.
  SyncProgress _current = SyncProgress.idle;
  SyncProgress get current => _current;

  /// Emit a progress event.
  void emit(SyncProgress progress) {
    _current = progress;
    _controller.add(progress);
  }

  /// Reset to idle state.
  void reset() {
    emit(SyncProgress.idle);
  }

  /// Dispose the stream controller.
  void dispose() {
    _controller.close();
  }
}
