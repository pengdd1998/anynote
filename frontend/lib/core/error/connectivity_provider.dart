import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_providers.dart';
import '../sync/sync_queue_manager.dart';

/// Connectivity state exposed to the app.
///
/// [true] means the device appears to have internet connectivity,
/// [false] means it is offline. [null] means the state is unknown (initial).
typedef ConnectivityState = bool?;

/// Provider that exposes the current network connectivity state.
///
/// Uses a simple periodic DNS lookup check rather than the
/// `connectivity_plus` package to avoid adding a new dependency.
/// The check is performed every 30 seconds while the app is active.
///
/// Screens can watch this provider to show offline banners or disable
/// network-dependent actions.
final connectivityProvider = StreamProvider<ConnectivityState>((ref) {
  final controller = StreamController<ConnectivityState>.broadcast();
  Timer? timer;
  bool lastState = true;

  Future<void> performCheck() async {
    try {
      // Lightweight DNS lookup to verify network reachability.
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 5));
      final isOnline = result.isNotEmpty;
      if (lastState != isOnline) {
        lastState = isOnline;
        controller.add(isOnline);
      }
    } catch (_) {
      if (lastState != false) {
        lastState = false;
        controller.add(false);
      }
    }
  }

  // Emit an initial null to indicate unknown state, then check immediately.
  controller.add(null);
  performCheck();

  // Periodic checks every 30 seconds.
  timer = Timer.periodic(const Duration(seconds: 30), (_) {
    performCheck();
  });

  // Clean up on disposal.
  ref.onDispose(() {
    timer?.cancel();
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
final connectivitySyncTriggerProvider = Provider<void>((ref) {
  ref.listen(connectivityProvider, (previous, next) {
    final wasOffline = previous?.valueOrNull == false;
    final isOnline = next.valueOrNull == true;

    if (wasOffline && isOnline) {
      // Connectivity restored -- process any queued offline operations.
      final queueManager = ref.read(syncQueueManagerProvider);
      queueManager.processQueue();
    }
  });
});
