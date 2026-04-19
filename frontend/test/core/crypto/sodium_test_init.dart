import 'dart:ffi';

import 'package:sodium/sodium.dart' show Sodium, SodiumInit;
import 'package:sodium/sodium_sumo.dart' show SodiumSumo, SodiumSumoInit;
import 'package:sodium_libs/sodium_libs.dart' show SodiumPlatform;

/// Initializes the sodium platform for unit tests on Linux.
///
/// The default [SodiumLinux] platform uses [DynamicLibrary.process] which
/// does not work in `flutter test` since the test runner does not link
/// against libsodium. This function registers a custom [SodiumPlatform]
/// that opens the shared library file directly.
void registerTestSodiumPlatform() {
  SodiumPlatform.instance = _TestSodiumPlatform();
}

class _TestSodiumPlatform extends SodiumPlatform {
  @override
  Future<Sodium> loadSodium() =>
      SodiumInit.init(() => DynamicLibrary.open('libsodium.so'));

  @override
  Future<SodiumSumo> loadSodiumSumo() =>
      SodiumSumoInit.init(() => DynamicLibrary.open('libsodium.so'));

  @override
  String get updateHint =>
      'Update libsodium via your system package manager.';
}
