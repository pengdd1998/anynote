import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_providers.dart';
import '../network/connectivity_service.dart';
import '../sync/sync_queue_manager.dart';

/// Connectivity state exposed to the app.
///
/// [true] means the device appears to have internet connectivity,
/// [false] means it is offline. [null] means the state is unknown (initial).
typedef ConnectivityState = bool?;

/// Provider that exposes the current network connectivity state.
///
/// Delegates to [connectivityServiceProvider] (powered by `connectivity_plus`)
/// and converts the synchronous bool into a stream so that existing consumers
/// which watch this as a `StreamProvider<ConnectivityState>` continue to work
/// without changes.
///
/// Screens can watch this provider to show offline banners or disable
/// network-dependent actions.
final connectivityProvider = StreamProvider<ConnectivityState>((ref) {
  // Start the connectivity service so it begins monitoring.
  ref.watch(connectivityServiceProvider);

  final controller = StreamController<ConnectivityState>.broadcast();
  StreamSubscription<bool>? subscription;

  // Emit an initial null to indicate unknown state.
  controller.add(null);

  // Subscribe to the connectivity service's stream for real-time updates.
  subscription =
      ref.read(connectivityServiceProvider.notifier).connectivityStream.listen(
    (isConnected) {
      controller.add(isConnected);
    },
    onError: (_) {
      controller.add(false);
    },
  );

  // Also emit the current state immediately so late subscribers get it.
  // The stream may not re-emit the current value, so we push it once.
  // connectivityServiceProvider is a NotifierProvider<ConnectivityService, bool>,
  // so its value is always a non-null bool.
  final current = ref.read(connectivityServiceProvider);
  controller.add(current);

  // Clean up on disposal.
  ref.onDispose(() {
    subscription?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Watches connectivity changes and triggers sync queue processing when
/// the device comes back online.
///
/// When connectivity transitions from offline to online, this provider
/// reads the [SyncQueueManager] and calls [SyncQueueManager.processQueue]
/// to flush any operations that were queued while offline.
///
/// This provider also listens directly to [connectivityServiceProvider] for
/// a faster response than the stream-based [connectivityProvider] allows.
final connectivitySyncTriggerProvider = Provider<void>((ref) {
  // Listen to connectivity state changes to detect offline-to-online
  // transitions and trigger sync queue processing.
  //
  // Using ref.listen (NOT ref.watch) to avoid provider rebuilds that would
  // replace the listener callbacks. When ref.watch is used in a
  // Provider<void>, state changes trigger a rebuild that discards the
  // ref.listen callbacks from the previous build, causing them to fire
  // only on the first change. ref.listen alone keeps the dependency alive
  // and the callbacks persist across all subsequent state changes.
  ref.listen<bool>(connectivityServiceProvider, (previous, next) {
    final wasOffline = previous == false;
    final isOnline = next == true;

    if (wasOffline && isOnline) {
      // Connectivity restored -- process any queued offline operations.
      final queueManager = ref.read(syncQueueManagerProvider);
      queueManager.processQueue();
    }
  });

  // Keep the stream-based provider alive for legacy consumers.
  ref.listen(connectivityProvider, (previous, next) {
    final wasOffline = previous?.valueOrNull == false;
    final isOnline = next.valueOrNull == true;

    if (wasOffline && isOnline) {
      final queueManager = ref.read(syncQueueManagerProvider);
      queueManager.processQueue();
    }
  });
});
