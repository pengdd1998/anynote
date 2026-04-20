import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod Notifier that monitors network connectivity using the
/// `connectivity_plus` package.
///
/// Exposes a boolean [isConnected] state that updates whenever the device's
/// connectivity changes. On initialization, an immediate check is performed
/// and a subscription to the connectivity stream is started.
///
/// The service distinguishes between "no connectivity" (none) and "has
/// connectivity" (any of wifi, mobile, ethernet, vpn, bluetooth, etc.).
/// This is intentionally coarse-grained: the app only needs to know whether
/// sync operations can reach the server, not which transport is in use.
class ConnectivityService extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  bool build() {
    // Start monitoring immediately.
    _startMonitoring();
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    // Default to connected; the stream will correct this on first emission.
    return true;
  }

  /// Whether the device currently has network connectivity.
  bool get isConnected => state;

  /// Begin listening to the connectivity_plus stream and update state
  /// on every change. Also perform an immediate check so the initial
  /// state is correct.
  void _startMonitoring() {
    final connectivity = Connectivity();
    _subscription = connectivity.onConnectivityChanged.listen((results) {
      final connected = _anyConnected(results);
      if (state != connected) {
        state = connected;
      }
    });

    // Fire an initial check so we don't rely on the default.
    _checkNow(connectivity);
  }

  /// Perform a one-shot connectivity check and update state.
  Future<void> _checkNow(Connectivity connectivity) async {
    try {
      final results = await connectivity.checkConnectivity();
      final connected = _anyConnected(results);
      if (state != connected) {
        state = connected;
      }
    } catch (_) {
      // If the check itself throws (rare), assume disconnected.
      if (kDebugMode) {
        // ignore: avoid_print
        print('ConnectivityService: checkConnectivity() threw, assuming offline');
      }
      state = false;
    }
  }

  /// Returns true if any of the connectivity results indicate an active
  /// network connection (i.e. not "none").
  static bool _anyConnected(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
  }

  /// Expose the raw connectivity stream for consumers that need to know
  /// the specific transport type (wifi, mobile, etc.).
  ///
  /// This is provided as a convenience; most consumers should simply watch
  /// [isConnected] via the provider.
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged;
  }

  /// A stream of bool values that emits on every connectivity change.
  Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(_anyConnected).distinct();
  }

  /// Force a re-check of the current connectivity state.
  Future<void> recheck() async {
    await _checkNow(Connectivity());
  }
}

/// Provider that exposes the current network connectivity state as a bool.
///
/// Watch this provider to reactively update UI when connectivity changes.
/// `true` means the device has network access, `false` means it does not.
final connectivityServiceProvider = NotifierProvider<ConnectivityService, bool>(
  ConnectivityService.new,
);
